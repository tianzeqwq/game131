class_name SkillSelectPanel
extends Panel

## 技能选择面板（纯技能名称列表）
##
## 重构（Clean Code）：动效委托给 MenuPanelAnimator
## 仅显示技能名称的简洁列表，选中项通过颜色高亮区分。

signal closed()

const _Config = preload("res://src/ui/ui_design_config.gd")

## 子面板相对父面板选中行的水平缩进（px）
const SUB_PANEL_X_OFFSET: float = _Config.SUB_PANEL_X_OFFSET

var _skills: Array[SkillConfig] = []
var _selected_index: int = 0
var _max_bp: int = 5
var _current_bp: int = 0
var _unit_name: String = ""

var last_selected_skill: SkillConfig = null
var was_cancelled: bool = false

# ── 取消恢复快照 ──
## 上层状态机在 cancel→restore 时调用 get/restore 方法
var _restore_snapshot: Dictionary = {}

# 动效引擎
var _animator: MenuPanelAnimator

# 浮动描述面板（组合组件）
var _desc_panel: DescriptionPanel

@onready var skill_list: VBoxContainer = $VBox/SkillList


func _ready() -> void:
	# 通过工厂方法统一设置 StyleBox（取代 tscn 中的 hardcoded SubResource）
	# 使用 COLOR_PANEL_BG + CORNER_RADIUS_MEDIUM + COLOR_BORDER
	add_theme_stylebox_override("panel", _Config.make_panel_style())

	# 初始化动效引擎
	_animator = MenuPanelAnimator.new()
	_animator.setup(self)

	# 初始化浮动描述面板（组合组件，从 .tscn 实例化以获取场景节点）
	_desc_panel = load("res://src/ui/description_panel.tscn").instantiate()
	# 描述面板宽度动态匹配父面板（CombatActionPanel）宽度
	_desc_panel.panel_width = size.x
	add_child(_desc_panel)

	focus_mode = FOCUS_ALL


func _input(event: InputEvent) -> void:
	if not visible or not has_focus():
		return

	if event.is_action_pressed("ui_up"):
		_select_skill(_selected_index - 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down"):
		_select_skill(_selected_index + 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


## 显示技能面板（带"侧翼推窗"动效）
func show_for(
	p_skills: Array[SkillConfig],
	p_current_bp: int,
	p_max_bp: int,
	p_unit_name: String = "",
	p_default_boost_level: int = 0,
	parent_menu_rect: Rect2 = Rect2()
) -> void:
	_skills = p_skills
	_current_bp = p_current_bp
	_max_bp = p_max_bp
	_unit_name = p_unit_name
	_selected_index = 0
	was_cancelled = false
	last_selected_skill = null

	# 隐藏描述面板（等动效完成后再展示）
	_desc_panel.hide()

	_rebuild_skill_list()
	_highlight_selected()

	# 根据技能数量自适应面板高度
	_resize_to_content()

	# 使用"原位替换"动效：在 CombatActionPanel 选中行右侧偏移位置淡入（形成缩进层次感）
	var offset_rect = parent_menu_rect
	if offset_rect != Rect2():
		offset_rect.position.x += SUB_PANEL_X_OFFSET
	await _animator.play_replace_open(offset_rect, skill_list)

	# 动效完成后展示第一条技能的描述
	_refresh_description()

	_publish_event("open", "", p_default_boost_level)


func hide_panel() -> void:
	_animator.hide_panel()
	if _desc_panel:
		_desc_panel.hide()


func enter_retreat_mode() -> void:
	_animator.enter_retreat([])

func exit_retreat_mode() -> void:
	_animator.exit_retreat([])

func play_execute_flyout() -> void:
	await _animator.play_flyout()


## ── 快照系统：用于 CANCEL_BACK 状态恢复 ──

## 保存当前技能列表状态的快照（供上层状态机使用）
func take_snapshot() -> void:
	_restore_snapshot = {
		"skill_index": _selected_index,
		"bp": _current_bp
	}

## 获取已保存的快照
func get_restore_snapshot() -> Dictionary:
	return _restore_snapshot

## 从快照恢复技能列表状态
func restore_from_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_selected_index = snapshot.get("skill_index", 0)
	var bp = snapshot.get("bp", _current_bp)

	# 重新构建 BP 上下文
	_current_bp = bp

	_highlight_selected()


# ── 内部 ──

func _rebuild_skill_list() -> void:
	for child in skill_list.get_children():
		child.queue_free()

	for i in range(_skills.size()):
		var skill = _skills[i]

		var name_label = Label.new()
		name_label.text = skill.skill_name
		name_label.name = "SkillName_%d" % i
		name_label.add_theme_font_size_override("font_size", _Config.FONT_SIZE_SKILL_NAME)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_list.add_child(name_label)


## 根据技能数量自适应面板高度
func _resize_to_content() -> void:
	var total = _skills.size() * _Config.SKILL_ROW_HEIGHT + _Config.SKILL_LIST_PADDING
	size.y = maxf(total, 40.0)


func _highlight_selected() -> void:
	for i in skill_list.get_child_count():
		var label = skill_list.get_child(i) as Label
		if i == _selected_index:
			label.add_theme_color_override("font_color", _Config.COLOR_HIGHLIGHT)
		else:
			label.add_theme_color_override("font_color", Color.WHITE)


func _select_skill(index: int) -> void:
	if index < 0 or index >= _skills.size():
		return
	_selected_index = index
	_highlight_selected()
	_refresh_description()
	var skill_name = _skills[_selected_index].skill_name if _skills.size() > 0 else ""
	_publish_event("select", skill_name)


## 刷新技能描述面板
func _refresh_description() -> void:
	if _selected_index < 0 or _selected_index >= _skills.size():
		_desc_panel.hide_with_fade()
		return

	var skill = _skills[_selected_index]
	var label = skill_list.get_child(_selected_index) as Control
	if label == null:
		return

	var label_rect = Rect2(label.global_position, label.size)
	_desc_panel.show_for(skill.description, label_rect)


func _confirm() -> void:
	if _selected_index < 0 or _selected_index >= _skills.size():
		return
	was_cancelled = false
	last_selected_skill = _skills[_selected_index]
	take_snapshot()
	# 隐藏描述面板
	if _desc_panel:
		_desc_panel.hide_with_fade()
	var skill_name = _skills[_selected_index].skill_name if _skills.size() > 0 else ""
	_publish_event("confirm", skill_name)
	closed.emit()
	hide()


func _cancel() -> void:
	was_cancelled = true
	last_selected_skill = null
	take_snapshot()
	# 隐藏描述面板
	if _desc_panel:
		_desc_panel.hide_with_fade()
	_publish_event("cancel")
	_animator.play_slide_back()
	closed.emit()


func _publish_event(action_type: String, skill_name: String = "", value: float = 0.0) -> void:
	if _unit_name.is_empty():
		return
	var event = CombatEventSkillSelect.new(
		_unit_name, action_type, skill_name, value, _current_bp, _max_bp
	)
	CombatEventBus.publish(event)
