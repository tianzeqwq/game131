class_name DescriptionPanel
extends Panel

## 浮动描述面板（组合组件）
##
## 作为 CombatActionPanel / SkillSelectPanel 的子节点，
## 在选中行下方展示半透明描述文字。自动淡入淡出，跟随父面板动效。

const _Config = preload("res://src/ui/ui_design_config.gd")

## 面板宽度（与父面板一致）
var panel_width: float = 280.0

## 水平偏移量（向右错开，形成缩进效果）
var x_offset: float = 16.0

## 锚定位置下方间距（px）
var _anchor_gap: float = 4.0

## 内部标签
@onready var _label: Label = $MarginContainer/Label


func _ready() -> void:
	hide()
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 0.0)

	# 通过工厂方法统一设置 StyleBox（取代 tscn 中的 hardcoded SubResource）
	# 使用 COLOR_DESC_BG + CORNER_RADIUS_SMALL + COLOR_BORDER
	add_theme_stylebox_override("panel", _Config.make_panel_style(
		_Config.COLOR_DESC_BG,
		_Config.CORNER_RADIUS_SMALL,
		true,
		_Config.COLOR_BORDER
	))

	# 从设计配置加载字体样式（字号 11px → 14px，颜色调亮）
	_label.add_theme_font_size_override("font_size", _Config.FONT_SIZE_DESCRIPTION)
	_label.add_theme_color_override("font_color", _Config.COLOR_DESCRIPTION)

	# 预热标签字体布局（避免首次打开时字体未加载导致高度计算不准）
	_label.text = " "
	_label.update_minimum_size()


## 显示描述面板，锚定在 anchor_rect 下方
## desc_text: 描述文本（自动换行）
## anchor_rect: 选中行的全局 Rect2
func show_for(desc_text: String, anchor_rect: Rect2) -> void:
	if desc_text.is_empty():
		hide_with_fade()
		return

	_label.text = desc_text

	# 设置面板宽度
	size.x = panel_width
	var effective_width = panel_width - 16.0  # 扣除 MarginContainer 左右 margin 8+8

	# 用字体度量直接计算换行后的文本高度（不依赖 Godot 标签布局缓存）
	var label_height = _calculate_wrapped_height(desc_text, effective_width)
	size.y = label_height + 24  # 上下 margin（MarginContainer 的 padding）

	# 定位：anchor_rect 下方，向右偏移形成缩进
	global_position = Vector2(
		anchor_rect.position.x + x_offset,
		anchor_rect.position.y + anchor_rect.size.y + _anchor_gap
	)

	# 淡入（modulate 在 _ready 中已设为透明，不会闪）
	show()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate", Color.WHITE, 0.1)


## 重新定位到新的锚定行（选中行切换时调用，不重复淡入）
func reposition(anchor_rect: Rect2) -> void:
	if not visible:
		return

	global_position = Vector2(
		anchor_rect.position.x + x_offset,
		anchor_rect.position.y + anchor_rect.size.y + _anchor_gap
	)


## 淡化隐藏
func hide_with_fade() -> void:
	if not visible:
		return
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0.0), 0.08)
	await tw.finished
	hide()


## 使用字体度量直接计算文本在指定宽度下换行后的高度
func _calculate_wrapped_height(text: String, width: float) -> float:
	if text.is_empty():
		return 20.0

	var font = _label.get_theme_font("font")
	var font_size = _label.get_theme_font_size("font_size")

	if font == null:
		return 20.0

	var space_width = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var line_height = font.get_height(font_size)
	var effective_width = maxf(width, 1.0)

	# 将文本按字词拆分，模拟自动换行计算行数
	var lines = 1
	var current_line_width = 0.0
	var words = text.split(" ", false)

	for word in words:
		var word_width = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		if current_line_width > 0 and current_line_width + word_width > effective_width:
			# 当前行放不下这个词，换行
			lines += 1
			current_line_width = word_width
		else:
			# 可以放在当前行
			if current_line_width > 0:
				current_line_width += space_width
			current_line_width += word_width

	return lines * line_height
