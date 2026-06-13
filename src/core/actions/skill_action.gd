class_name SkillAction
extends CombatAction

## 技能行动
##
## 单段高伤害，附带 Heat（负载）增加。
## 伤害随 Boost 线性增长：倍率 = 1.0 + boost_level
## 必须通过构造函数注入 SkillConfig，确保 Action 永远不会处于无效状态。

## 技能配置（通过构造函数注入，不可为空）
var skill_config: SkillConfig

## 构造函数注入：强制要求传入 SkillConfig
func _init(p_executor: Combatant, p_targets: Array[Combatant], p_config: SkillConfig) -> void:
	super(p_executor, p_targets)
	assert(p_config != null, "SkillAction requires a valid SkillConfig to run!")
	skill_config = p_config

func _apply_effect(boost_level: int) -> void:
	if targets.is_empty(): return
	var target = targets[0]

	# 技能产生热量
	executor.add_heat(skill_config.heat_generated)

	if executor.visual_unit:
		executor.visual_unit.play_attack_animation()

	# 技能倍率 = (1.0 + boost_level)，Boost 0=1x, Boost 1=2x, Boost 2=3x, Boost 3=4x
	var damage_multiplier = 1.0 + boost_level
	var bp_mult = DamageCalculator.BP_MULTIPLIERS[boost_level] if boost_level < DamageCalculator.BP_MULTIPLIERS.size() else 1.0

	var ctx = DamageContext.new(
		executor, target, skill_config.damage_type,
		skill_config.damage_multiplier * damage_multiplier, skill_config.accuracy, bp_mult
	)
	var result = DamageCalculator.calculate(ctx)

	target.take_damage(result, skill_config.damage_type, executor.stats.unit_name)
