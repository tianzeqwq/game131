class_name CombatAction
extends RefCounted

var executor: Combatant
var targets: Array[Combatant] = []

func _init(p_executor: Combatant, p_targets: Array[Combatant]) -> void:
	executor = p_executor
	targets = p_targets

# Execute the action, consuming BP if boosted
func execute(boost_level: int) -> void:
	if boost_level > 0:
		executor.bp -= boost_level
		executor.can_gain_bp_next_round = false
		
		# 通过 CombatEventBus 发布 Boost 领域事件
		CombatEventBus.publish(
			CombatEventAction.new(executor.stats.unit_name, "boost", boost_level)
		)
	
	await _apply_effect(boost_level)

# Abstract-like method to be overridden by subclasses
func _apply_effect(boost_level: int) -> void:
	pass
