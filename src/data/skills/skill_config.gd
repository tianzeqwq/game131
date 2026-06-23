class_name SkillConfig
extends Resource

## 技能配置资源
##
## 策划可在编辑器中将此 Resource 拖入技能 Action，
## 自由调整伤害倍率、命中率等参数，无需修改代码。

@export var skill_name: String = "技能"

## 技能描述（UI 展示用，策划可在 .tres 中编辑）
@export var description: String = ""

## 伤害类型: "physical" | "digital"
@export var damage_type: String = "physical"

## 技能基础伤害倍率（用于公式中的 skill_multiplier）
@export var damage_multiplier: float = 1.0

## 技能基础命中率（0.0~1.0，用于公式中的 skill_accuracy）
@export_range(0.0, 1.0)
var accuracy: float = 1.0

## 段数计算方式:
## - "single"   = 始终 1 段（如技能）
## - "linear"   = 1 + boost_level（每级多一段，如普攻/黑客）
## - "random"   = random_hit_count（固定段数，不随 Boost 增长）
@export var hit_mode: String = "single"

## 目标选择类型:
## - "single"       = 单体目标（需选择目标）
## - "all_enemies"  = 全体敌人（自动选取）
## - "random"       = 随机目标（每次命中随机选择）
@export var target_type: String = "single":
	set(v):
		assert(v in ["single", "all_enemies", "random"], "target_type 必须是 single/all_enemies/random")
		target_type = v

## 随机命中次数（仅 hit_mode="random" 时生效，如五月雨斩=3）
@export var random_hit_count: int = 1

## 增幅上限（1~3，默认 3，限制玩家最多使用多少 BP 增幅此技能）
@export_range(1, 3)
var boost_limit: int = 3

## 增幅效果类型:
## - "hits"   = 每级 BP 增加一段攻击（如平A）
## - "damage" = 每级 BP 增加伤害倍率（如技能）
@export var boost_effect: String = "damage"

## 技能产生的热量
@export var heat_generated: float = 0.0

## 是否需要目标（false 表示无目标技能，如自buff）
@export var requires_target: bool = true

## 根据 hit_mode 和 boost_level 计算命中段数
func get_hit_count(boost_level: int) -> int:
	match hit_mode:
		"linear":
			return 1 + boost_level
		"random":
			return random_hit_count
		_: # "single"
			return 1

## 返回刻印的增幅上限（最小为 1，最大为 3）
func get_boost_limit() -> int:
	return clampi(boost_limit, 1, 3)
