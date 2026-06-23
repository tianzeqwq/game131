class_name MenuPanelAnimator
extends RefCounted

## 菜单面板动效引擎
##
## 八方旅人2风格5种动效的统一实现。
## 消除3个面板文件间的重复代码，动效参数集中配置。
##
## 使用方式（在面板的脚本中）：
##   var _animator: MenuPanelAnimator
##   func _ready():
##       _animator = MenuPanelAnimator.new()
##       _animator.setup(self)
##       _animator.retreat_shift = 80.0  # 按需调参
##
## 支持的动效：
##   1. play_slide_in()    — "原位滑出"：从角色位置横向拉伸展开
##   2. play_push_open()   — "侧翼推窗"：从父面板右侧边缘推出
##   3. enter_retreat()    — "半隐退"：右移+透明化
##   4. exit_retreat()     — 从半隐退恢复
##   5. play_flyout()      — "一扫而空"：飞离屏幕
##   6. play_slide_back()  — "抽屉缩回"：宽度缩回0+淡出（推窗的逆向）

# ═══════════════════════════════════════════
#  配置参数（每个面板可独立覆盖）
# ═══════════════════════════════════════════

## 从角色原点水平偏移量（px）
var slide_offset: float = 60.0
## 半隐退时向右位移量（px）
var retreat_shift: float = 80.0
## 半隐退时透明度目标值
var retreat_opacity: float = 0.35
## 飞离时向右位移量（px）
var flyout_shift: float = 300.0
## 展开动画时长（s）
var expand_duration: float = 0.15
## 子项错位淡入的起始延迟（s）
var stagger_start_delay: float = 0.04
## 子项错位淡入的每项递增延迟（s）
var stagger_step_delay: float = 0.025
## 飞离动画时长（s）
var flyout_duration: float = 0.2
## 飞离时是否附带缩小效果
var flyout_use_scale: bool = false
## 飞离缩小比例（仅 flyout_use_scale=true 时生效）
var flyout_scale: Vector2 = Vector2(0.8, 0.8)


# ═══════════════════════════════════════════
#  内部状态
# ═══════════════════════════════════════════

var _panel: Control = null
var _tween: Tween = null
var _is_retreated: bool = false


# ═══════════════════════════════════════════
#  公开接口
# ═══════════════════════════════════════════

## 绑定目标面板（必须在调用任何动效前调用）
func setup(panel: Control) -> void:
	_panel = panel


## 当前是否处于半隐退状态
func is_retreated() -> bool:
	return _is_retreated


## 杀掉当前正在运行的动画
func kill_tween() -> void:
	if _tween and _tween.is_running():
		_tween.kill()


# ── 动效1："原位滑出" ──

## 从角色屏幕位置横向拉伸展开
## origin: 角色在屏幕空间的像素位置
## children_container: 需要错位淡入的子项容器（如 ActionList 的 VBoxContainer）
func play_slide_in(origin: Vector2, children_container: Control = null) -> void:
	if _panel == null:
		return

	if origin == Vector2.ZERO:
		_panel.show()
		_panel.grab_focus()
		return

	# 计算锚定位置：角色右侧偏上
	var target_pos = Vector2(
		origin.x + slide_offset,
		origin.y - _panel.size.y * 0.3
	)
	_clamp_to_viewport(target_pos)

	# 初始状态：在角色X位置、宽度为0
	var start_pos = Vector2(origin.x, target_pos.y)
	var start_width = 0.0
	# 使用面板自然宽度（来自 tscn 或代码设置），保持与 BoostPanel 等子节点的相对位置一致
	var target_width = _panel.size.x

	_panel.position = start_pos
	_panel.size = Vector2(start_width, _panel.size.y)
	_panel.modulate = Color(1, 1, 1, 0.0)
	_panel.show()

	_build_tween(true)
	_tween.tween_property(_panel, "size:x", target_width, expand_duration)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.12)

	# 子项错位淡入
	if children_container:
		_animate_children_stagger(children_container)

	await _tween.finished

	# 修正到最终位置（Godot tween 不修改实际 property）
	_panel.position = target_pos
	_panel.size.x = target_width
	_panel.grab_focus()


# ── 动效2："侧翼推窗" ──

## 从父面板右侧边缘向右推出
## parent_rect: 父面板（CombatActionPanel）的 Rect2
## children_container: 需要错位淡入的子项容器
## extra_nodes: 额外需要淡入的节点（如 BoostPanel）
func play_push_open(parent_rect: Rect2, children_container: Control = null, extra_nodes: Array[Node] = []) -> void:
	if _panel == null:
		return

	if parent_rect == Rect2():
		_panel.show()
		_panel.grab_focus()
		return

	# 目标位置：父面板右侧对齐顶部
	var target_pos = Vector2(
		parent_rect.position.x + parent_rect.size.x + 4,
		parent_rect.position.y
	)
	_clamp_to_viewport(target_pos)

	var start_pos = Vector2(parent_rect.position.x + parent_rect.size.x, target_pos.y)
	# 使用面板自然宽度，避免动效后子节点（如描述面板）定位偏移
	var target_width = _panel.size.x

	# 初始状态：宽度为0
	_panel.position = start_pos
	_panel.size = Vector2(0, _panel.size.y)
	_panel.modulate = Color(1, 1, 1, 0.0)
	_panel.show()

	_build_tween(true)
	_tween.tween_property(_panel, "size:x", target_width, expand_duration)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.12)

	if children_container:
		_animate_children_stagger(children_container)

	# 额外节点淡入（BoostPanel 等）
	for node in extra_nodes:
		node.modulate = Color(1, 1, 1, 0.0)
		_tween.tween_property(node, "modulate", Color.WHITE, 0.1).set_delay(stagger_start_delay + stagger_step_delay * 4)

	await _tween.finished

	_panel.position = target_pos
	_panel.size.x = target_width
	_panel.grab_focus()


