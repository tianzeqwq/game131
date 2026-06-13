class_name PreemptiveAction
extends CombatAction

## 先制技能行动
##
## 使用后，执行者的下一回合顺位层级提升至 TIER_PREEMPTIVE（几乎锁定先手）。
## 本 Action 不处理伤害，仅负责层级修改；伤害由具体技能配置决定。

func _apply_effect(boost_level: int) -> void:
	# 核心效果：下一回合先制
	executor.next_round_priority_tier = Combatant.TIER_PREEMPTIVE

	# 发布先制技能事件
	CombatEventBus.publish(
		CombatEventAction.new(executor.stats.unit_name, "preemptive", boost_level)
	)
