class_name CombatLogFormatter
extends RefCounted

## ⚠️ 已废弃 — 格式化逻辑已分散到各 Sink 和 CombatLogAdapter
##
## 保留供参考。新代码请直接：
##   - 在 UISink 中处理 BBCode 格式化
##   - 在 CombatLogAdapter 中处理战斗消息生成
##   - 使用 GameLogger.info("combat", ...) 直接记录

## 日志格式化器（旧版）
##
## 负责将结构化的 CombatEvent 数据转换为人类可读的字符串。
## 遵循单一职责原则 (SRP)：所有格式化逻辑集中在此类。
## 遵守依赖倒置原则 (DIP)：核心逻辑只产生事件，格式化由本类完成。
##
## 提供两种输出格式：
## - BBCode：用于 UI RichTextLabel（带颜色标签）
## - Plain Text：用于控制台和文件输出（无格式标记）
##
## 各提供两种详细度：
## - 简洁模式：一行摘要
## - 详细模式：含完整计算过程（仅对伤害事件有效）

# ============================================================
#  UI BBCode 格式化 - 简洁模式
# ============================================================

static func format_to_bbcode(event: CombatEvent) -> String:
	if event is CombatEventDamage:
		return _format_damage_bbcode(event as CombatEventDamage)
	if event is CombatEventBreak:
		return _format_break_bbcode(event as CombatEventBreak)
	if event is CombatEventHeat:
		return _format_heat_bbcode(event as CombatEventHeat)
	if event is CombatEventAction:
		return _format_action_bbcode(event as CombatEventAction)
	if event is CombatEventFlow:
		return _format_flow_bbcode(event as CombatEventFlow)
	if event is CombatEventSkillSelect:
		return _format_skill_select_bbcode(event as CombatEventSkillSelect)
	return ""

# ============================================================
#  UI BBCode 格式化 - 详细模式
# ============================================================

static func format_to_bbcode_verbose(event: CombatEvent) -> String:
	if event is CombatEventDamage:
		return _format_damage_bbcode_verbose(event as CombatEventDamage)
	# 非伤害事件，详细模式与简洁模式相同
	if event is CombatEventBreak:
		return _format_break_bbcode(event as CombatEventBreak)
	if event is CombatEventHeat:
		return _format_heat_bbcode(event as CombatEventHeat)
	if event is CombatEventAction:
		return _format_action_bbcode(event as CombatEventAction)
	if event is CombatEventFlow:
		return _format_flow_bbcode(event as CombatEventFlow)
	if event is CombatEventSkillSelect:
		return _format_skill_select_bbcode(event as CombatEventSkillSelect)
	return ""

