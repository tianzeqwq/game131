class_name BoostPanel
extends Panel

## BP 增幅显示组件
##
## 居中显示「增幅」，两侧方向箭头指示可操作方向：
##   - level < max → 右侧显示 →
##   - level == max → 左侧显示 ←
## 箭头通过文字内容切换（非显隐），保持 layout 稳定，「增幅」始终居中。

signal boost_changed(level: int)

const _Config = preload("res://src/ui/ui_design_config.gd")

## 当前增幅等级 (0 = ×1, 1 = ×2, 2 = ×3 ...)
var current_level: int = 0:
	set(v):
		current_level = v
		_refresh_display()

## 可用 BP
var _current_bp: int = 0
## 允许的最大增幅
var _boost_limit: int = 3

@onready var _left_arrow: Label = $HBox/LeftArrow
@onready var _boost_text: Label = $HBox/BoostText
@onready var _right_arrow: Label = $HBox/RightArrow


func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_PASS
	# 通过工厂方法统一设置 StyleBox（取代 tscn 中的 hardcoded SubResource）
	add_theme_stylebox_override("panel", _Config.make_boost_style())
	_refresh_display()


## 初始化增幅数据
## p_current_bp: 当前 BP 数量
## p_boost_limit: 允许的最大增幅等级
## p_default_level: 默认等级（通常为 0）
func setup(p_current_bp: int, p_boost_limit: int, p_default_level: int = 0) -> void:
	_current_bp = p_current_bp
	_boost_limit = mini(p_boost_limit, _current_bp)
	current_level = clampi(p_default_level, 0, _boost_limit)
	_refresh_display()


## 获取当前消耗的 BP 数量
func get_bp_cost() -> int:
	return current_level


## 公开方法：供父面板转发 ←/→ 按键
func adjust(delta: int) -> void:
	var new_level = clampi(current_level + delta, 0, _boost_limit)
	if new_level != current_level:
		current_level = new_level
		boost_changed.emit(current_level)


## 重置到无增幅状态
func reset() -> void:
	current_level = 0


# ── 内部 ──

func _refresh_display() -> void:
	if not is_node_ready():
		return

	# 箭头通过文字控制（保持 layout 占位稳定）
	if current_level < _boost_limit:
		_left_arrow.text = ""
		_right_arrow.text = "→"
	else:
		_left_arrow.text = "←"
		_right_arrow.text = ""

	# 增幅中亮青色，否则灰色
	var active_color = _Config.COLOR_BOOST_ACTIVE if current_level > 0 else _Config.COLOR_BOOST_INACTIVE
	_boost_text.add_theme_color_override("font_color", active_color)
