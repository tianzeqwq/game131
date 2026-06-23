class_name TargetSelector
extends Control

## 目标选择器 — 战场方向导航版
##
## 不再显示列表面板。进入目标选择后：
##   菜单进入半隐退（由上层状态机处理）
##   键盘 ↑↓←→ 四方向键基于战场物理布局切换高亮
##   方向导航算法：以当前目标为轴心，寻找指定方向上最近的目标
##   Enter/Space 确认，Escape/BackSpace 取消
##
## 信号:
##   target_confirmed(target: Combatant)
##   selection_cancelled()

signal target_confirmed(target: Combatant)
signal selection_cancelled()
signal closed()

## 可用目标列表
var _targets: Array[Combatant] = []
var _selected_index: int = 0
var last_selected_target: Combatant = null
var was_cancelled: bool = false

# ── 场景高亮依赖 ──
var _hud: BattleHUD = null
var _assembler: BattleSceneAssembler = null

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(600, 30)

	focus_mode = FOCUS_ALL


func _ready() -> void:
	# 延迟到加入场景树后获取 viewport 尺寸（_init 中调用会报错）
	position = Vector2(
		get_viewport_rect().size.x * 0.5 - 300,
		get_viewport_rect().size.y - 60
	)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_right"):
		_navigate(Vector2.RIGHT)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_left"):
		_navigate(Vector2.LEFT)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_down"):
		_navigate(Vector2.DOWN)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_up"):
		_navigate(Vector2.UP)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


## ── 公开入口 ──

## 设置依赖
## 注意：timeline 参数保留以兼容外部调用，但已不再用于导航
func set_deps(hud: BattleHUD, _timeline: BattleTimeline, assembler: BattleSceneAssembler) -> void:
	_hud = hud
	_assembler = assembler


## 开始选择
func show_for(targets: Array[Combatant], prompt: String = "选择目标") -> void:
	_targets = targets
	_selected_index = 0
	last_selected_target = null
	was_cancelled = false

	# 高亮第一个目标（白色自发光 + 3D 箭头指示器）
	_update_highlight()

	show()
	grab_focus()


## 关闭选择器
func hide_selector() -> void:
	_clear_target_highlight()
	if _assembler:
		_assembler.hide_target_indicator()
	hide()


## ── 方向导航 ──
##
## 以当前选中目标为轴心，在屏幕空间中找到指定方向上最近的目标。
## 算法：
##   1. 过滤出在指定方向上的目标（方向向量与目标-当前向量的点积 > 0）
##   2. 计算垂直偏离距离（目标偏离方向轴的程度）
##   3. 综合评分 = 垂直偏离² × 100 + 前进距离 × 0.01
##   4. 选择评分最低的目标（优先最小化垂直偏离）

func _navigate(direction: Vector2) -> void:
	if _targets.is_empty() or _targets.size() <= 1:
		_play_empty_feedback()
		return

	var from_pos = _get_screen_pos(_targets[_selected_index])
	if from_pos == Vector2.ZERO:
		_play_empty_feedback()
		return

	var best: Combatant = null
	var best_score: float = INF

	for i in range(_targets.size()):
		var t = _targets[i]
		if not t.is_alive():
			continue
		if i == _selected_index:
			continue

		var pos = _get_screen_pos(t)
		if pos == Vector2.ZERO:
			continue

		var v: Vector2 = pos - from_pos
		var dot: float = v.dot(direction)

		# 不在指定方向上（在背后或侧面），跳过
		if dot <= 0.0:
			continue

		# 计算垂直偏离距离（目标离方向轴有多远）
		var perp: Vector2 = v - direction * dot
		var perp_dist_sq: float = perp.length_squared()

		# 综合评分：垂直偏离为主导，前进距离为辅助
		var score: float = perp_dist_sq * 100.0 + dot * 0.01

		if score < best_score:
			best_score = score
			best = t

	if best == null:
		_play_empty_feedback()
		return

	_selected_index = _targets.find(best)
	if _selected_index < 0:
		_selected_index = 0
	_update_highlight()


func _get_screen_pos(combatant: Combatant) -> Vector2:
	if _assembler == null:
		return Vector2.ZERO
	return _assembler.get_unit_screen_pos(combatant)


func _update_highlight() -> void:
	if _selected_index < 0 or _selected_index >= _targets.size():
		return
	
	var current = _targets[_selected_index]
	
	# 取消上一个目标的高亮
	if last_selected_target != null and last_selected_target != current:
		var prev_unit = last_selected_target.visual_unit
		if prev_unit and is_instance_valid(prev_unit):
			prev_unit.unhighlight()
	
	# 高亮当前目标
	if current.visual_unit and is_instance_valid(current.visual_unit):
		current.visual_unit.highlight_white()
	last_selected_target = current
	
	# 更新 3D 箭头指示器
	if _assembler:
		_assembler.show_target_indicator(current)


func _play_empty_feedback() -> void:
	# 无可切换目标时静默处理（无提示文字）
	pass


func _confirm() -> void:
	if _selected_index < 0 or _selected_index >= _targets.size():
		return
	var chosen = _targets[_selected_index]
	if not chosen.is_alive():
		_play_empty_feedback()
		return
	_clear_target_highlight()
	last_selected_target = chosen
	was_cancelled = false
	if _assembler:
		_assembler.hide_target_indicator()
	target_confirmed.emit(chosen)
	closed.emit()
	hide()


func _cancel() -> void:
	_clear_target_highlight()
	last_selected_target = null
	was_cancelled = true
	if _assembler:
		_assembler.hide_target_indicator()
	selection_cancelled.emit()
	closed.emit()
	hide()


## 清除当前 CombatUnit 上的白色高亮（如果有）
func _clear_target_highlight() -> void:
	if last_selected_target != null:
		var unit = last_selected_target.visual_unit
		if unit and is_instance_valid(unit):
			unit.unhighlight()
		last_selected_target = null
