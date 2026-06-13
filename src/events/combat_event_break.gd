class_name CombatEventBreak
extends CombatEvent

## Break（系统瘫痪）领域事件
##
## 纯数据：仅含单位名称和破防类型。
## 不含任何 BBCode 或 UI 格式信息。

var unit_name: String
var break_type: String  # "shield" | "firewall"
var is_recovery: bool = false  # true 表示恢复，false 表示触发 Break

func _init(p_name: String, p_type: String, p_recovery: bool = false) -> void:
	super()
	unit_name = p_name
	break_type = p_type
	is_recovery = p_recovery
