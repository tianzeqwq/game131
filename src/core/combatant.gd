class_name Combatant
extends RefCounted

signal state_changed

# ------------------------------------------------------------
#  Priority Tier 常量（行动顺位层级）
#  用于时间轴排序：高层级者必定优先于低层级者行动
# ------------------------------------------------------------
const TIER_ABSOLUTE_FIRST: int = 3   # Break 恢复回合，绝对先手
const TIER_PREEMPTIVE: int   = 2     # 使用先制技能
const TIER_NORMAL: int       = 1     # 默认层级
const TIER_POSTEMPTIVE: int  = 0     # 使用后制技能

var stats: CharacterStats
var visual_unit: CombatUnit
var is_player: bool = false

# Runtime Stats
var hp: float:
	set(v):
		hp = clamp(v, 0, stats.max_hp)
		stats.hp = hp
		state_changed.emit()

var shield_points: int:
	set(v):
		shield_points = clampi(v, 0, stats.max_shield_points)
		stats.shield_points = shield_points
		state_changed.emit()

var firewall_hp: float:
	set(v):
		firewall_hp = clamp(v, 0, stats.max_firewall_hp)
		stats.firewall_hp = firewall_hp
		state_changed.emit()

var heat: float:
	set(v):
		heat = clamp(v, 0, 100)
		stats.heat = heat
		state_changed.emit()

# Octopath Traveler mechanics
var bp: int = 1:
	set(v):
		bp = clamp(v, 0, 5)
		state_changed.emit()

var is_broken: bool = false
var break_rounds_left: int = 0
var is_defending: bool = false
var can_gain_bp_next_round: bool = true

# ------------------------------------------------------------
#  Priority Tier 系统
#  current_priority_tier — 当前回合用于排序的层级
#  next_round_priority_tier — 下一回合的层级（先制/后制技能或Break恢复设置此处）
# ------------------------------------------------------------
## 当前回合的顺位层级（由 next_round_priority_tier 在回合开始时转入）
var current_priority_tier: int = TIER_NORMAL

## 下回合的顺位层级（先制/后制技能或 Break 恢复修改此值）
var next_round_priority_tier: int = TIER_NORMAL

# ------------------------------------------------------------
#  Buff / Debuff 系统（轻量级字典）
#  TODO: 后续可重构为独立的 BuffManager 或 Buff Resource
#  标准化 Key 常量见 DamageCalculator (BUFF_ATK_UP 等)
# ------------------------------------------------------------
var _buffs: Dictionary = {}

func add_buff(buff_key: String, duration: int = 1) -> void:
	_buffs[buff_key] = duration
	state_changed.emit()

func remove_buff(buff_key: String) -> void:
	_buffs.erase(buff_key)
	state_changed.emit()

func has_buff(buff_key: String) -> bool:
	return _buffs.has(buff_key)

func clear_all_buffs() -> void:
	_buffs.clear()
	state_changed.emit()

## 每回合结束时 tick 所有 Buff 的持续时间，到期自动移除
func _tick_buffs() -> void:
	var expired: Array[String] = []
	for key in _buffs.keys():
		_buffs[key] -= 1
		if _buffs[key] <= 0:
			expired.append(key)
	for key in expired:
		_buffs.erase(key)
	if not expired.is_empty():
		state_changed.emit()


func _init(unit: CombatUnit, p_is_player: bool = false) -> void:
	visual_unit = unit
	is_player = p_is_player
	stats = unit.stats
	
	# Initialize runtime stats from starting stats
	hp = stats.hp
	shield_points = stats.shield_points
	firewall_hp = stats.firewall_hp
	heat = stats.heat

## 获取当前角色可以使用的技能列表
func get_available_skills() -> Array[SkillConfig]:
	if not is_alive() or is_broken:
		return []
	return stats.skills

func is_alive() -> bool:
	return hp > 0

