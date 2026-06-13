class_name DamageCalculator
extends RefCounted

## ============================================================
#  伤害计算引擎（纯函数、无副作用）
#
#  职责：根据 DamageContext 计算最终伤害并返回 DamageResult。
#  不修改任何 Combatant 的状态——只算数字，不执行扣血。
#  不构建任何日志文本——日志格式化已交由 CombatLogFormatter 处理。
#
#  设计原则：
#  1. 纯函数式：相同的输入永远得到相同的输出（除随机浮动外）
#  2. 魔术数字全部定义为命名常量
#  3. 每个子步骤拆分为独立的私有方法，便于阅读和测试
#  4. 不包含任何 UI 格式信息（BBCode 等）
# ============================================================

# ---------- 魔术数字常量 ----------
const ACCURACY_DIVISOR := 200.0
const CRIT_DIVISOR := 200.0

const DEFENDING_MULTIPLIER := 0.65
const NORMAL_DEFENSE_MULTIPLIER := 0.5

const LEVEL_BASE := 0.58
const LEVEL_FACTOR := 0.01

const MAX_DAMAGE := 9999.0
const MIN_DAMAGE := 0.0

const RANDOM_FLOAT_MIN := 0.98
const RANDOM_FLOAT_MAX := 1.02

# ---------- 状态加成常量 ----------
const STATUS_ATK_UP := 1.5      # 攻击/魔攻上升
const STATUS_ATK_DOWN := 1.5    # 攻击/魔攻下降（做除数）
const STATUS_DEF_UP := 1.5      # 物防/魔防上升（做除数）
const STATUS_DEF_DOWN := 1.5    # 物防/魔防下降
const WEAKNESS_MULTIPLIER := 1.3
const BREAK_MULTIPLIER := 2.0
const CRIT_MULTIPLIER := 1.25

# ---------- Buff/Debuff Key 常量 ----------
const BUFF_ATK_UP := "atk_up"       # 攻击方物攻上升
const BUFF_MATK_UP := "matk_up"     # 攻击方魔攻上升
const BUFF_ATK_DOWN := "atk_down"   # 攻击方物攻下降
const BUFF_MATK_DOWN := "matk_down" # 攻击方魔攻下降
const BUFF_DEF_UP := "def_up"       # 受击方物防上升
const BUFF_MDEF_UP := "mdef_up"     # 受击方魔防上升
const BUFF_DEF_DOWN := "def_down"   # 受击方物防下降
const BUFF_MDEF_DOWN := "mdef_down" # 受击方魔防下降

# BP 增幅倍率表: index = boost_level
const BP_MULTIPLIERS := [1.0, 1.5, 2.0, 2.5]


static func calculate(context: DamageContext) -> DamageResult:
	var result = DamageResult.new()

	# ----- 阶段 1: 命中判定 -----
	result.is_hit = _roll_hit(context)
	if not result.is_hit:
		return result

	# ----- 阶段 2: 暴击判定 -----
	result.is_crit = context.is_crit_forced or _roll_crit(context)

	# ----- 阶段 3: 弱点判定 -----
	result.is_weakness = _check_weakness(context)

	# ----- 阶段 4: 基础伤害 -----
	result.atk_stat = _get_attacker_atk(context)
	result.def_stat = _get_defender_def(context)
	result.def_multiplier = _get_defense_multiplier(context.defender)

	result.attack_value = context.skill_multiplier * result.atk_stat
	result.defense_value = result.def_multiplier * result.def_stat

	result.base_damage = (result.attack_value - result.defense_value) * context.bp_multiplier
	# 伤害保底为 0，避免负伤害导致回血
	result.base_damage = max(MIN_DAMAGE, result.base_damage)

	# ----- 阶段 5: 演算伤害（能力加成 × 状态加成 × 等级倍率）-----
	result.ability_mod = context.attacker.stats.get_ability_modifier()
	result.status_mod = _get_status_multiplier(context, result)
	result.level_mult = LEVEL_BASE + LEVEL_FACTOR * context.attacker.stats.level

	result.calculated_damage = result.base_damage * result.ability_mod * result.status_mod * result.level_mult

	# ----- 阶段 6: 执行伤害（随机浮动 × 强制免伤，上限 9999）-----
	result.random_factor = randf_range(RANDOM_FLOAT_MIN, RANDOM_FLOAT_MAX)
	result.forced_reduction = _get_forced_reduction(context.defender)

	var executed_damage = result.calculated_damage * result.random_factor * result.forced_reduction
	executed_damage = clamp(executed_damage, MIN_DAMAGE, MAX_DAMAGE)

	result.raw_damage = executed_damage
	result.final_damage = round(executed_damage)

	# ----- 阶段 7: 有效伤害（不超过目标剩余 HP）-----
	result.effective_damage = min(result.final_damage, context.defender.hp)

	# ----- 上下文参数透传（供详细日志展示）-----
	result.skill_multiplier = context.skill_multiplier
	result.bp_multiplier = context.bp_multiplier
	result.hp_before_damage = context.defender.hp

	return result


