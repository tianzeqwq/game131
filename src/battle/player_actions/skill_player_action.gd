class_name SkillPlayerAction
extends PlayerAction

## 技能策略 — 信号驱动状态机
##
## 状态流：
##   SKILL_LIST ──(选单体技能)──→ TARGET_SELECT
##   SKILL_LIST ──(全体/随机)───→ EXECUTING
##   SKILL_LIST ──(取消)───────→ 退出
##
##   TARGET_SELECT ──(确认)───→ EXECUTING
##   TARGET_SELECT ──(取消)───→ CANCEL_BACK ──→ SKILL_LIST
##
##   CANCEL_BACK ──(再取消)──→ 退出
##
##   EXECUTING ──(执行完毕)──→ 返回 true

const SKILL_PANEL_PATH: String = "res://src/ui/skill_select_panel.tscn"

# ── 状态枚举 ──
enum State { SKILL_LIST, TARGET_SELECT, CANCEL_BACK, EXECUTING, IDLE }
var _state: int = State.IDLE

# ── 跨状态数据 ──
var _actor: Combatant
var _controller: BattleController
var _hud: BattleHUD
var _ui_root: Control
var _player_party: Array[Combatant]
var _enemy_party: Array[Combatant]

var _skill_panel: SkillSelectPanel
var _chosen_skill: SkillConfig
var _chosen_target: Combatant
var _actual_boost: int

# 临时跨状态数据（避免 lambda 闭包捕获问题）
var _pending_target: Combatant
var _pending_cancelled: bool


func get_action_name() -> String:
	return "技能"


func get_action_description() -> String:
	return "消耗热量释放特殊技能。可对单体、全体或随机敌人造成伤害。"


func execute(
	actor: Combatant,
	controller: BattleController,
	hud: BattleHUD,
	ui_root: Control,
	player_party: Array[Combatant],
	enemy_party: Array[Combatant]
) -> bool:
	var skills = actor.get_available_skills()
	if skills.is_empty():
		return false

	_actor = actor
	_controller = controller
	_hud = hud
	_ui_root = ui_root
	_player_party = player_party
	_enemy_party = enemy_party

	_state = State.SKILL_LIST

	while true:
		match _state:
			State.SKILL_LIST:
				await _do_skill_list(skills)
				# _state 在 _do_skill_list 内部设置

			State.TARGET_SELECT:
				await _do_target_select()
				# _state 在 _do_target_select 内部设置

			State.CANCEL_BACK:
				await _do_cancel_back(skills)
				# _state 在 _do_cancel_back 内部设置

			State.EXECUTING:
				await _do_execute()
				return true
			State.IDLE:
				return false

	# 兜底（不应到达）
	return false


## ── State: SKILL_LIST ──

func _do_skill_list(skills: Array[SkillConfig]) -> void:
	# 计算增幅上限
	var boost_limit = 3
	for s in skills:
		boost_limit = mini(boost_limit, s.get_boost_limit())
	boost_limit = mini(boost_limit, _actor.bp)

	# 保留当前增幅等级（增幅不因进入技能面板而重置）
	var current_boost = _assembler.get_boost_level() if _assembler else 0

	# 更新 CombatActionPanel 上的 BoostPanel 数据（已始终显示）
	if _assembler:
		_assembler.setup_boost_panel(_actor.bp, boost_limit, clampi(current_boost, 0, boost_limit))

	# 1. 打开技能选择面板
	_skill_panel = load(SKILL_PANEL_PATH).instantiate()
	_ui_root.add_child(_skill_panel)

	if _assembler:
		_assembler.set_active_sub_panel(_skill_panel)

	var parent_rect = _assembler.get_main_menu_rect() if _assembler else Rect2()
	_skill_panel.show_for(skills, _actor.bp, _actor.stats.max_bp, _actor.stats.unit_name, 0, parent_rect)

	# 2. 等待面板关闭
	await _skill_panel.closed

	if not is_instance_valid(_skill_panel):
		_hud.update_all()
		_state = State.IDLE
		return

	_chosen_skill = _skill_panel.last_selected_skill
	_actual_boost = _assembler.get_boost_level() if _assembler else 0
	var was_cancelled = _skill_panel.was_cancelled

	if was_cancelled or _chosen_skill == null:
		_skill_panel.queue_free()
		_hud.update_all()
		_state = State.IDLE
		return

	# 3. 根据目标类型决定下一步
	# 注意：对于 all_enemies/random 不在此处释放面板，
	#      面板会在 _do_execute() 的 play_all_flyout() 中使用飞行动画，
	#      最后由 _on_battle_player_action_requested 中的 _cleanup_sub_panel() 统一释放。
	match _chosen_skill.target_type:
		"all_enemies", "random":
			_state = State.EXECUTING
		_: # "single"
			_state = State.TARGET_SELECT


