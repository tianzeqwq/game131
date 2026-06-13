class_name CombatLogAdapter
extends RefCounted

## 战斗事件 → 通用日志 桥接适配器
##
## 监听 CombatEventBus 发布的领域事件，
## 将其转换为通用的 LogEvent，通过 GameLogger 进入统一日志管线。
##
## 这样 Combat 系统仍保留丰富的领域事件结构（CombatEventDamage 等），
## 同时日志输出走统一的 GameLogger → LogRouter → LogSink 管线。

## 详细模式：true=完整计算过程，false=仅摘要
var verbose_mode: bool = true


func start_listening() -> void:
	CombatEventBus.event_dispatched.connect(_on_combat_event)


func stop_listening() -> void:
	if CombatEventBus.event_dispatched.is_connected(_on_combat_event):
		CombatEventBus.event_dispatched.disconnect(_on_combat_event)


func _on_combat_event(event: CombatEvent) -> void:
	var msg := _to_message(event)
	if msg.is_empty():
		return

	var ctx := _to_context(event)
	GameLogger.info("combat", msg, ctx)


## 将 CombatEvent 转为人类可读的消息字符串
func _to_message(event: CombatEvent) -> String:
	if event is CombatEventDamage:
		return _damage_message(event as CombatEventDamage)
	if event is CombatEventBreak:
		return _break_message(event as CombatEventBreak)
	if event is CombatEventHeat:
		return _heat_message(event as CombatEventHeat)
	if event is CombatEventAction:
		return _action_message(event as CombatEventAction)
	if event is CombatEventFlow:
		return _flow_message(event as CombatEventFlow)
	if event is CombatEventSkillSelect:
		return _skill_select_message(event as CombatEventSkillSelect)
	return ""


## 提取结构化上下文数据（供 AnalyticsSink 等消费）
func _to_context(event: CombatEvent) -> Dictionary:
	if event is CombatEventDamage:
		var d := event as CombatEventDamage
		return {
			"type": "damage",
			"attacker": d.attacker_name,
			"target": d.target_name,
			"damage_type": d.damage_type,
			"final_damage": d.final_damage,
			"is_hit": d.is_hit,
			"is_crit": d.is_crit,
			"is_kill": d.is_kill,
			"is_weakness": d.is_weakness,
			"shield_damaged": d.shield_damaged,
			"effective_damage": d.effective_damage,
		}
	if event is CombatEventBreak:
		var b := event as CombatEventBreak
		return {
			"type": "break",
			"unit": b.unit_name,
			"is_recovery": b.is_recovery,
		}
	if event is CombatEventHeat:
		var h := event as CombatEventHeat
		return {
			"type": "heat",
			"unit": h.unit_name,
			"event_type": h.event_type,
			"heat_amount": h.heat_amount,
			"current_heat": h.current_heat,
		}
	return {}


# ============================================================
#  消息生成（含两种详细度，不含 BBCode）
# ============================================================

func _damage_message(d: CombatEventDamage) -> String:
	if not d.is_hit:
		return "%s 攻击 %s — MISS!" % [d.attacker_name, d.target_name]

	if verbose_mode:
		return _damage_message_verbose(d)
	return _damage_message_summary(d)


func _damage_message_summary(d: CombatEventDamage) -> String:
	var type_label := "物理" if d.damage_type == "physical" else "数字"
	var tags: Array[String] = []
	if d.is_weakness:
		tags.append("弱点打击")
	if d.is_crit:
		tags.append("暴击")
	if d.shield_damaged > 0:
		tags.append("护盾-%.0f" % d.shield_damaged)
	if d.is_kill:
		tags.append("击杀")
	if d.effective_damage < d.final_damage:
		tags.append("溢出%.0f" % (d.final_damage - d.effective_damage))

	var msg := "%s → %s: %.0f %s伤害" % [d.attacker_name, d.target_name, d.final_damage, type_label]
	if not tags.is_empty():
		msg += " (%s)" % ", ".join(tags)
	return msg


