class_name CombatActionPanel
extends Panel

## 战斗操作面板（八方旅人2风格）
##
## 重构（Clean Code）：动效委托给 MenuPanelAnimator，本文件只保留输入/列表/描述逻辑。
## 动效参数个性化：retreat_shift=100, flyout_shift=400, flyout 带缩小

signal action_confirmed(strategy: PlayerAction, _dummy: int)
signal cancelled()
signal closed()
signal boost_changed(level: int)

const _Config = preload("res://src/ui/ui_design_config.gd")

var _selected_index: int = 0
var _actions: Array[PlayerAction] = []
var last_selected_strategy: PlayerAction = null
var was_cancelled: bool = false

# 灰显/禁用状态（选择子面板时父面板保持可见但禁用）
var _is_disabled: bool = false

# 动效引擎（组合而非继承）
var _animator: MenuPanelAnimator

# Boost 状态
var _boost_active: bool = false

# 浮动描述面板（组合组件）
var _desc_panel: DescriptionPanel

@onready var _action_list_container: VBoxContainer = $VBox/ActionList
@onready var _vbox: VBoxContainer = $VBox
@onready var _boost_panel: BoostPanel = $BoostPanel


func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_PASS

	# 通过工厂方法统一设置 StyleBox（取代 tscn 中的 hardcoded SubResource）
	# 使用 COLOR_PANEL_BG + CORNER_RADIUS_MEDIUM + COLOR_BORDER
	add_theme_stylebox_override("panel", _Config.make_panel_style())

	# 初始化动效引擎
	_animator = MenuPanelAnimator.new()
	_animator.setup(self)
	_animator.retreat_shift = 100.0
	_animator.flyout_shift = 400.0
	_animator.flyout_use_scale = true

	# 初始化浮动描述面板（组合组件，从 .tscn 实例化以获取场景节点）
	_desc_panel = load("res://src/ui/description_panel.tscn").instantiate()
	_desc_panel.panel_width = size.x
	add_child(_desc_panel)

	# 透传 BoostPanel 信号
	_boost_panel.boost_changed.connect(func(level: int):
		boost_changed.emit(level)
	)

	# 初始即显示 BoostPanel（默认状态：BP=5, limit=3, level=0）
	_boost_panel.setup(5, 3, 0)
	# 动态居中 BoostPanel（确保无论面板宽度如何变化都居中于 ActionList）
	_center_boost_panel()
	show_boost()