# -----------------------------------------------------------
#  Damage BBCode 详细模式（含完整计算过程）
# -----------------------------------------------------------
static func _format_damage_bbcode_verbose(evt: CombatEventDamage) -> String:
	if not evt.is_hit:
		return "[color=gray]%s 攻击 %s — MISS! 未命中！[/color]" % [evt.attacker_name, evt.target_name]

	var type_label = "物理" if evt.damage_type == "physical" else "数字"
	var lines: Array[String] = []

	# 标题行
	lines.append("[color=yellow]━━━ %s ─── %s (%s) ━━━[/color]" % [evt.attacker_name, evt.target_name, type_label])

	# 阶段 4: 基础伤害
	lines.append("[color=white]④ 基础伤害计算:[/color]")
	lines.append("  攻击力: [color=yellow]%.1f[/color] × 技能倍率 [color=yellow]%.1f[/color] = [color=orange]%.1f[/color]" % [evt.atk_stat, evt.skill_multiplier, evt.attack_value])
	lines.append("  防御力: [color=cyan]%.1f[/color] × 防御倍率 [color=cyan]%.1f[/color] = [color=orange]%.1f[/color]" % [evt.def_stat, evt.def_multiplier, evt.defense_value])
	lines.append("  (%.1f - %.1f) × BP %.1f = [color=orange]%.1f[/color] (基础伤害)" % [evt.attack_value, evt.defense_value, evt.bp_multiplier, evt.base_damage])

	# 阶段 5: 演算伤害
	lines.append("[color=white]⑤ 演算伤害:[/color]")
	var buff_str = ""
	if evt.status_mod != 1.0:
		buff_str = " × 状态加成 [color=purple]%.2f[/color]" % evt.status_mod
	lines.append("  %.1f × 能力 %.1f%s × 等级 %.2f = [color=orange]%.1f[/color]" % [
		evt.base_damage, evt.ability_mod, buff_str, evt.level_mult, evt.calculated_damage
	])

	# 阶段 6: 执行伤害
	lines.append("[color=white]⑥ 执行伤害:[/color]")
	lines.append("  %.1f × 随机 %.4f × 免伤 %.1f = [color=orange]%.1f[/color]" % [
		evt.calculated_damage, evt.random_factor, evt.forced_reduction, evt.raw_damage
	])
	lines.append("  → 取整 [color=red]%.0f[/color]" % evt.final_damage)

	# 阶段 7: 有效伤害
	var hp_before = _get_hp_before(evt)
	lines.append("[color=white]⑦ 有效伤害: min(%.0f, %.0f) = [color=red]%.0f[/color][/color]" % [
		evt.final_damage, hp_before, evt.effective_damage
	])

	# 特殊标识
	var tags: Array[String] = []
	if evt.is_weakness:
		tags.append("[color=cyan]弱点打击![/color]")
	if evt.is_crit:
		tags.append("[color=orange]暴击! x1.25[/color]")
	if evt.shield_damaged > 0:
		tags.append("(护盾削减 %.0f 点)" % evt.shield_damaged)
	if evt.effective_damage < evt.final_damage:
		tags.append("[color=gray](溢出 %.0f)[/color]" % (evt.final_damage - evt.effective_damage))
	if evt.is_kill:
		tags.append("[color=red]💀 击杀![/color]")
	if not tags.is_empty():
		lines.append("[color=white]⚡ [/color]" + " ".join(tags))

	lines.append("[color=yellow]━━━━━━━━━━━━━━━━━━━━━━[/color]")
	return "\n".join(lines)


# ============================================================
#  纯文本格式化 - 简洁模式（全中文）
# ============================================================

static func format_to_plain_text(event: CombatEvent) -> String:
	if event is CombatEventDamage:
		return _format_damage_plain(event as CombatEventDamage)
	if event is CombatEventBreak:
		return _format_break_plain(event as CombatEventBreak)
	if event is CombatEventHeat:
		return _format_heat_plain(event as CombatEventHeat)
	if event is CombatEventAction:
		return _format_action_plain(event as CombatEventAction)
	if event is CombatEventFlow:
		return _format_flow_plain(event as CombatEventFlow)
	if event is CombatEventSkillSelect:
		return _format_skill_select_plain(event as CombatEventSkillSelect)
	return ""

# ============================================================
#  纯文本格式化 - 详细模式（全中文）
# ============================================================

static func format_to_plain_text_verbose(event: CombatEvent) -> String:
	if event is CombatEventDamage:
		return _format_damage_plain_verbose(event as CombatEventDamage)
	if event is CombatEventBreak:
		return _format_break_plain(event as CombatEventBreak)
	if event is CombatEventHeat:
		return _format_heat_plain(event as CombatEventHeat)
	if event is CombatEventAction:
		return _format_action_plain(event as CombatEventAction)
	if event is CombatEventFlow:
		return _format_flow_plain(event as CombatEventFlow)
	if event is CombatEventSkillSelect:
		return _format_skill_select_plain(event as CombatEventSkillSelect)
	return ""