## ── State: TARGET_SELECT ──

func _do_target_select() -> void:
	# 1. 隐藏菜单（直接 hide，不做半隐退）
	if _assembler:
		_assembler.hide_menus()

	# 2. 准备目标列表
	var alive_enemies = _enemy_party.filter(func(e): return e.is_alive())
	if alive_enemies.is_empty():
		print("[Skill] no alive enemies, cancel back")
		if _assembler:
			_assembler.show_menus()
		_state = State.CANCEL_BACK
		return

	# 3. 创建 TargetSelector（场景内高亮，无列表面板）
	var selector = TargetSelector.new()
	selector.set_deps(_hud, _controller.timeline, _assembler)
	_ui_root.add_child(selector)
	selector.show_for(alive_enemies, "选择技能目标")

	# 4. 用信号桥接等结果
	# 重要：使用成员变量而非局部变量，避免 Godot await 恢复后 lambda 闭包变量丢失
	_pending_target = null
	_pending_cancelled = false

	selector.target_confirmed.connect(func(t: Combatant):
		_pending_target = t
	)
	selector.selection_cancelled.connect(func():
		_pending_cancelled = true
	)
	await selector.closed

	selector.queue_free()

	# 5. 条件性处理
	if _pending_cancelled or _pending_target == null:
		# 取消 → 恢复菜单显示
		if _assembler:
			_assembler.show_menus()
		_state = State.CANCEL_BACK
		return

	# 确认 → 菜单保持隐藏（高亮由 play_all_flyout 清理）
	_chosen_target = _pending_target
	_state = State.EXECUTING


## ── State: CANCEL_BACK — 取消后恢复技能列表 ──

func _do_cancel_back(skills: Array[SkillConfig]) -> void:
	# 1. 取快照（保存当前技能索引和 BP）
	var snapshot: Dictionary = {}
	if is_instance_valid(_skill_panel):
		snapshot = _skill_panel.get_restore_snapshot()
		_skill_panel.queue_free()

	_hud.update_all()

	# 2. 从 CombatActionPanel 读取当前增幅等级
	var current_boost = _assembler.get_boost_level() if _assembler else 0

	# 重新设置增幅面板
	var boost_limit = 3
	for s in skills:
		boost_limit = mini(boost_limit, s.get_boost_limit())
	boost_limit = mini(boost_limit, _actor.bp)
	if _assembler:
		_assembler.setup_boost_panel(_actor.bp, boost_limit, current_boost)

	# 3. 重建技能面板
	var new_panel = load(SKILL_PANEL_PATH).instantiate()
	_ui_root.add_child(new_panel)
	if _assembler:
		_assembler.set_active_sub_panel(new_panel)
	_skill_panel = new_panel

	var parent_rect = _assembler.get_main_menu_rect() if _assembler else Rect2()

	_skill_panel.show_for(skills, _actor.bp, _actor.stats.max_bp, _actor.stats.unit_name, current_boost, parent_rect)

	# 4. 从快照恢复（技能索引）
	if not snapshot.is_empty():
		_skill_panel.restore_from_snapshot(snapshot)

	_hud.show_boost_preview(_actor, current_boost)

	# 5. 等待新面板
	await _skill_panel.closed

	if not is_instance_valid(_skill_panel):
		_state = State.IDLE
		return

	_chosen_skill = _skill_panel.last_selected_skill
	_actual_boost = _assembler.get_boost_level() if _assembler else 0
	var was_cancelled = _skill_panel.was_cancelled

	if was_cancelled or _chosen_skill == null:
		_skill_panel.queue_free()
		_state = State.IDLE
		return

	# 6. 再次判断目标类型
	# 同样，不在此处释放面板，由 play_all_flyout() + _cleanup_sub_panel() 统一管理
	match _chosen_skill.target_type:
		"all_enemies", "random":
			_state = State.EXECUTING
		_: # "single"
			_state = State.TARGET_SELECT


## ── State: EXECUTING — 执行技能 ──

func _do_execute() -> void:
	# 1. 构建目标数组
	var targets: Array[Combatant] = []
	var alive_enemies = _enemy_party.filter(func(e): return e.is_alive())

	match _chosen_skill.target_type:
		"all_enemies":
			targets = alive_enemies
		"random":
			targets = _enemy_party
		_: # "single"
			targets = [_chosen_target]

	if targets.is_empty():
		_state = State.IDLE
		return

	# 2. 面板飞离（一扫而空）
	if _assembler:
		await _assembler.play_all_flyout()

	# 3. 创建并执行 Action
	var action = SkillAction.new(_actor, targets, _chosen_skill)
	await action.execute(_actual_boost)

	_hud.update_all()
