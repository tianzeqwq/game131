class_name PlayerInputHandler
extends RefCounted

## 玩家输入处理器
##
## 职责：处理玩家按钮点击，创建对应的 CombatAction 并执行。
## 从 Main.gd 提取，遵循单一职责原则。

const SKILL_PANEL_PATH: String = "res://src/ui/skill_select_panel.tscn"

var _battle_controller: BattleController
var _hud: BattleHUD
var _player_party: Array[Combatant]
var _enemy_party: Array[Combatant]
var _ui_root: Control
var _selected_boost: int = 0


func setup(controller: BattleController, hud: BattleHUD, player: Array[Combatant], enemy: Array[Combatant], ui_root: Control = null) -> void:
	_battle_controller = controller
	_hud = hud
	_player_party = player
	_enemy_party = enemy
	_ui_root = ui_root


func _get_default_enemy_target() -> Combatant:
	for e in _enemy_party:
		if e.is_alive():
			return e
	return null


func _find_skill_by_type(combatant: Combatant, damage_type: String) -> SkillConfig:
	for s in combatant.get_available_skills():
		if s.damage_type == damage_type and s.heat_generated <= 0.0:
			return s
	return null


func _find_skill_by_heat(combatant: Combatant) -> SkillConfig:
	for s in combatant.get_available_skills():
		if s.heat_generated > 0.0:
			return s
	return null


func _on_skill_pressed() -> void:
	if not _battle_controller.is_waiting_for_player or _battle_controller.current_actor == null:
		return

	var actor = _battle_controller.current_actor
	var skills = actor.get_available_skills()
	if skills.is_empty():
		_battle_controller.player_action_completed.emit()
		return

	# 创建并显示技能选择面板
	var panel = load(SKILL_PANEL_PATH).instantiate()
	_ui_root.add_child(panel)
	panel.show_for(skills, actor.bp, actor.stats.max_bp, actor.stats.unit_name)

	# 增幅变化时实时更新 HUD 上的 BP 预览（面板 ×N = 消耗 N-1）
	panel.boost_changed.connect(func(bl):
		var cost = bl - 1
		_hud.show_boost_preview(actor, cost)
	)

	# 等待面板关闭（用户确认或取消）
	await panel.closed

	# 从面板读取结果（面板内存有效，因为我们还没 queue_free）
	var chosen_skill = panel.last_selected_skill
	var boost_level = panel.last_boost_level
	var was_cancelled = panel.was_cancelled

	panel.queue_free()

	if was_cancelled or chosen_skill == null:
		_battle_controller.player_action_completed.emit()
		return

	var target = _get_default_enemy_target()
	if target == null:
		_battle_controller.player_action_completed.emit()
		return

	# 面板显示 ×N 对应实际消耗 N-1（×1=消耗0, ×2=消耗1...）
	var actual_boost = boost_level - 1
	var action = SkillAction.new(actor, [target], chosen_skill)
	await _execute_and_complete(action, actual_boost)


func _execute_and_complete(action: CombatAction, boost_level: int = -1) -> void:
	var bl = boost_level if boost_level >= 0 else _selected_boost
	await action.execute(bl)
	_selected_boost = 0
	# 强制刷新 HUD，确保 BP 圆点和血条反映最新状态
	_hud.update_all()
	_battle_controller.player_action_completed.emit()