func _center_boost_panel() -> void:
	## 将 BoostPanel 水平居中于面板宽度
	_boost_panel.position.x = (size.x - _boost_panel.size.x) / 2


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return

	# Boost 输入处理（Q 减少增幅，E 增加增幅；子面板模式下也生效）
	if _boost_active:
		if event.is_action_pressed("boost_decrease"):
			_boost_panel.adjust(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("boost_increase"):
			_boost_panel.adjust(1)
			get_viewport().set_input_as_handled()
			return

	# 正常输入：仅当面板有焦点且未禁用时
	if not has_focus() or _is_disabled:
		return

	if event.is_action_pressed("ui_up") and not event.is_echo():
		_select_action(_selected_index - 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down") and not event.is_echo():
		_select_action(_selected_index + 1)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_confirm()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		last_selected_strategy = null
		was_cancelled = true
		cancelled.emit()
		get_viewport().set_input_as_handled()


## 显示面板（带"原位滑出"动效）
func show_for(actions: Array[PlayerAction], origin_screen_pos: Vector2 = Vector2.ZERO) -> void:
	_actions = actions
	_selected_index = 0
	last_selected_strategy = null
	was_cancelled = false
	# 重置禁用状态（保证新角色能正常操作）
	_is_disabled = false
	_vbox.modulate = Color.WHITE
	mouse_filter = MOUSE_FILTER_PASS
	_animator.kill_tween()

	# 先隐藏描述面板（等动效完成后再展示）
	_desc_panel.hide()

	_rebuild_action_list()
	_resize_to_content()
	_highlight_selected()

	# 等待滑入动效完成后再展示描述（确保定位准确）
	await _animator.play_slide_in(origin_screen_pos, _action_list_container)
	_refresh_description()


func hide_panel() -> void:
	_animator.hide_panel()


## 半隐退 / 恢复（由 Assembler 协调调用）
## BoostPanel 跟随面板右移但保持全亮（不 fade）
## 描述面板作为子节点自动跟随 modulate/position 变化
func enter_retreat_mode() -> void:
	_animator.enter_retreat([])
	# 描述面板在父面板半隐退时也淡出
	if _desc_panel and _desc_panel.visible:
		_desc_panel.modulate = Color(1, 1, 1, 0.0)
	# BoostPanel 不受 fade 影响（保持可见）
	_boost_panel.modulate = Color.WHITE

func exit_retreat_mode() -> void:
	_animator.exit_retreat([])
	# 描述面板恢复显示
	if _desc_panel and _desc_panel.visible:
		_desc_panel.modulate = Color.WHITE
	_boost_panel.modulate = Color.WHITE

func play_execute_flyout() -> void:
	await _animator.play_flyout()


func get_selected_strategy() -> PlayerAction:
	if _selected_index >= 0 and _selected_index < _actions.size():
		return _actions[_selected_index]
	return null


# ── Boost 管理 ──

## 设置增幅面板数据
func setup_boost(current_bp: int, boost_limit: int, default_level: int = 0) -> void:
	_boost_panel.setup(current_bp, boost_limit, default_level)
	if current_bp <= 0:
		hide_boost()
	else:
		show_boost()


## 显示增幅面板
func show_boost() -> void:
	_boost_active = true
	_boost_panel.show()


## 隐藏增幅面板
func hide_boost() -> void:
	_boost_active = false
	_boost_panel.hide()


func _hide_boost() -> void:
	_boost_active = false
	if _boost_panel:
		_boost_panel.hide()


## 获取当前增幅等级
func get_boost_level() -> int:
	return _boost_panel.current_level


## 重置增幅
func reset_boost() -> void:
	_boost_panel.reset()


# ── 内部方法 ──

func _select_action(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	_selected_index = index
	_highlight_selected()
	_refresh_description()


func _confirm() -> void:
	if _actions.is_empty():
		return
	var chosen = _actions[_selected_index]
	last_selected_strategy = chosen
	was_cancelled = false

	# 防御是直接操作（无子面板），隐藏面板
	# 攻击/技能有子面板，灰显/禁用而非隐藏
	if chosen.get_action_name() == "防御":
		hide()
	else:
		set_disabled(true)

	action_confirmed.emit(chosen, 0)
	closed.emit()


func _rebuild_action_list() -> void:
	for child in _action_list_container.get_children():
		child.free()

	for i in range(_actions.size()):
		var action = _actions[i]
		var row = PanelContainer.new()
		row.name = "ActionRow_%d" % i
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_filter = MOUSE_FILTER_PASS
		var row_box = HBoxContainer.new()
		row_box.name = "RowBox"
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 6)
		row.add_child(row_box)

		var cursor = Label.new()
		cursor.name = "Cursor"
		cursor.text = "  "
		cursor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cursor.add_theme_font_size_override("font_size", _Config.FONT_SIZE_ACTION_NAME)
		row_box.add_child(cursor)

		var name_label = Label.new()
		name_label.name = "ActionName"
		name_label.text = action.get_action_name()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", _Config.FONT_SIZE_ACTION_NAME)
		row_box.add_child(name_label)

		_action_list_container.add_child(row)


## 根据行动数量自适应面板高度
func _resize_to_content() -> void:
	var total = _actions.size() * _Config.ACTION_ROW_HEIGHT + _Config.ACTION_LIST_PADDING
	size.y = maxf(total, 60.0)


func _highlight_selected() -> void:
	var count = min(_action_list_container.get_child_count(), _actions.size())
	for i in count:
		var row = _action_list_container.get_child(i)
		var row_box = row.get_node("RowBox") as HBoxContainer
		var cursor = row_box.get_node("Cursor") as Label
		var name_label = row_box.get_node("ActionName") as Label

		var is_selected = (i == _selected_index)

		if is_selected:
			cursor.text = "▸ "
			cursor.add_theme_color_override("font_color", _Config.COLOR_HIGHLIGHT)
			name_label.add_theme_color_override("font_color", _Config.COLOR_HIGHLIGHT)
		else:
			cursor.text = "  "
			cursor.add_theme_color_override("font_color", _Config.COLOR_TEXT_PRIMARY)
			name_label.add_theme_color_override("font_color", _Config.COLOR_TEXT_PRIMARY)

		if is_selected:
			var bg = StyleBoxFlat.new()
			bg.bg_color = Color(_Config.COLOR_PRIMARY.r, _Config.COLOR_PRIMARY.g, _Config.COLOR_PRIMARY.b, 0.3)
			bg.set_corner_radius_all(_Config.CORNER_RADIUS_SMALL)
			row.add_theme_stylebox_override("panel", bg)
			row.add_theme_stylebox_override("focus", bg)
		else:
			row.remove_theme_stylebox_override("panel")


func _refresh_description() -> void:
	if _selected_index < 0 or _selected_index >= _actions.size():
		_desc_panel.hide_with_fade()
		return

	var action = _actions[_selected_index]
	var desc = action.get_action_description()
	var row_rect = get_selected_row_global_rect()

	_desc_panel.show_for(desc, row_rect)


## 设置禁用状态（仅 VBox 内容透明度降低，BoostPanel 保持全亮）
func set_disabled(disabled: bool) -> void:
	_is_disabled = disabled
	if disabled:
		# 仅 VBox（操作列表+描述）透明度降低，BoostPanel 不受影响
		_vbox.modulate = Color(1, 1, 1, 0.3)
		# 禁用鼠标/触摸输入
		mouse_filter = MOUSE_FILTER_IGNORE
		# 释放键盘焦点，交由子面板处理
		release_focus()
	else:
		# 恢复正常
		_vbox.modulate = Color.WHITE
		mouse_filter = MOUSE_FILTER_PASS


## 获取当前选中行动行的全局 Rect2（用于子面板精确定位）
func get_selected_row_global_rect() -> Rect2:
	if _selected_index < 0 or _selected_index >= _action_list_container.get_child_count():
		return Rect2(global_position, size)
	var row = _action_list_container.get_child(_selected_index)
	return Rect2(row.global_position, row.size)


## 恢复父面板到活跃状态（子面板取消时由 Assembler 调用）
func restore() -> void:
	set_disabled(false)
	grab_focus()


func reset() -> void:
	_selected_index = 0
	_actions = []
	last_selected_strategy = null
	was_cancelled = false
	_is_disabled = false
	# 隐藏描述面板
	if _desc_panel:
		_desc_panel.hide()
	# 重置增幅等级但保持可见
	_boost_panel.reset()
	_boost_active = true
