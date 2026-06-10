extends Node2D
class_name CombatUnit

## 策划可以在编辑器里直接拖入不同的 .tres 配置文件
@export var stats: CharacterStats
@export var unit_color: Color = Color.WHITE

@onready var sprite = $ColorRect

func _ready():
	sprite.color = unit_color
	if stats:
		stats = stats.duplicate() # 保证每个实例数据独立
