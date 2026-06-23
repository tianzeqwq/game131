class_name HackAction
extends AttackAction

## ⚠️ HackAction 已废弃，统一使用 AttackAction
##
## HackAction 与 AttackAction 的逻辑完全重复，唯一的区别是默认伤害类型。
## AttackAction 已支持通过 SkillConfig.damage_type 指定伤害类型，
## 因此 HackAction 不再需要独立的实现。
##
## 保留此文件仅用于向后兼容，所有新代码请直接使用 AttackAction。

func _init(p_executor: Combatant, p_targets: Array[Combatant], p_config: SkillConfig = null) -> void:
	super(p_executor, p_targets, p_config)
