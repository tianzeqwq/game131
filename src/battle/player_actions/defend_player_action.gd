class_name DefendPlayerAction
extends PlayerAction

## 防御策略
##
## 流程：主菜单"一扫而空"飞离 → 立即执行 DefendAction

func get_action_name() -> String:
	return "防御"


func get_action_description() -> String:
	return "进入防御姿态，大幅减少受到的伤害。"


func execute(
	actor: Combatant,
	controller: BattleController,
	hud: BattleHUD,
	ui_root: Control,
	player_party: Array[Combatant],
	enemy_party: Array[Combatant]
) -> bool:
	# 主菜单飞离（一扫而空）
	if _assembler:
		await _assembler.play_all_flyout()

	var action = DefendAction.new(actor, [])
	await action.execute(0)

	hud.update_all()
	return true