# ── 动效2b："原位飞入" ──

## 在主面板的同一位置以「宽度展开 + 淡入」飞入（替代侧翼推窗）
## target_rect: 主面板（CombatActionPanel）的 Rect2
## children_container: 需要错位淡入的子项容器
## extra_nodes: 额外需要淡入的节点（如 BoostPanel）
func play_replace_open(target_rect: Rect2, children_container: Control = null, extra_nodes: Array[Node] = []) -> void:
	if _panel == null:
		return

	if target_rect == Rect2():
		_panel.show()
		_panel.grab_focus()
		return

	# 目标位置：与主面板左上角对齐
	var target_pos = Vector2(target_rect.position.x, target_rect.position.y)
	_clamp_to_viewport(target_pos)

	# 保存目标宽度（子面板自然宽度）
	var target_width = _panel.size.x

	# 初始状态：在目标位置、宽度为0、透明度0
	_panel.position = target_pos
	_panel.size = Vector2(0, _panel.size.y)
	_panel.modulate = Color(1, 1, 1, 0.0)
	_panel.show()

	_build_tween(true)
	# 宽度向右展开 + 淡入（飞入效果）
	_tween.tween_property(_panel, "size:x", target_width, expand_duration)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.12)

	if children_container:
		_animate_children_stagger(children_container)

	# 额外节点淡入（BoostPanel 等）
	for node in extra_nodes:
		node.modulate = Color(1, 1, 1, 0.0)
		_tween.tween_property(node, "modulate", Color.WHITE, 0.1).set_delay(stagger_start_delay + stagger_step_delay * 2)

	await _tween.finished

	_panel.size.x = target_width
	_panel.grab_focus()


# ── 动效3："半隐退" ──

## 进入半隐退状态：右移 + 透明化
## extra_nodes: 额外需要隐藏的节点（如描述框、增幅标签）
func enter_retreat(extra_nodes: Array[Node] = []) -> void:
	if _is_retreated or _panel == null:
		return
	_is_retreated = true

	_build_tween(false)
	_tween.tween_property(_panel, "position:x", _panel.position.x + retreat_shift, 0.2)
	_tween.tween_property(_panel, "modulate", Color(1, 1, 1, retreat_opacity), 0.2)

	for node in extra_nodes:
		_tween.tween_property(node, "modulate", Color(1, 1, 1, 0.0), 0.15)


## 退出半隐退状态
## extra_nodes: 同上，需要恢复的节点
func exit_retreat(extra_nodes: Array[Node] = []) -> void:
	if not _is_retreated or _panel == null:
		return
	_is_retreated = false

	_build_tween(false)
	_tween.tween_property(_panel, "position:x", _panel.position.x - retreat_shift, 0.2)
	_tween.tween_property(_panel, "modulate", Color.WHITE, 0.2)

	for node in extra_nodes:
		node.modulate = Color.WHITE


# ── 动效4："一扫而空" ──

## 飞离屏幕
func play_flyout() -> void:
	if _panel == null:
		return

	_build_tween(true)
	_tween.tween_property(_panel, "position:x", _panel.position.x + flyout_shift, flyout_duration)
	_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0.0), flyout_duration - 0.05)

	if flyout_use_scale:
		_tween.tween_property(_panel, "scale", flyout_scale, flyout_duration - 0.05)

	await _tween.finished
	_panel.hide()


# ── 动效5："抽屉缩回" ──

## 宽度缩回0并淡出（推窗的逆向动效）
func play_slide_back() -> void:
	if _panel == null:
		return

	_build_tween(true)
	_tween.tween_property(_panel, "size:x", 0, 0.12)
	_tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0.0), 0.1)

	await _tween.finished
	_panel.hide()


# ── 重置 ──

## 重置到初始状态
func reset() -> void:
	kill_tween()
	_panel = null
	_is_retreated = false


## 隐藏面板并重置视觉状态
func hide_panel() -> void:
	kill_tween()
	if _panel:
		_panel.hide()
		_panel.modulate = Color.WHITE
		_panel.position = Vector2.ZERO
	_is_retreated = false


# ═══════════════════════════════════════════
#  内部辅助
# ═══════════════════════════════════════════

func _build_tween(parallel: bool) -> void:
	kill_tween()
	_tween = _panel.create_tween()
	if parallel:
		_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)


func _clamp_to_viewport(pos: Vector2) -> void:
	if _panel == null:
		return
	var viewport_size = _panel.get_viewport_rect().size
	var margin = 20
	if pos.x + _panel.size.x > viewport_size.x - margin:
		pos.x = viewport_size.x - _panel.size.x - margin
	pos.y = clampf(pos.y, 40, viewport_size.y - _panel.size.y - margin)


func _animate_children_stagger(container: Control) -> void:
	var delay = stagger_start_delay
	for i in container.get_child_count():
		var child = container.get_child(i)
		child.modulate = Color(1, 1, 1, 0.0)
		_tween.tween_property(child, "modulate", Color.WHITE, 0.08).set_delay(delay)
		delay += stagger_step_delay
