class_name PostActiveAction
extends CombatAction

## 后制技能行动
##
## 使用后，执行者的下一回合顺位层级降至 TIER_POSTEMPTIVE（几乎锁定后手）。
## 本 Action 不处理伤害，仅负责层级修改；伤害由具体技能配置决定。

func _apply_effect(boost_level: int) -> void:
	# 核心效果：下一回合后制
	executor.next_round_priority_tier = Combatant.TIER_POSTEMPTIVE

	# 发布后制技能事件
	CombatEventBus.publish(
		CombatEventAction.new(executor.stats.unit_name, "postactive", boost_level)
	)