# -----------------------------------------------------------
#  Damage Plain Text 详细模式（含完整计算过程，中文）
# -----------------------------------------------------------
static func _format_damage_plain_verbose(evt: CombatEventDamage) -> String:
	if not evt.is_hit:
		return "%s 攻击 %s — MISS! 未命中！" % [evt.attacker_name, evt.target_name]

	var type_label = "物理" if evt.damage_type == "physical" else "数字"
	var lines: Array[String] = []

	# 标题
	lines.append("━━━ %s ─── %s (%s) ━━━" % [evt.attacker_name, evt.target_name, type_label])

	# 阶段 4
	lines.append("[④ 基础伤害]")
	lines.append("  攻击力: %.1f × 技能倍率 %.1f = %.1f" % [evt.atk_stat, evt.skill_multiplier, evt.attack_value])
	lines.append("  防御力: %.1f × 防御倍率 %.1f = %.1f" % [evt.def_stat, evt.def_multiplier, evt.defense_value])
	lines.append("  (%.1f - %.1f) × BP %.1f = %.1f (基础伤害)" % [evt.attack_value, evt.defense_value, evt.bp_multiplier, evt.base_damage])

	# 阶段 5
	lines.append("[⑤ 演算伤害]")
	var buff_str = ""
	if evt.status_mod != 1.0:
		buff_str = " × 状态加成 %.2f" % evt.status_mod
	lines.append("  %.1f × 能力 %.1f%s × 等级 %.2f = %.1f" % [
		evt.base_damage, evt.ability_mod, buff_str, evt.level_mult, evt.calculated_damage
	])

	# 阶段 6
	lines.append("[⑥ 执行伤害]")
	lines.append("  %.1f × 随机 %.4f × 免伤 %.1f = %.1f" % [
		evt.calculated_damage, evt.random_factor, evt.forced_reduction, evt.raw_damage
	])
	lines.append("  → 取整 %.0f" % evt.final_damage)

	# 阶段 7
	var hp_before = _get_hp_before(evt)
	lines.append("[⑦ 有效伤害] min(%.0f, %.0f) = %.0f" % [
		evt.final_damage, hp_before, evt.effective_damage
	])

	# 标识
	var tags: Array[String] = []
	if evt.is_weakness:
		tags.append("弱点打击!")
	if evt.is_crit:
		tags.append("暴击 x1.25")
	if evt.shield_damaged > 0:
		tags.append("护盾削减 %.0f" % evt.shield_damaged)
	if evt.effective_damage < evt.final_damage:
		tags.append("溢出 %.0f" % (evt.final_damage - evt.effective_damage))
	if evt.is_kill:
		tags.append("击杀!")
	if not tags.is_empty():
		lines.append("  ⚡ " + " | ".join(tags))

	lines.append("━━━━━━━━━━━━━━━━━━")
	return "\n".join(lines)


# ============================================================
#  BBCode 子格式化器
# ============================================================

static func _format_damage_bbcode(evt: CombatEventDamage) -> String:
	if not evt.is_hit:
		return "[color=gray]%s 攻击 %s — MISS! 未命中！[/color]" % [evt.attacker_name, evt.target_name]

	var msg = "[color=yellow]%s[/color] 攻击 [color=white]%s[/color]，造成 [color=red]%.0f[/color] 点%s伤害。" % [
		evt.attacker_name, evt.target_name, evt.final_damage,
		"物理" if evt.damage_type == "physical" else "数字"
	]

	if evt.is_weakness:
		msg += " [color=cyan]弱点打击![/color]"
	if evt.is_crit:
		msg += " [color=orange]暴击! x1.25[/color]"
	if evt.shield_damaged > 0:
		msg += " (护盾削减 %.0f 点)" % evt.shield_damaged
	if evt.effective_damage < evt.final_damage:
		msg += " [color=gray](溢出 %.0f)[/color]" % (evt.final_damage - evt.effective_damage)
	if evt.is_kill:
		msg += " [color=red]💀 击杀![/color]"

	return msg

static func _format_break_bbcode(evt: CombatEventBreak) -> String:
	if evt.is_recovery:
		return "[color=green][%s] 系统防护重启完成，恢复正常运行。[/color]" % evt.unit_name
	return "[color=red]💥 !!! %s 陷入系统瘫痪 (Break) !!![/color]" % evt.unit_name

