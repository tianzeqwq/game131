class_name BattleHUD
extends Node

## 战斗 HUD — 管理所有 UI 元素（血条、BP、行动轴）
##
## 从 Main.gd 提取，遵循单一职责原则。

const _Config = preload("res://src/ui/ui_design_config.gd")

var timeline_bar: TimelineBar

var player_hp_bar_template: ProgressBar
var enemy_hp_bar_template: ProgressBar
var player_label_template: Label
var enemy_label_template: Label

var ui_elements: Dictionary = {}

# 记录每个 Combatant 的 UI 元素原始屏幕位置（用于偏移动画后还原）
var _ui_original_positions: Dictionary = {}

var _battle_controller: BattleController
var _ui_root: Control


## 传入 UI 引用和 BattleController
func setup(
	p_timeline_bar: TimelineBar,
	p_battle_controller: BattleController,
	p_player_bar: ProgressBar = null,
	p_enemy_bar: ProgressBar = null,
	p_player_label: Label = null,
	p_enemy_label: Label = null,
	p_ui_root: Control = null
) -> void:
	timeline_bar = p_timeline_bar
	player_hp_bar_template = p_player_bar
	enemy_hp_bar_template = p_enemy_bar
	player_label_template = p_player_label
	enemy_label_template = p_enemy_label
	_battle_controller = p_battle_controller
	_ui_root = p_ui_root


## 为单个 Combatant 创建 UI 元素（血条 + BP + 标签）
func setup_for_combatant(c: Combatant, index: int, is_player_side: bool) -> void:
	var side_offset = 1670.0 if is_player_side else 50.0
	var y_offset = 80.0 + index * 130.0

	var parent = _ui_root if _ui_root else get_parent()
	if not parent:
		return

	var orig_bar = player_hp_bar_template if is_player_side else enemy_hp_bar_template
	if not orig_bar:
		return
	var bar = orig_bar.duplicate()
	bar.position = Vector2(side_offset, y_offset + 50.0)
	parent.add_child(bar)
	bar.visible = true

	# 隐藏盾条（不再使用）
	var shield_bar = bar.get_node("ShieldBar")
	if shield_bar:
		shield_bar.visible = false

	# 添加 BP 圆点 Label
	var bp_label = Label.new()
	bp_label.name = "BPLabel"
	bp_label.position = Vector2(0, -20)
	bp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bp_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bp_label.size = Vector2(bar.size.x, 18)
	bar.add_child(bp_label)

	var orig_label = player_label_template if is_player_side else enemy_label_template
	if not orig_label:
		return
	var label = orig_label.duplicate()
	label.position = Vector2(side_offset, y_offset)
	parent.add_child(label)
	label.visible = true

	ui_elements[c] = {
		"bar": bar,
		"bp_label": bp_label,
		"label": label
	}
	# 记录原始位置（用于偏移动画后还原）
	_ui_original_positions[c] = {
		"bar": bar.position,
		"label": label.position
	}


## 刷新所有 UI（HP 条、BP 圆点、标签状态、颜色）
func update_all() -> void:
	var current_actor = _battle_controller.current_actor if _battle_controller else null

	for c in ui_elements.keys():
		var elements = ui_elements[c]
		var bar = elements["bar"]
		var bp_label = elements["bp_label"]
		var label = elements["label"]

		bar.value = c.hp
		bar.max_value = c.stats.max_hp
		bp_label.text = _get_bp_dots(c.bp, c.stats.max_bp)

		var name_text = c.stats.unit_name
		if c == current_actor:
			name_text = "▶ " + name_text

		var status_str = ""
		if not c.is_alive():
			status_str = " [倒下]"
		elif c.is_broken:
			status_str = " [瘫痪]"
		elif c.is_defending:
			status_str = " [防御]"

		label.text = name_text + status_str

		if not c.is_alive():
			label.modulate = _Config.COLOR_DEAD
		elif c.is_broken:
			label.modulate = _Config.COLOR_WARNING
		elif c == current_actor:
			label.modulate = _Config.COLOR_HIGHLIGHT
		else:
			label.modulate = Color.WHITE


## 生成八方旅人风格的 BP 圆点文本
static func _get_bp_dots(current_bp: int, max_bp: int) -> String:
	var filled = "●".repeat(current_bp)
	var empty = "○".repeat(max_bp - current_bp)
	return filled + empty


