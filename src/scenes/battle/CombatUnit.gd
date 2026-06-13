@tool
extends Node3D
class_name CombatUnit

## 策划可以在编辑器里直接拖入不同的 .tres 配置文件
@export var stats: CharacterStats:
	set(v):
		stats = v
		if Engine.is_editor_hint(): # 如果在编辑器内
			update_visuals()

@export var unit_color: Color = Color.WHITE

@onready var visual = $Sprite3D

func _ready():
	update_visuals()
	if stats:
		if not Engine.is_editor_hint():
			stats = stats.duplicate() # 仅在游戏运行时复制数据

## 在编辑器中，如果资源没有及时刷新，可以通过这个函数强制更新
func _process(_delta):
	if Engine.is_editor_hint():
		# 检查是否需要更新编辑器内的显示
		if stats and visual and visual.texture != stats.idle_sprite:
			update_visuals()

func update_visuals():
	# 资深写法：在 tool 模式下，@onready 可能未就绪，使用 get_node 确保安全
	if visual == null: 
		visual = get_node_or_null("Sprite3D")
	
	if visual == null: return
	
	if stats and stats.idle_sprite:
		visual.texture = stats.idle_sprite
	elif visual.texture == null:
		# 兜底方案：如果没有贴图，创建一个纯白的 100x100 贴图作为占位符
		var image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		var tex = ImageTexture.create_from_image(image)
		visual.texture = tex
	
	visual.modulate = unit_color

## 攻击动作接口
func play_attack_animation():
	if not stats: return
	
	var original_tex = visual.texture

	if stats.attack_sprite:
		visual.texture = stats.attack_sprite
	
	await get_tree().create_timer(0.3).timeout
	
	visual.texture = original_tex