static func _format_heat_bbcode(evt: CombatEventHeat) -> String:
	match evt.event_type:
		"add":
			return "[color=cyan][%s] 负载上升 %.0f%% (当前: %.0f%%)[/color]" % [evt.unit_name, evt.heat_amount, evt.current_heat]
		"overload":
			return "[color=red][%s] !!! 负载 100%% 瞬间过载 !!! 受到 %.0f 点反噬伤害并强制清零负载。[/color]" % [evt.unit_name, evt.heat_amount]
		"tick":
			return "[color=orange][%s] 超频反噬：维持负载损耗了 %.0f 生命值。[/color]" % [evt.unit_name, evt.heat_amount]
		"reset":
			return "[color=cyan][%s] 负载已清零。[/color]" % evt.unit_name
		_:
			return "[color=cyan][%s] 负载变化 %.0f%% (当前: %.0f%%)[/color]" % [evt.unit_name, evt.heat_amount, evt.current_heat]

static func _format_action_bbcode(evt: CombatEventAction) -> String:
	match evt.action_type:
		"boost":
			return "[color=orange][%s] 释放提振 (Boost x%d)！[/color]" % [evt.unit_name, int(evt.value)]
		"defend":
			return "[color=green][%s] 摆出防守姿态，降低所受伤害，且下一轮将优先行动！[/color]" % evt.unit_name
		"death":
			return "[color=gray]--- %s 已倒下 ---[/color]" % evt.unit_name
		_:
			return "[color=white][%s] 执行了 %s[/color]" % [evt.unit_name, evt.action_type]


# ============================================================
#  CombatEventFlow BBCode 格式化
# ============================================================

static func _format_flow_bbcode(evt: CombatEventFlow) -> String:
	match evt.flow_type:
		"round_started":
			return "\n[color=cyan]▶▶▶ 第 %d 回合开始 ◀◀◀[/color]\n" % evt.round_number
		"unit_skipped":
			return "[color=red]● [%s] 处于瘫痪状态 (Break)，跳过本回合行动！[/color]\n" % evt.unit_name
		"enemy_analyzing":
			return "[color=gray]● [%s] 正在分析战场状态...[/color]\n" % evt.unit_name
		_:
			return "[color=white][%s] 战斗流程事件: %s[/color]\n" % [evt.unit_name, evt.flow_type]


# ============================================================
#  CombatEventSkillSelect BBCode 格式化
# ============================================================

static func _format_skill_select_bbcode(evt: CombatEventSkillSelect) -> String:
	match evt.action_type:
		"open":
			return "[color=cyan][%s] 打开技能选择面板 (BP: %d/%d)[/color]" % [evt.unit_name, evt.current_bp, evt.max_bp]
		"select":
			return "[color=white][%s] 选中技能: %s[/color]" % [evt.unit_name, evt.skill_name]
		"boost":
			return "[color=orange][%s] 调整增幅至 ×%d[/color]" % [evt.unit_name, int(evt.value)]
		"confirm":
			return "[color=yellow][%s] 确认技能: %s ×%d (消耗BP: %d)[/color]" % [evt.unit_name, evt.skill_name, int(evt.value), int(evt.value) - 1]
		"cancel":
			return "[color=gray][%s] 取消技能选择[/color]" % evt.unit_name
		_:
			return "[color=white][%s] 技能选择: %s (%s)[/color]" % [evt.unit_name, evt.action_type, evt.skill_name]


# ============================================================
#  Plain Text 子格式化器（中文）
# ============================================================

static func _format_damage_plain(evt: CombatEventDamage) -> String:
	if not evt.is_hit:
		return "%s 攻击 %s — MISS! 未命中！" % [evt.attacker_name, evt.target_name]

	var type_label = "物理" if evt.damage_type == "physical" else "数字"
	var msg = "%s 攻击 %s，造成 %.0f 点%s伤害。" % [
		evt.attacker_name, evt.target_name, evt.final_damage, type_label
	]

	if evt.is_weakness:
		msg += " [弱点打击!]"
	if evt.is_crit:
		msg += " [暴击 x1.25]"
	if evt.shield_damaged > 0:
		msg += " (护盾削减 %.0f)" % evt.shield_damaged
	if evt.effective_damage < evt.final_damage:
		msg += " (溢出 %.0f)" % (evt.final_damage - evt.effective_damage)
	if evt.is_kill:
		msg += " [击杀!]"

	return msg

