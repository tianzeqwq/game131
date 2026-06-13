class_name CombatEventDamage
extends CombatEvent

## 伤害领域事件
##
## 仅携带纯数据：谁打了谁、什么类型、多少伤害。
## 不含任何 BBCode 或 UI 格式信息。
##
## 包含中间计算值，供 CombatLogFormatter 展示详细计算过程。

var attacker_name: String
var target_name: String
var damage_type: String  # "physical" | "digital"
var raw_damage: float
var final_damage: float
var effective_damage: float
var is_hit: bool
var is_crit: bool
var is_weakness: bool
var shield_damaged: float
var is_kill: bool

# 计算过程中间值（从 DamageResult 透传）
var atk_stat: float = 0.0
var def_stat: float = 0.0
var def_multiplier: float = 0.5
var attack_value: float = 0.0
var defense_value: float = 0.0
var base_damage: float = 0.0
var ability_mod: float = 1.0
var status_mod: float = 1.0
var level_mult: float = 0.58
var calculated_damage: float = 0.0
var random_factor: float = 1.0
var forced_reduction: float = 1.0
var skill_multiplier: float = 1.0   # 技能倍率（从 DamageContext 来）
var bp_multiplier: float = 1.0      # BP 倍率（从 DamageContext 来）

func _init(
	p_attacker: String,
	p_target: String,
	p_type: String,
	p_raw: float,
	p_final: float,
	p_effective: float,
	p_hit: bool,
	p_crit: bool = false,
	p_weakness: bool = false,
	p_shield: float = 0.0,
	p_kill: bool = false
) -> void:
	super()
	attacker_name = p_attacker
	target_name = p_target
	damage_type = p_type
	raw_damage = p_raw
	final_damage = p_final
	effective_damage = p_effective
	is_hit = p_hit
	is_crit = p_crit
	is_weakness = p_weakness
	shield_damaged = p_shield
	is_kill = p_kill
