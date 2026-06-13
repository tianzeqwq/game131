class_name BattleTimeline
extends RefCounted

# The current round's sorted list of combatants yet to act
var active_queue: Array[Combatant] = []
# Preview of the next round's action order (for UI display)
var next_round_queue: Array[Combatant] = []

# Generate timeline order for both the current round and next round preview
func generate_timeline(all_combatants: Array[Combatant]) -> void:
	active_queue = _sort_combatants(all_combatants, false)
	next_round_queue = _sort_combatants(all_combatants, true)

## 计算角色的"本回合行动点数"
##
## 公式：行动点数 = 速度 + 随机数(0, 100)
##
## - 随机数使得每回合出手顺序都有剧烈洗牌，增加策略深度
## - 下一轮预览时不加随机数（展示确定性排序供参考）
func _calculate_action_points(combatant: Combatant, is_next_round: bool = false) -> int:
	var random_factor: int = 0 if is_next_round else randi_range(0, 100)
	return combatant.stats.speed + random_factor

## 获取指定 Combatant 在当前轮/预览轮中使用的 Priority Tier
func _get_priority_tier(c: Combatant, is_next_round: bool) -> int:
	return c.next_round_priority_tier if is_next_round else c.current_priority_tier

# Sort combatants by priority tier first, then action points, then tie-breakers
func _sort_combatants(units: Array[Combatant], is_next_round: bool = false) -> Array[Combatant]:
	var active_units = units.filter(func(u): return u.is_alive())
	
	# ⚠️ 预计算行动点数，避免在比较器内调用 randi_range()
	# 比较器必须是纯函数（幂等、无副作用），否则 Godot 的排序会因
	# 比较结果不一致抛出 "bad comparison function" 错误。
	var point_cache: Dictionary = {}
	for u in active_units:
		point_cache[u] = _calculate_action_points(u, is_next_round)
	
	active_units.sort_custom(func(a: Combatant, b: Combatant):
		# Rule 1: Priority Tier 排序（高层级必定先出手）
		#   TIER_ABSOLUTE_FIRST (3) > TIER_PREEMPTIVE (2) > TIER_NORMAL (1) > TIER_POSTEMPTIVE (0)
		var tier_a = _get_priority_tier(a, is_next_round)
		var tier_b = _get_priority_tier(b, is_next_round)
		if tier_a != tier_b:
			return tier_a > tier_b
		
		# Rule 2: Defending units act first (仅在 NORMAL 层级生效)
		# Defending states only apply to the current round. Next round preview does not assume defending
		var a_defending = a.is_defending if not is_next_round else false
		var b_defending = b.is_defending if not is_next_round else false
		if a_defending != b_defending:
			return a_defending
		
		# Rule 3: 行动点数比较 — 使用预缓存的值（避免比较器内调用随机函数）
		var points_a = point_cache[a]
		var points_b = point_cache[b]
		if points_a != points_b:
			return points_a > points_b
		
		# Rule 4: Tie breaker by unit type (Players first)
		if a.is_player != b.is_player:
			return a.is_player
			
		return false
	)
	return active_units

# Retrieve the next combatant who should act
func get_next_up() -> Combatant:
	# Filter out any combatants that might have died mid-round
	while not active_queue.is_empty():
		var unit = active_queue.pop_front()
		if unit.is_alive():
			return unit
	return null

## Break 发生时：从 active_queue + next_round_queue 中同步移除
## 返回 true 表示 active_queue 中有该单位（时机 A），false 表示已行动（时机 B）
func apply_break(combatant: Combatant) -> bool:
	var was_in_active = combatant in active_queue
	active_queue.erase(combatant)
	next_round_queue.erase(combatant)  # 同步更新预览队列，剔除被 Break 的单位
	return was_in_active

# Remove a dead unit from both queues
func remove_unit(unit: Combatant) -> void:
	active_queue.erase(unit)
	next_round_queue.erase(unit)

# Return the full list of remaining actions in the current round
func get_active_queue() -> Array[Combatant]:
	return active_queue

# Return the full preview queue for the next round
func get_next_round_queue() -> Array[Combatant]:
	return next_round_queue
