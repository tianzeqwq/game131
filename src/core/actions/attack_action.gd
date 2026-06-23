class_name AttackAction
extends CombatAction

## 通用基础攻击行动（平A）
##
## 统一了原来的 AttackAction（物理）和 HackAction（数字），
## 通过 SkillConfig.damage_type 区分伤害类型。
## 段数 = SkillConfig.get_hit_count(boost_level)，默认 linear 模式 = 1 + boost_level。
## 若未传入 SkillConfig，使用默认物理攻击参数。

## 技能配置（可选，不传则使用默认物理攻击参数）
var skill_config: SkillConfig

## 构造函数注入（可选）
func _init(p_executor: Combatant, p_targets: Array[Combatant], p_config: SkillConfig = null) -> void:
	super(p_executor, p_targets)
	skill_config = p_config

func _apply_effect(boost_level: int) -> void:
	if targets.is_empty(): return

	# 技能参数：优先使用 SkillConfig，否则 fallback 到默认值
	var cfg = skill_config
	var skill_mult = cfg.damage_multiplier if cfg else 1.0
	var skill_acc = cfg.accuracy if cfg else 0.95
	var dmg_type = cfg.damage_type if cfg else "physical"
	var hit_count = cfg.get_hit_count(boost_level) if cfg else (1 + boost_level)
	var bp_mult = DamageCalculator.BP_MULTIPLIERS[boost_level] if boost_level < DamageCalculator.BP_MULTIPLIERS.size() else 1.0

	if executor.visual_unit:
		await executor.visual_unit.play_attack_animation()

	# 根据 target_type 选择目标处理方式
	match cfg.target_type if cfg else "single":
		"all_enemies":
			await _execute_aoe(skill_mult, skill_acc, dmg_type, hit_count, bp_mult)
		"random":
			await _execute_random(skill_mult, skill_acc, dmg_type, hit_count, bp_mult)
		_: # "single"
			await _execute_single(targets[0], skill_mult, skill_acc, dmg_type, bp_mult, hit_count)


## 单体目标：对 targets[0] 进行 hit_count 段攻击
func _execute_single(target: Combatant, skill_mult: float, skill_acc: float, dmg_type: String, bp_mult: float, hit_count: int) -> void:
	for i in range(hit_count):
		if not target.is_alive():
			break
		await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, hit_count, i)


## 全体目标：对所有活着的敌人各打一段
func _execute_aoe(skill_mult: float, skill_acc: float, dmg_type: String, hit_count: int, bp_mult: float) -> void:
	# AOE 模式下，hit_count 通常为 1（每目标打一段），
	# 遍历 targets 中所有活着的目标各打一次
	for target in targets:
		if target.is_alive():
			await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, 1, 0)


## 随机目标：每次命中从 targets 中随机选一个活着的目标
func _execute_random(skill_mult: float, skill_acc: float, dmg_type: String, hit_count: int, bp_mult: float) -> void:
	var alive_targets = targets.filter(func(t): return t.is_alive())
	if alive_targets.is_empty():
		return

	for i in range(hit_count):
		# 重新过滤活着的目标
		alive_targets = targets.filter(func(t): return t.is_alive())
		if alive_targets.is_empty():
			break
		var target = alive_targets[randi() % alive_targets.size()]
		await _deal_hit(target, skill_mult, skill_acc, dmg_type, bp_mult, hit_count, i)


## 单段伤害执行（公共方法，避免重复代码）
func _deal_hit(target: Combatant, skill_mult: float, skill_acc: float, dmg_type: String, bp_mult: float, total_hits: int, hit_index: int) -> void:
	var ctx = DamageContext.new(
		executor, target, dmg_type,
		skill_mult, skill_acc, bp_mult
	)
	var result = DamageCalculator.calculate(ctx)
	target.take_damage(result, dmg_type, executor.stats.unit_name)

	# 多段攻击间的视觉间隔
	if total_hits > 1 and hit_index < total_hits - 1:
		await executor.visual_unit.get_tree().create_timer(0.2).timeout
