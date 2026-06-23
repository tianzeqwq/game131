class_name AttackPlayerAction
extends PlayerAction

## 攻击（平A）策略 — 场景内高亮
##
## 流程：
##   主菜单选择"攻击" → 直接场景目标选择（四方向键）→ 执行 AttackAction
##   增幅在进入主菜单阶段由玩家用 ←/→ 调整，选中后保留该值
## 动效：目标选择时主菜单 + 子面板进入半隐退

# 临时跨状态数据（避免 lambda 闭包捕获问题）
var _pending_target: Combatant
var _pending_cancelled: bool


func get_action_name() -> String:
	return "攻击"


func get_action_description() -> String:
	return "对敌方单体进行攻击。增幅可增加攻击段数。"


func execute(
	actor: Combatant,
	controller: BattleController,
	hud: BattleHUD,
	ui_root: Control,
	player_party: Array[Combatant],
	enemy_party: Array[Combatant]
) -> bool:
	var attack_skill = _find_basic_attack_skill(actor)
	if attack_skill == null:
		return false

	var alive_enemies = enemy_party.filter(func(e): return e.is_alive())
	if alive_enemies.is_empty():
		return false

	var boost_limit = mini(attack_skill.get_boost_limit(), actor.bp)

	# ── 1. 设置 CombatActionPanel 上的 BoostPanel（保留玩家在主菜单已设定的增幅等级）──
	var current_boost = _assembler.get_boost_level() if _assembler else 0
	if _assembler:
		_assembler.setup_boost_panel(actor.bp, boost_limit, clampi(current_boost, 0, boost_limit))

	var boost_level = _assembler.get_boost_level() if _assembler else 0

	# ── 2. 根据目标类型进入分支（跳过 AttackSelectPanel，直接目标选择）──
	match attack_skill.target_type:
		"all_enemies":
			var targets = alive_enemies
			var action = AttackAction.new(actor, targets, attack_skill)
			await action.execute(boost_level)
			hud.update_all()
			return true

		"random":
			var action = AttackAction.new(actor, enemy_party, attack_skill)
			await action.execute(boost_level)
			hud.update_all()
			return true

		_: # "single"
			var target = await _do_scene_target_selection(alive_enemies, hud, controller, ui_root)
			if target == null:
				hud.update_all()
				return false

			var action = AttackAction.new(actor, [target], attack_skill)
			if _assembler:
				await _assembler.play_all_flyout()
			await action.execute(boost_level)
			hud.update_all()
			return true


## 场景内目标选择（复用 TargetSelector 的场景高亮机制）
func _do_scene_target_selection(
	alive_enemies: Array[Combatant],
	hud: BattleHUD,
	controller: BattleController,
	ui_root: Control
) -> Combatant:
	if alive_enemies.is_empty():
		return null
	if alive_enemies.size() == 1:
		return alive_enemies[0]

	# 隐藏菜单（直接 hide，不做半隐退）
	if _assembler:
		_assembler.hide_menus()

	var selector = TargetSelector.new()
	selector.set_deps(hud, controller.timeline, _assembler)
	ui_root.add_child(selector)
	selector.show_for(alive_enemies, "选择攻击目标")

	# 使用成员变量而非局部变量，避免 Godot await 恢复后 lambda 闭包丢失
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

	if _pending_cancelled or _pending_target == null:
		# 取消 → 恢复菜单显示
		if _assembler:
			_assembler.show_menus()
		return null

	# 确认 → 菜单保持隐藏（高亮由 play_all_flyout 清理）
	return _pending_target


func _find_basic_attack_skill(actor: Combatant) -> SkillConfig:
	for s in actor.get_available_skills():
		if s.hit_mode == "linear" and s.heat_generated <= 0.0:
			return s
	return null
