class_name CombatEvent
extends RefCounted

## 战斗领域事件基类
##
## 只包含纯粹的数据（时间戳），不含任何 UI 样式或格式信息。
## 所有具体事件类型都继承自此基类。

var timestamp: float

func _init() -> void:
	timestamp = Time.get_unix_time_from_system()