func _damage_message_verbose(d: CombatEventDamage) -> String:
	var type_label := "物理" if d.damage_type == "physical" else "数字"
	var lines: Array[String] = []

	# 标题
	lines.append("━━━ %s ─── %s (%s) ━━━" % [d.attacker_name, d.target_name, type_label])

	# 阶段 4: 基础伤害
	lines.append("[④ 基础伤害]")
	lines.append("  攻击力: %.1f × 技能倍率 %.1f = %.1f" % [d.atk_stat, d.skill_multiplier, d.attack_value])
	lines.append("  防御力: %.1f × 防御倍率 %.1f = %.1f" % [d.def_stat, d.def_multiplier, d.defense_value])
	lines.append("  (%.1f - %.1f) × BP %.1f = %.1f (基础伤害)" % [d.attack_value, d.defense_value, d.bp_multiplier, d.base_damage])

	# 阶段 5: 演算伤害
	lines.append("[⑤ 演算伤害]")
	var buff_str := ""
	if d.status_mod != 1.0:
		buff_str = " × 状态加成 %.2f" % d.status_mod
	lines.append("  %.1f × 能力 %.1f%s × 等级 %.2f = %.1f" % [d.base_damage, d.ability_mod, buff_str, d.level_mult, d.calculated_damage])

	# 阶段 6: 执行伤害
	lines.append("[⑥ 执行伤害]")
	lines.append("  %.1f × 随机 %.4f × 免伤 %.1f = %.1f" % [d.calculated_damage, d.random_factor, d.forced_reduction, d.raw_damage])
	lines.append("  → 取整 %.0f" % d.final_damage)

	# 阶段 7: 有效伤害
	lines.append("[⑦ 有效伤害] min(%.0f, %.0f) = %.0f" % [d.final_damage, _hp_before(d), d.effective_damage])

	# 标识
	var tags: Array[String] = []
	if d.is_weakness:
		tags.append("弱点打击!")
	if d.is_crit:
		tags.append("暴击 x1.25")
	if d.shield_damaged > 0:
		tags.append("护盾削减 %.0f" % d.shield_damaged)
	if d.effective_damage < d.final_damage:
		tags.append("溢出 %.0f" % (d.final_damage - d.effective_damage))
	if d.is_kill:
		tags.append("击杀!")
	if not tags.is_empty():
		lines.append("  ⚡ %s" % " | ".join(tags))

	lines.append("━━━━━━━━━━━━━━━━━━")
	return "\n".join(lines)


## 估算受击前 HP
func _hp_before(d: CombatEventDamage) -> float:
	if d.effective_damage < d.final_damage:
		return d.effective_damage
	return d.final_damage


func _break_message(b: CombatEventBreak) -> String:
	if b.is_recovery:
		return "%s Break恢复" % b.unit_name
	return "%s 陷入Break瘫痪!" % b.unit_name


func _heat_message(h: CombatEventHeat) -> String:
	match h.event_type:
		"add":
			return "%s 负载+%.0f%% (当前%.0f%%)" % [h.unit_name, h.heat_amount, h.current_heat]
		"overload":
			return "%s 过载! 受到%.0f反噬伤害" % [h.unit_name, h.heat_amount]
		"tick":
			return "%s 超频反噬: -%.0f HP" % [h.unit_name, h.heat_amount]
		"reset":
			return "%s 负载清零" % h.unit_name
		_:
			return "%s 负载变化%.0f%%" % [h.unit_name, h.heat_amount]


func _action_message(a: CombatEventAction) -> String:
	match a.action_type:
		"boost":
			return "%s Boost x%d!" % [a.unit_name, int(a.value)]
		"defend":
			return "%s 进入防守姿态" % a.unit_name
		"death":
			return "%s 已倒下" % a.unit_name
		_:
			return "%s 执行 %s" % [a.unit_name, a.action_type]


func _flow_message(f: CombatEventFlow) -> String:
	match f.flow_type:
		"round_started":
			return "=== 第%d回合开始 ===" % f.round_number
		"unit_skipped":
			return "%s 因Break跳过行动" % f.unit_name
		"enemy_analyzing":
			return "%s 正在分析..." % f.unit_name
		_:
			return "战斗流程: %s" % f.flow_type


func _skill_select_message(s: CombatEventSkillSelect) -> String:
	match s.action_type:
		"open":
			return "%s 打开技能面板 (BP:%d/%d)" % [s.unit_name, s.current_bp, s.max_bp]
		"select":
			return "%s 选中: %s" % [s.unit_name, s.skill_name]
		"boost":
			return "%s Boost调整至×%d" % [s.unit_name, int(s.value)]
		"confirm":
			return "%s 确认: %s ×%d" % [s.unit_name, s.skill_name, int(s.value)]
		"cancel":
			return "%s 取消技能选择" % s.unit_name
		_:
			return "%s 技能: %s (%s)" % [s.unit_name, s.skill_name, s.action_type]
