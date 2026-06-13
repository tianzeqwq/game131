class_name DamageContext
extends RefCounted

## 伤害计算输入上下文 DTO
##
## 将一次伤害计算所需的全部输入打包成一个对象，
## 避免长参数列表，符合 Clean Code 原则（参数 ≤ 3）。

var attacker: Combatant
var defender: Combatant

# 伤害类型: "physical" 或 "digital"
var damage_type: String = "physical"

# 技能参数（来自 SkillConfig 或 hardcode）
var skill_multiplier: float = 1.0   # 技能基础伤害倍率
var skill_accuracy: float = 1.0     # 技能基础命中率 (0.0~1.0)

# BP 增幅倍率 (Boost 0=1.0, 1=1.5, 2=2.0, 3=2.5)
var bp_multiplier: float = 1.0

# 是否强制暴击（某些技能特性）
var is_crit_forced: bool = false

func _init(
	p_attacker: Combatant,
	p_defender: Combatant,
	p_damage_type: String = "physical",
	p_skill_multiplier: float = 1.0,
	p_skill_accuracy: float = 1.0,
	p_bp_multiplier: float = 1.0
) -> void:
	attacker = p_attacker
	defender = p_defender
	damage_type = p_damage_type
	skill_multiplier = p_skill_multiplier
	skill_accuracy = p_skill_accuracy
	bp_multiplier = p_bp_multiplier