# ============================================================
#  私有方法
# ============================================================

# ---------- 命中判定 ----------
static func _roll_hit(context: DamageContext) -> bool:
	var hit_rate = context.skill_accuracy + (context.attacker.stats.accuracy - context.defender.stats.evasion) / ACCURACY_DIVISOR
	hit_rate = clamp(hit_rate, 0.0, 1.0)
	return randf() < hit_rate


# ---------- 暴击判定 ----------
static func _roll_crit(context: DamageContext) -> bool:
	var crit_rate = (context.attacker.stats.crit - context.defender.stats.speed) / CRIT_DIVISOR
	crit_rate = clamp(crit_rate, 0.0, 1.0)
	return randf() < crit_rate


# ---------- 弱点判定 ----------
static func _check_weakness(context: DamageContext) -> bool:
	return context.defender.stats.weaknesses.has(context.damage_type)


# ---------- 根据伤害类型选择攻击力 ----------
static func _get_attacker_atk(context: DamageContext) -> float:
	match context.damage_type:
		"physical":
			return context.attacker.stats.phys_atk
		"digital":
			return context.attacker.stats.digi_atk
		_:
			push_warning("DamageCalculator: 未知伤害类型 '%s'，默认使用 phys_atk" % context.damage_type)
			return context.attacker.stats.phys_atk


# ---------- 根据伤害类型选择防御力 ----------
static func _get_defender_def(context: DamageContext) -> float:
	match context.damage_type:
		"physical":
			return context.defender.stats.phys_def
		"digital":
			return context.defender.stats.digi_def
		_:
			push_warning("DamageCalculator: 未知伤害类型 '%s'，默认使用 phys_def" % context.damage_type)
			return context.defender.stats.phys_def


# ---------- 防御状态倍率 ----------
static func _get_defense_multiplier(defender: Combatant) -> float:
	return DEFENDING_MULTIPLIER if defender.is_defending else NORMAL_DEFENSE_MULTIPLIER


# ---------- 状态加成总倍率 ----------
static func _get_status_multiplier(context: DamageContext, result: DamageResult) -> float:
	var mod := 1.0

	# 1) 攻击方 Buff：攻击/魔攻上升 → *1.5，下降 → /1.5
	if context.attacker.has_buff(BUFF_ATK_UP) or context.attacker.has_buff(BUFF_MATK_UP):
		mod *= STATUS_ATK_UP
	if context.attacker.has_buff(BUFF_ATK_DOWN) or context.attacker.has_buff(BUFF_MATK_DOWN):
		mod /= STATUS_ATK_DOWN

	# 2) 受击方 Buff：物防/魔防上升 → /1.5，下降 → *1.5
	if context.defender.has_buff(BUFF_DEF_UP) or context.defender.has_buff(BUFF_MDEF_UP):
		mod /= STATUS_DEF_UP
	if context.defender.has_buff(BUFF_DEF_DOWN) or context.defender.has_buff(BUFF_MDEF_DOWN):
		mod *= STATUS_DEF_DOWN

	# 3) 弱点加成
	if result.is_weakness:
		mod *= WEAKNESS_MULTIPLIER

	# 4) 破防加成
	if context.defender.is_broken:
		mod *= BREAK_MULTIPLIER

	# 5) 暴击加成
	if result.is_crit:
		mod *= CRIT_MULTIPLIER

	return mod


# ---------- 强制免伤（预留接口） ----------
static func _get_forced_reduction(defender: Combatant) -> float:
	# TODO: 后续可由受击方的 Barrier/Invincible 状态覆盖
	return 1.0
