class_name CombatEventSkillSelect
extends CombatEvent

## 技能选择领域事件
##
## 纯数据：记录玩家技能选择面板的交互过程（打开、选择、增幅、确认、取消）。
## 不含任何 BBCode 或 UI 格式信息。

var unit_name: String      # 执行者名称
var action_type: String    # "open" | "select" | "boost" | "confirm" | "cancel"
var skill_name: String     # 技能名（"open"/"cancel" 时为空）
var value: float = 0.0     # 可选数值（增幅等级等）
var current_bp: int = 0    # 当前BP（事件发生时）
var max_bp: int = 0        # 最大BP


func _init(
	p_unit_name: String,
	p_action_type: String,
	p_skill_name: String = "",
	p_value: float = 0.0,
	p_current_bp: int = 0,
	p_max_bp: int = 0
) -> void:
	super()
	unit_name = p_unit_name
	action_type = p_action_type
	skill_name = p_skill_name
	value = p_value
	current_bp = p_current_bp
	max_bp = p_max_bp
