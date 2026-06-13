class_name SkillSelectPanel
extends Panel

## 技能选择面板
##
## 纯 View 职责：展示技能列表 + 增幅等级，键盘交互，通过信号汇报结果。
## 不引用 Combatant 或任何领域对象，只接收纯数据。
##
## 键盘操作:
##   ↑/↓  — 切换技能选择
##   ←/→  — 切换增幅等级 (×0~×3，受 BP 限制)
##   Enter — 确认选择
##   Esc   — 取消

signal closed()  # 面板关闭后发射，处理器读取 last_* 字段获取结果
signal boost_changed(boost_level: int)  # 增幅等级变化时发射，供 HUD 实时更新 BP 预览

var _skills: Array[SkillConfig] = []
var _selected_index: int = 0
var _boost_level: int = 0
var _max_boost: int = 0
var _max_bp: int = 5
var _current_bp: int = 0
var _unit_name: String = ""  # 执行者名称，用于 logging

# 面板关闭后，处理器通过这些字段读取选择结果
var last_selected_skill: SkillConfig = null
var last_boost_level: int = 0
var was_cancelled: bool = false

# 节点缓存
@onready var boost_label: Label = $VBox/TopInfo/BoostLabel
@onready var skill_list: VBoxContainer = $VBox/SkillList


func _ready() -> void:
	focus_mode = FOCUS_ALL
	grab_focus()


func _input(event: InputEvent) -> void:
	if not visible or not has_focus():
		return

	if event.is_action_pressed("ui_up"):
		_select_skill(_selected_index - 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down"):
		_select_skill(_selected_index + 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_left"):
		_adjust_boost(-1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_right"):
		_adjust_boost(1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		was_cancelled = true
		last_selected_skill = null
		last_boost_level = 0
		_publish_event("cancel")
		closed.emit()
		hide()
		get_viewport().set_input_as_handled()


## 公开入口：传入技能数据和 BP 信息，面板自动渲染
## p_unit_name: 执行者名称，用于 logging
func show_for(
	p_skills: Array[SkillConfig],
	p_current_bp: int,
	p_max_bp: int,
	p_unit_name: String = ""
) -> void:
	_skills = p_skills
	_current_bp = p_current_bp
	_max_bp = p_max_bp
	_unit_name = p_unit_name
	# 面板显示 ×1~×N，N = 当前BP + 1（×1=消耗0，×2=消耗1...）
	_max_boost = _current_bp + 1
	_selected_index = 0
	_boost_level = 1
	was_cancelled = false
	last_selected_skill = null
	last_boost_level = 0

	_rebuild_skill_list()
	_refresh_header()
	show()
	_highlight_selected()
	_publish_event("open", "", 0)


func _rebuild_skill_list() -> void:
	for child in skill_list.get_children():
		child.queue_free()

	for i in range(_skills.size()):
		var skill = _skills[i]

		var row = HBoxContainer.new()
		row.name = "SkillRow_%d" % i

		var cursor = Label.new()
		cursor.name = "Cursor"
		cursor.text = "  "
		cursor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(cursor)

		var name_label = Label.new()
		name_label.text = skill.skill_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)

		skill_list.add_child(row)


func _refresh_header() -> void:
	boost_label.text = "增幅: ×%d" % _boost_level


func _highlight_selected() -> void:
	for i in skill_list.get_child_count():
		var row = skill_list.get_child(i)
		var cursor = row.get_node("Cursor") as Label
		var name_label = row.get_child(1) as Label

		if i == _selected_index:
			cursor.text = "▶ "
			name_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
		else:
			cursor.text = "  "
			name_label.add_theme_color_override("font_color", Color.WHITE)


func _select_skill(index: int) -> void:
	if index < 0 or index >= _skills.size():
		return
	_selected_index = index
	_highlight_selected()
	var skill_name = _skills[_selected_index].skill_name if _skills.size() > 0 else ""
	_publish_event("select", skill_name)


func _adjust_boost(delta: int) -> void:
	var new_boost = clampi(_boost_level + delta, 1, _max_boost)
	if new_boost == _boost_level:
		return
	_boost_level = new_boost
	_refresh_header()
	boost_changed.emit(_boost_level)
	_publish_event("boost", "", _boost_level)


func _confirm() -> void:
	if _selected_index < 0 or _selected_index >= _skills.size():
		return
	was_cancelled = false
	last_selected_skill = _skills[_selected_index]
	last_boost_level = _boost_level
	var skill_name = _skills[_selected_index].skill_name if _skills.size() > 0 else ""
	_publish_event("confirm", skill_name, _boost_level)
	closed.emit()
	hide()


## 发布技能选择事件到 CombatEventBus 进行日志记录
func _publish_event(action_type: String, skill_name: String = "", value: float = 0.0) -> void:
	if _unit_name.is_empty():
		return
	var event = CombatEventSkillSelect.new(
		_unit_name, action_type, skill_name, value, _current_bp, _max_bp
	)
	CombatEventBus.publish(event)
