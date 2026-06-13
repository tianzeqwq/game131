class_name CombatEventHeat
extends CombatEvent

## 负载（Heat）事件
##
## 纯数据：仅含单位名称、负载变化值和当前负载值。
## 不含任何 BBCode 或 UI 格式信息。

var unit_name: String
var heat_amount: float     # 本次增加/减少的负载量
var current_heat: float    # 变化后的当前负载值
var event_type: String     # "add" | "overload" | "tick" | "reset"

func _init(
	p_name: String,
	p_amount: float,
	p_current: float,
	p_type: String = "add"
) -> void:
	super()
	unit_name = p_name
	heat_amount = p_amount
	current_heat = p_current
	event_type = p_type
