class_name SkillConfig
extends Resource

## 技能配置资源
##
## 策划可在编辑器中将此 Resource 拖入技能 Action，
## 自由调整伤害倍率、命中率等参数，无需修改代码。

@export var skill_name: String = "技能"

## 伤害类型: "physical" | "digital"
@export var damage_type: String = "physical"

## 技能基础伤害倍率（用于公式中的 skill_multiplier）
@export var damage_multiplier: float = 1.0

## 技能基础命中率（0.0~1.0，用于公式中的 skill_accuracy）
@export_range(0.0, 1.0)
var accuracy: float = 1.0

## 段数增长方式:
## - "linear" = 1 + boost_level（每级多一段，如普攻/黑客）
## - "single" = 始终 1 段（如技能）
@export var hit_mode: String = "single"

## 技能产生的热量（仅 SkillAction 使用）
@export var heat_generated: float = 0.0

## 是否需要目标
@export var requires_target: bool = true

func get_hit_count(boost_level: int) -> int:
	match hit_mode:
		"linear":
			return 1 + boost_level
		_:
			return 1
