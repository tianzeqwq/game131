class_name AttackAction
extends CombatAction

## 物理攻击行动
##
## 使用 DamageCalculator 计算每段伤害。
## 段数 = 1 + boost_level（Boost 0=1段, Boost 1=2段, ...）
## 可通过构造函数注入 SkillConfig 自定义参数；若不传则使用默认值。

## 技能配置（可选，不传则使用默认参数）
var skill_config: SkillConfig

## 构造函数注入（可选）
func _init(p_executor: Combatant, p_targets: Array[Combatant], p_config: SkillConfig = null) -> void:
	super(p_executor, p_targets)
	skill_config = p_config

func _apply_effect(boost_level: int) -> void:
	if targets.is_empty(): return
	var target = targets[0]

	# Play attack animation on executor
	if executor.visual_unit:
		executor.visual_unit.play_attack_animation()

	var hits = 1 + boost_level
	var bp_mult = DamageCalculator.BP_MULTIPLIERS[boost_level] if boost_level < DamageCalculator.BP_MULTIPLIERS.size() else 1.0

	# 技能参数：优先使用 SkillConfig，否则 fallback 到默认值
	var skill_mult = skill_config.damage_multiplier if skill_config else 1.0
	var skill_acc = skill_config.accuracy if skill_config else 0.95
	var dmg_type = skill_config.damage_type if skill_config else "physical"

	for i in range(hits):
		if not target.is_alive():
			break

		# 构造 DamageContext 并计算
		var ctx = DamageContext.new(
			executor, target, dmg_type,
			skill_mult, skill_acc, bp_mult
		)
		var result = DamageCalculator.calculate(ctx)

		# 执行伤害（扣血 + 削盾 + Break）
		target.take_damage(result, dmg_type, executor.stats.unit_name)

		# 多段攻击间的视觉间隔
		if hits > 1 and i < hits - 1:
			await executor.visual_unit.get_tree().create_timer(0.2).timeout
