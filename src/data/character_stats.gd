extends Resource
class_name CharacterStats

## 战斗角色基础属性
##
## 所有战斗单位（玩家&敌人）共有的核心属性。
## 玩家/敌人独有的属性请分别定义在 PlayerStats / EnemyStats 中。
##
## 属性上限：
##   - 速度/命中/会心/回避: 0 ~ 999
##   - 护盾点数: 0 ~ 99
##   - 热量: 0 ~ 100

signal stats_changed

@export var unit_name: String = "Unit"
@export var idle_sprite: Texture2D
@export var attack_sprite: Texture2D

## 头像图标（用于 UI 行动轴 TimelineBar 的小头像）
@export var avatar: Texture2D

@export_group("Resources")
@export var level: int = 1:
	set(v):
		level = max(1, v)
		stats_changed.emit()

## 战斗外能力加成（装备、天赋等），默认为 1.0
@export var ability_modifier: float = 1.0:
	set(v):
		ability_modifier = max(0.0, v)
		stats_changed.emit()

@export var bp: int = 0
@export var max_bp: int = 5
@export var max_hp: float = 100.0
@export var hp: float = 100.0:
	set(v):
		hp = clamp(v, 0, max_hp)
		stats_changed.emit()

@export_group("Offense")
@export var phys_atk: float = 10.0
@export var digi_atk: float = 10.0

@export_group("Defense")
@export var phys_def: float = 10.0
@export var digi_def: float = 10.0

@export_group("Break System")
## 护盾点数（物理层），上限 99，每次命中 -1
@export var max_shield_points: int = 0:
	set(v):
		max_shield_points = clampi(v, 0, 99)
		stats_changed.emit()
@export var shield_points: int = 0:
	set(v):
		shield_points = clampi(v, 0, max_shield_points)
		stats_changed.emit()

## 防火墙生命值（数字层），按伤害值削减
@export var max_firewall_hp: float = 0.0
@export var firewall_hp: float = 0.0:
	set(v):
		firewall_hp = clamp(v, 0, max_firewall_hp)
		stats_changed.emit()

@export_group("Skills")
## 角色拥有的技能配置列表（策划可在 Inspector 中自由拖入 SkillConfig 资源）
@export var skills: Array[SkillConfig] = []

@export_group("Attributes")
## 速度（上限 999），影响行动顺序 & 降低对方暴击率
@export var speed: int = 10:
	set(v):
		speed = clampi(v, 0, 999)
		stats_changed.emit()
## 命中（上限 999），提高命中率
@export var accuracy: int = 100:
	set(v):
		accuracy = clampi(v, 0, 999)
		stats_changed.emit()
## 回避（上限 999），降低对方命中率
@export var evasion: int = 50:
	set(v):
		evasion = clampi(v, 0, 999)
		stats_changed.emit()
## 会心（上限 999），提高暴击率
@export var crit: int = 50:
	set(v):
		crit = clampi(v, 0, 999)
		stats_changed.emit()

@export var weaknesses: Array[String] = ["physical"]

@export var heat: float = 0.0:
	set(v):
		heat = clamp(v, 0, 100)
		stats_changed.emit()

# Runtime state flags
var shield_broken: bool = false
var firewall_broken: bool = false

## 返回战斗外能力加成（供 DamageCalculator 调用）
func get_ability_modifier() -> float:
	return ability_modifier
