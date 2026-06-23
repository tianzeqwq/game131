class_name SkillAction
extends CombatAction

## 技能行动
##
## 高伤害技能，附带 Heat（负载）增加。
## 伤害随 Boost 线性增长：倍率 = 1.0 + boost_level
## 支持目标类型：单体（single）/ 全体（all_enemies）/ 随机（random）
## 必须通过构造函数注入 SkillConfig。

## 技能配置（通过构造函数注入，不可为空）
var skill_config: SkillConfig

## 构造函数注入：强制要求传入 SkillConfig
func _init(p_executor: Combatant, p_targets: Array[Combatant], p_config: SkillConfig) -> void:
	super(p_executor, p_targets)
	assert(p_config != null, "SkillAction requires a valid SkillConfig to run!")
	skill_config = p_config

func _apply_effect(boost_level: int) -> void:
	if targets.is_empty(): return

	# 技能产生热量
	executor.add_heat(skill_config.heat_generated)

	if executor.visual_unit:
		await executor.visual_unit.play_attack_animation()

	# 技能倍率 = (1.0 + boost_level)，Boost 0=1x, Boost 1=2x, Boost 2=3x, Boost 3=4x
	var damage_multiplier = 1.0 + boost_level
	var bp_mult = DamageCalculator.BP_MULTIPLIERS[boost_level] if boost_level < DamageCalculator.BP_MULTIPLIERS.size() else 1.0
	var skill_mult = skill_config.damage_multiplier * damage_multiplier
	var skill_acc = skill_config.accuracy
	var dmg_type = skill_config.damage_type
	var hit_count = skill_config.get_hit_count(boost_level)

	# 根据 target_type 选择目标处理方式
	match skill_config.target_type:
		"all_enemies":
			await _execute_aoe(skill_mult, skill_acc, dmg_type, hit_count, bp_mult)
		"random":
			await _execute_random(skill_mult, skill_acc, dmg_type, hit_count, bp_mult)
		_: # "single"
			if targets.size() > 0:
				await _execute_single(targets[0], skill_mult, skill_acc, dmg_type, bp_mult, hit_count)


## 单体目标
func _execute_single(target: Combatant, skill_mult: float, skill_acc: float, dmg_type: String, bp_mult: float, hit_count: int) -> void:
	for i in range(hit_count):
		if not target.is_alive():
			break
		await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, hit_count, i)


## 全体目标
func _execute_aoe(skill_mult: float, skill_acc: float, dmg_type: String, hit_count: int, bp_mult: float) -> void:
	for target in targets:
		if target.is_alive():
			await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, 1, 0)


## 随机目标
func _execute_random(skill_mult: float, skill_acc: float, dmg_type: String, hit_count: int, bp_mult: float) -> void:
	var alive_targets = targets.filter(func(t): return t.is_alive())
	if alive_targets.is_empty():
		return
	for i in range(hit_count):
		alive_targets = targets.filter(func(t): return t.is_alive())
		if alive_targets.is_empty():
			break
		var target = alive_targets[randi() % alive_targets.size()]
		await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, hit_count, i)


## 单段伤害执行
func _deal_hit(target: Combatant, skill_mult: float, skill_acc: float, dmg_type: String, bp_mult: float, total_hits: int, hit_index: int) -> void:
	var ctx = DamageContext.new(
		executor, target, dmg_type,
		skill_mult, skill_acc, bp_mult
	)
	var result = DamageCalculator.calculate(ctx)
	target.take_damage(result, dmg_type, executor.stats.unit_name)

	if total_hits > 1 and hit_index < total_hits - 1:
		await executor.visual_unit.get_tree().create_timer(0.2).timeout
