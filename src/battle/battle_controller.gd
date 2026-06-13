class_name BattleController
extends Node

## 战斗控制器
##
## 职责：掌管战斗主循环（回合循环、AI、Break 时序），不直接操作 UI。
## 通过信号与 Main.gd/UI 层通信，遵循依赖倒置原则（DIP）。
##
## 信号 → Main.gd 监听 → 更新 UI / 写日志

## 请求玩家输入（Main.gd 应启用按钮并等待玩家操作）
signal player_action_requested(actor: Combatant)
## 战斗结束
signal battle_ended(players_won: bool)
## 新回合开始
signal round_started(round_number: int)
## 单位因 Break 被跳过行动
signal unit_skipped_broken(actor: Combatant)
## 敌人正在分析行动
signal enemy_analyzing(actor: Combatant)
## 每个单位行动完成后触发（用于 UI 刷新行动轴）
signal turn_advanced(actor: Combatant)

var player_party: Array[Combatant] = []
var enemy_party: Array[Combatant] = []
var timeline: BattleTimeline = BattleTimeline.new()

var current_actor: Combatant = null
var selected_boost: int = 0
var is_battle_active: bool = false
var is_waiting_for_player: bool = false
var round_number: int = 0


func start_battle() -> void:
	is_battle_active = true
	await get_tree().create_timer(0.5).timeout
	run_round_loop()


func run_round_loop() -> void:
	while is_battle_active:
		if _check_battle_end():
			is_battle_active = false
			break

		round_number += 1
		selected_boost = 0

		# Round Start Phase
		var all_units = player_party + enemy_party
		for c in all_units:
			if c.is_alive():
				c.on_round_start()

		timeline.generate_timeline(all_units)

		# Turn Cycle Phase
		current_actor = timeline.get_next_up()

		# 信号在队列和 current_actor 就绪后发出，确保 UI 能正确读取
		round_started.emit(round_number)
		while current_actor != null:
			if current_actor.is_alive():
				if current_actor.is_broken:
					unit_skipped_broken.emit(current_actor)
					await get_tree().create_timer(1.0).timeout
				else:
					if current_actor.is_player:
						is_waiting_for_player = true
						player_action_requested.emit(current_actor)
						await player_action_completed
						is_waiting_for_player = false
					else:
						await _execute_enemy_ai(current_actor)

				turn_advanced.emit(current_actor)

				if _check_battle_end():
					is_battle_active = false
					break

			current_actor = timeline.get_next_up()

		if not is_battle_active:
			break

		# Round End Phase
		for c in all_units:
			if c.is_alive():
				c.on_round_end()

		await get_tree().create_timer(1.0).timeout

	resolve_battle_result()


func _execute_enemy_ai(actor: Combatant) -> void:
	enemy_analyzing.emit(actor)
	await get_tree().create_timer(1.5).timeout

	var target = _get_random_alive_player()
	if target == null: return

	var skills = actor.get_available_skills()
	var action: CombatAction

	if skills.is_empty():
		action = AttackAction.new(actor, [target])
	else:
		var chosen_skill = _find_skill_by_heat(actor)
		if chosen_skill == null:
			chosen_skill = skills[randi() % skills.size()]

		match chosen_skill.damage_type:
			"digital":
				action = HackAction.new(actor, [target], chosen_skill)
			_:
				action = AttackAction.new(actor, [target], chosen_skill)

	var enemy_boost = 0
	if actor.bp >= 3 and randf() < 0.4:
		enemy_boost = randi_range(1, actor.bp - 1)

	await action.execute(enemy_boost)


func _get_random_alive_player() -> Combatant:
	var alive = player_party.filter(func(p): return p.is_alive())
	if alive.is_empty(): return null
	return alive[randi() % alive.size()]


func _find_skill_by_heat(combatant: Combatant) -> SkillConfig:
	for s in combatant.get_available_skills():
		if s.heat_generated > 0.0:
			return s
	return null


func _check_battle_end() -> bool:
	var players_alive = player_party.any(func(p): return p.is_alive())
	var enemies_alive = enemy_party.any(func(e): return e.is_alive())
	return not players_alive or not enemies_alive


func resolve_battle_result() -> void:
	var players_win = enemy_party.all(func(e): return not e.is_alive())

	# 掉落结算（这里作为纯数据计算）
	var total_money: int = 0
	var total_drops: Array[String] = []
	if players_win:
		for e in enemy_party:
			if not e.is_alive() and e.stats is EnemyStats:
				var enemy_stats := e.stats as EnemyStats
				total_money += enemy_stats.money
				for item in enemy_stats.drop_items:
					total_drops.append(item)
				if enemy_stats.held_item != "":
					total_drops.append("[携带] " + enemy_stats.held_item)

	battle_ended.emit(players_win)
	# Main.gd 监听 battle_ended 信号后，读取这些结算数据
	# （或通过另一个信号传递结算数据）
	battle_reward_calculated.emit(players_win, total_money, total_drops)


## 结算数据信号（Main.gd 监听后显示奖励文本）
signal battle_reward_calculated(players_won: bool, money: int, drops: Array[String])

## 供 Main.gd 调用：玩家完成操作后触发此信号
signal player_action_completed
