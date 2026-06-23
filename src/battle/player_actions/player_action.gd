class_name PlayerAction
extends RefCounted

## 玩家行动策略基类
##
## 重构后：新增 assembler 引用，用于子类协调菜单动效

## 场景组装器引用（由 PlayerInputHandler 注入）
var _assembler: BattleSceneAssembler = null


func set_assembler(assembler: BattleSceneAssembler) -> void:
	_assembler = assembler


## 菜单按钮显示名称
func get_action_name() -> String:
	return "行动"


## 菜单描述文本（子类可覆盖）
func get_action_description() -> String:
	return "选择行动。"


## 执行策略
## 返回 true 表示行动已执行完毕；false 表示取消/需要重选
func execute(
	actor: Combatant,
	controller: BattleController,
	hud: BattleHUD,
	ui_root: Control,
	player_party: Array[Combatant],
	enemy_party: Array[Combatant]
) -> bool:
	push_warning("PlayerAction.execute() 需要在子类中实现")
	return false