static func _format_break_plain(evt: CombatEventBreak) -> String:
	if evt.is_recovery:
		return "[%s] 系统防护重启完成，恢复正常运行。" % evt.unit_name
	return "!!! %s 陷入系统瘫痪 (Break) !!!" % evt.unit_name

static func _format_heat_plain(evt: CombatEventHeat) -> String:
	match evt.event_type:
		"add":
			return "[%s] 负载上升 %.0f%% (当前: %.0f%%)" % [evt.unit_name, evt.heat_amount, evt.current_heat]
		"overload":
			return "[%s] !!! 负载 100%% 瞬间过载 !!! 受到 %.0f 点反噬伤害并强制清零负载。" % [evt.unit_name, evt.heat_amount]
		"tick":
			return "[%s] 超频反噬：维持负载损耗了 %.0f 生命值。" % [evt.unit_name, evt.heat_amount]
		"reset":
			return "[%s] 负载已清零。" % evt.unit_name
		_:
			return "[%s] 负载变化 %.0f%% (当前: %.0f%%)" % [evt.unit_name, evt.heat_amount, evt.current_heat]

static func _format_action_plain(evt: CombatEventAction) -> String:
	match evt.action_type:
		"boost":
			return "[%s] 释放提振 (Boost x%d)！" % [evt.unit_name, int(evt.value)]
		"defend":
			return "[%s] 摆出防守姿态，降低所受伤害，且下一轮将优先行动！" % evt.unit_name
		"death":
			return "--- %s 已倒下 ---" % evt.unit_name
		_:
			return "[%s] 执行了 %s" % [evt.unit_name, evt.action_type]


# ============================================================
#  CombatEventFlow Plain Text 格式化
# ============================================================

static func _format_flow_plain(evt: CombatEventFlow) -> String:
	match evt.flow_type:
		"round_started":
			return "\n▶▶▶ 第 %d 回合开始 ◀◀◀\n" % evt.round_number
		"unit_skipped":
			return "● [%s] 处于瘫痪状态 (Break)，跳过本回合行动！\n" % evt.unit_name
		"enemy_analyzing":
			return "● [%s] 正在分析战场状态...\n" % evt.unit_name
		_:
			return "[%s] 战斗流程事件: %s\n" % [evt.unit_name, evt.flow_type]


# ============================================================
#  CombatEventSkillSelect Plain Text 格式化
# ============================================================

static func _format_skill_select_plain(evt: CombatEventSkillSelect) -> String:
	match evt.action_type:
		"open":
			return "[%s] 打开技能选择面板 (BP: %d/%d)" % [evt.unit_name, evt.current_bp, evt.max_bp]
		"select":
			return "[%s] 选中技能: %s" % [evt.unit_name, evt.skill_name]
		"boost":
			return "[%s] 调整增幅至 ×%d" % [evt.unit_name, int(evt.value)]
		"confirm":
			return "[%s] 确认技能: %s ×%d (消耗BP: %d)" % [evt.unit_name, evt.skill_name, int(evt.value), int(evt.value) - 1]
		"cancel":
			return "[%s] 取消技能选择" % evt.unit_name
		_:
			return "[%s] 技能选择: %s (%s)" % [evt.unit_name, evt.action_type, evt.skill_name]


# ============================================================
#  辅助方法
# ============================================================

## 获取受击前 HP（CombatEventDamage 没有直接存这个值，
## 用 effective_damage + 当前情景推断；由于事件发布时
## HP 已扣减，这个值是个近似值）
static func _get_hp_before(evt: CombatEventDamage) -> float:
	# 从 CombatEventDamage 携带的 hp_before_damage 或 effective_damage 推断
	# 详细模式下 DamageCalculator 已计算 effective_damage = min(final, hp_before)
	# 所以如果 effective < final，则 hp_before = effective
	# 否则 hp_before >= final，输出 final 即可
	if evt.effective_damage < evt.final_damage:
		return evt.effective_damage + (evt.final_damage - evt.effective_damage)
	return evt.final_damage
