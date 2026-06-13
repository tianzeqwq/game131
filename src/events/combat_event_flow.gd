class_name CombatEventFlow
extends CombatEvent

## 战斗流程领域事件
##
## 纯数据：用于记录回合开始、Break跳过、AI分析等战斗流程通知。
## 与 CombatEventAction（玩家行动）属于不同的领域概念。
## 不含任何 BBCode 或 UI 格式信息。

var unit_name: String      # 关联单位名（空字符串表示不关联特定单位）
var flow_type: String      # "round_started" | "unit_skipped" | "enemy_analyzing"
var round_number: int = 0  # 仅用于 round_started

func _init(p_unit_name: String, p_flow_type: String, p_round_number: int = 0) -> void:
	super()
	unit_name = p_unit_name
	flow_type = p_flow_type
	round_number = p_round_number
