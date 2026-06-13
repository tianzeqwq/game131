class_name CombatEventAction
extends CombatEvent

## 行动领域事件
##
## 纯数据：用于记录 Boost 释放、防御姿态等非伤害性行动。
## 不含任何 BBCode 或 UI 格式信息。

var unit_name: String
var action_type: String  # "boost" | "defend" | "death"
var value: float = 0.0   # 可选数值（如 Boost 等级）

func _init(p_name: String, p_type: String, p_value: float = 0.0) -> void:
	super()
	unit_name = p_name
	action_type = p_type
	value = p_value
