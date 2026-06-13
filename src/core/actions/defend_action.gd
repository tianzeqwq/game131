class_name DefendAction
extends CombatAction

func _apply_effect(boost_level: int) -> void:
	executor.is_defending = true

	# 通过 CombatEventBus 发布 Defend 领域事件
	CombatEventBus.publish(
		CombatEventAction.new(executor.stats.unit_name, "defend", 0.0)
	)