## 显示增幅后的 BP 预览（面板调增幅时实时更新）
func show_boost_preview(actor: Combatant, boost_level: int) -> void:
	var elements = ui_elements.get(actor)
	if elements:
		var remaining = maxi(0, actor.bp - boost_level)
		var bp_label = elements["bp_label"] as Label
		if bp_label:
			bp_label.text = _get_bp_dots(remaining, actor.stats.max_bp)


## 刷新行动轴 UI
func update_timeline() -> void:
	var tl = _battle_controller.timeline if _battle_controller else null
	if tl:
		timeline_bar.refresh(tl.get_active_queue(), tl.get_next_round_queue())


## ── 目标选择高亮 ──

## 当前单目标选择高亮（场景内目标选择时用）
var _highlighted_target: Combatant = null

## 高亮所有敌方单位（进入目标选择阶段时）
func highlight_enemies(enemy_party: Array[Combatant]) -> void:
	for c in enemy_party:
		var elements = ui_elements.get(c)
		if elements == null:
			continue
		var label = elements["label"] as Label
		var bar = elements["bar"] as ProgressBar
		if label:
			label.add_theme_color_override("font_color", _Config.COLOR_HIGHLIGHT)
			label.add_theme_constant_override("outline_size", _Config.EFFECT_GLOW_OUTLINE_SIZE)
			# 放大效果
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "scale", Vector2(1.05, 1.05), 0.2)
		if bar:
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(bar, "scale", Vector2(1.05, 1.05), 0.2)


## 取消高亮（从目标选择返回时）
func unhighlight_enemies(enemy_party: Array[Combatant]) -> void:
	for c in enemy_party:
		var elements = ui_elements.get(c)
		if elements == null:
			continue
		_reset_unit_visual(c, elements)
	_highlighted_target = null


## 高亮单个目标（场景内选择时，仅高亮当前选中的敌人）
func highlight_target(combatant: Combatant) -> void:
	# 取消上一个目标的高亮
	if _highlighted_target and _highlighted_target != combatant:
		var old_elements = ui_elements.get(_highlighted_target)
		if old_elements:
			_reset_unit_visual(_highlighted_target, old_elements)

	# 高亮新目标
	var elements = ui_elements.get(combatant)
	if elements:
		var label = elements["label"] as Label
		var bar = elements["bar"] as ProgressBar
		if label:
			label.add_theme_color_override("font_color", _Config.COLOR_PRIMARY)
			label.add_theme_constant_override("outline_size", _Config.EFFECT_GLOW_HIGHLIGHT_SIZE)
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.15)
		if bar:
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(bar, "scale", Vector2(1.1, 1.1), 0.15)

	_highlighted_target = combatant


## 取消单目标高亮
func unhighlight_target() -> void:
	if _highlighted_target:
		var elements = ui_elements.get(_highlighted_target)
		if elements:
			_reset_unit_visual(_highlighted_target, elements)
		_highlighted_target = null


## 重置单个单位的视觉效果到默认状态
func _reset_unit_visual(combatant: Combatant, elements: Dictionary) -> void:
	var label = elements["label"] as Label
	var bar = elements["bar"] as ProgressBar
	if label:
		label.remove_theme_color_override("font_color")
		label.remove_theme_constant_override("outline_size")
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.15)
	if bar:
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(bar, "scale", Vector2.ONE, 0.15)


## ── UI 偏移动画（跟随角色 3D 移动同步） ──

## 将指定 Combatant 的 HUD 元素（bar + label）动画移动到「原始位置 + 偏移量」
## BP Label 是 bar 的子节点，会随 bar 自动移动
func animate_ui_shift(combatant: Combatant, offset: Vector2, duration: float) -> void:
	var elements = ui_elements.get(combatant)
	var originals = _ui_original_positions.get(combatant)
	if elements == null or originals == null:
		return

	var bar: ProgressBar = elements["bar"]
	var label: Label = elements["label"]

	var bar_target = originals["bar"] + offset
	var label_target = originals["label"] + offset

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "position", bar_target, duration)
	tween.tween_property(label, "position", label_target, duration)


## 将指定 Combatant 的 HUD 元素动画还原到原始位置
func restore_ui_positions(combatant: Combatant, duration: float) -> void:
	var elements = ui_elements.get(combatant)
	var originals = _ui_original_positions.get(combatant)
	if elements == null or originals == null:
		return

	var bar: ProgressBar = elements["bar"]
	var label: Label = elements["label"]

	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "position", originals["bar"], duration)
	tween.tween_property(label, "position", originals["label"], duration)