## 新版 take_damage：接收 DamageResult，仅负责执行（扣血 + 削盾 + Break）
##
## DamageCalculator 已算出 final_damage，这里只做：
## 1. 护盾/防火墙削减（Break 判定）
## 2. HP 扣减
## 3. 通过 CombatEventBus 发布领域事件（不再直接发射格式化日志）
func take_damage(damage_result: DamageResult, damage_type: String, attacker_name: String = "未知单位") -> void:
	if hp <= 0 or not damage_result.is_hit:
		return
	
	var shield_lost: float = 0.0
	var was_kill: bool = false
	
	# ----- 护盾/防火墙削减 & Break 判定 -----
	if not is_broken:
		if damage_type == "physical" and stats.weaknesses.has("physical"):
			if shield_points > 0:
				shield_points = max(0, shield_points - 1)
				shield_lost = 1.0
				if shield_points <= 0:
					_trigger_break()
		elif damage_type == "digital" and stats.weaknesses.has("digital"):
			if firewall_hp > 0:
				# 数字攻击按伤害值削减防火墙
				firewall_hp = max(0, firewall_hp - damage_result.final_damage)
				shield_lost = damage_result.final_damage
				if firewall_hp <= 0:
					_trigger_break()

	# ----- HP 扣减 -----
	hp -= damage_result.effective_damage

	# ----- 发布伤害领域事件（含中间计算值）-----
	if hp <= 0:
		hp = 0
		was_kill = true
	
	var event = CombatEventDamage.new(
		attacker_name,
		stats.unit_name,
		damage_type,
		damage_result.raw_damage,
		damage_result.final_damage,
		damage_result.effective_damage,
		damage_result.is_hit,
		damage_result.is_crit,
		damage_result.is_weakness,
		shield_lost,
		was_kill
	)
	
	# 透传计算过程中间值（供详细日志展示）
	event.atk_stat = damage_result.atk_stat
	event.def_stat = damage_result.def_stat
	event.def_multiplier = damage_result.def_multiplier
	event.attack_value = damage_result.attack_value
	event.defense_value = damage_result.defense_value
	event.base_damage = damage_result.base_damage
	event.ability_mod = damage_result.ability_mod
	event.status_mod = damage_result.status_mod
	event.level_mult = damage_result.level_mult
	event.calculated_damage = damage_result.calculated_damage
	event.random_factor = damage_result.random_factor
	event.forced_reduction = damage_result.forced_reduction
	event.skill_multiplier = damage_result.skill_multiplier
	event.bp_multiplier = damage_result.bp_multiplier
	
	CombatEventBus.publish(event)

func _trigger_break() -> void:
	is_broken = true
	break_rounds_left = 2
	is_defending = false
	
	# 🌟 发布 Break 领域事件（不再发射格式化字符串）
	CombatEventBus.publish(
		CombatEventBreak.new(stats.unit_name, "shield" if stats.weaknesses.has("physical") else "firewall", false)
	)

func add_heat(amount: float) -> void:
	heat += amount
	
	# 🌟 发布 Heat 领域事件
	CombatEventBus.publish(
		CombatEventHeat.new(stats.unit_name, amount, heat, "add")
	)
	
	if heat >= 100.0:
		apply_overload_penalty()
	elif heat >= 80.0:
		# 超频警告不再直接输出日志，由格式化器根据 heat 事件决定
		pass

func apply_overload_penalty() -> void:
	var damage = stats.max_hp * 0.3
	hp -= damage
	heat = 0
	
	# 🌟 发布 Overload 领域事件
	CombatEventBus.publish(
		CombatEventHeat.new(stats.unit_name, damage, heat, "overload")
	)

func check_turn_start_heat() -> void:
	if heat >= 80.0 and heat < 100.0:
		var tick_damage = stats.max_hp * 0.3
		hp -= tick_damage
		
		# 🌟 发布 Heat tick 领域事件
		CombatEventBus.publish(
			CombatEventHeat.new(stats.unit_name, tick_damage, heat, "tick")
		)

func get_attack_multiplier() -> float:
	# TODO: 此方法将被 DamageCalculator 的状态加成替代，保留作为过渡
	return 1.5 if heat >= 80.0 else 1.0

func on_round_start() -> void:
	# 层级过渡：将 next_round_priority_tier 转入当前回合
	current_priority_tier = next_round_priority_tier
	next_round_priority_tier = TIER_NORMAL
	
	is_defending = false
	check_turn_start_heat()

func on_round_end() -> void:
	# Break 恢复
	if is_broken:
		break_rounds_left -= 1
		if break_rounds_left <= 0:
			is_broken = false
			shield_points = stats.max_shield_points
			firewall_hp = stats.max_firewall_hp
			
			# 设置下回合为绝对先手（Break 恢复后的奖励）
			next_round_priority_tier = TIER_ABSOLUTE_FIRST
			
			# 🌟 发布 Break Recovery 领域事件
			CombatEventBus.publish(
				CombatEventBreak.new(stats.unit_name, "shield", true)
			)
	
	# BP 恢复
	if not is_broken:
		if can_gain_bp_next_round:
			bp = min(5, bp + 1)
		else:
			can_gain_bp_next_round = true
	
	# Buff 持续时间 tick
	_tick_buffs()
