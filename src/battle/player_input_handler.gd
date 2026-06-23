class_name PlayerInputHandler
extends RefCounted

## 玩家输入处理器
##
## 重构后：新增 assembler 引用，使 PlayerAction 可以协调动效（半隐退/推窗/飞离）
##
## 职责：管理玩家行动策略集合，负责初始化和分发菜单选择。
## 使用策略模式（Strategy Pattern），每种操作由独立的 PlayerAction 子类实现。

## 可用的行动策略
var _action_strategies: Dictionary = {}
var _action_order: Array[String] = ["攻击", "技能", "防御"]

var _battle_controller: BattleController
var _hud: BattleHUD
var _player_party: Array[Combatant]
var _enemy_party: Array[Combatant]
var _ui_root: Control
var _assembler: BattleSceneAssembler  # 新增：用于动效协调


func setup(
	controller: BattleController,
	hud: BattleHUD,
	player: Array[Combatant],
	enemy: Array[Combatant],
	ui_root: Control = null,
	assembler: BattleSceneAssembler = null
) -> void:
	_battle_controller = controller
	_hud = hud
	_player_party = player
	_enemy_party = enemy
	_ui_root = ui_root
	_assembler = assembler
	_register_default_strategies()


## 注册默认策略（攻击/技能/防御）
func _register_default_strategies() -> void:
	register_strategy(AttackPlayerAction.new())
	register_strategy(SkillPlayerAction.new())
	register_strategy(DefendPlayerAction.new())


## 注册一个行动策略
func register_strategy(strategy: PlayerAction) -> void:
	_action_strategies[strategy.get_action_name()] = strategy


## 获取所有已注册的策略名称列表
func get_available_action_names() -> Array[String]:
	var names: Array[String] = []
	for action_name in _action_order:
		if _action_strategies.has(action_name):
			names.append(action_name)
	return names


## 获取当前角色的可用策略列表
func get_available_actions(actor: Combatant) -> Array[PlayerAction]:
	var available: Array[PlayerAction] = []
	for action_name in _action_order:
		if not _action_strategies.has(action_name):
			continue
		var strategy = _action_strategies[action_name] as PlayerAction
		if strategy is SkillPlayerAction:
			if actor.get_available_skills().is_empty():
				continue
		available.append(strategy)
	return available


## 执行指定的行动策略
func execute_action(strategy: PlayerAction) -> bool:
	if not _battle_controller.is_waiting_for_player or _battle_controller.current_actor == null:
		return true

	var actor = _battle_controller.current_actor

	# 将 assembler 引用注入策略
	if strategy.has_method("set_assembler"):
		strategy.set_assembler(_assembler)

	var completed = await strategy.execute(actor, _battle_controller, _hud, _ui_root, _player_party, _enemy_party)
	return completed


## 直接执行行动并完成
func _execute_and_complete(action: CombatAction, boost_level: int = 0) -> void:
	await action.execute(boost_level)
	_hud.update_all()
	_battle_controller.player_action_completed.emit()
