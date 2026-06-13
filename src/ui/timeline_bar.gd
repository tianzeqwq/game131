class_name TimelineBar
extends Control

## 行动轴 UI 组件
##
## 在屏幕左上方显示一行头像序列：
##   [头像1] [头像2] | [头像3] [头像4]
##    ← 当前回合 →   │  ← 下一回合 →
##
## 用法：每回合调用 refresh(active_queue, next_round_queue)

const AVATAR_SIZE: int = 48
const AVATAR_GAP: int = 4

@onready var container: HBoxContainer = $HBoxContainer

## 分隔线（"下一回合"标记）的资源
var divider_scene: PackedScene = preload("res://src/ui/timeline_divider.tscn")

## 刷新整个行动轴
func refresh(active_queue: Array[Combatant], next_queue: Array[Combatant]) -> void:
	_clear_container()
	
	# 当前回合头像
	for c in active_queue:
		_add_avatar(c)
	
	# 分隔线（仅当下一回合有内容时）
	if not next_queue.is_empty():
		_add_divider()
		
		# 下一回合头像
		for c in next_queue:
			_add_avatar(c)

## 清空容器中所有动态生成的子节点
func _clear_container() -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

## 添加单个头像槽位
func _add_avatar(combatant: Combatant) -> void:
	var slot = TextureRect.new()
	slot.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# 使用专门的 avatar 头像图标（区别于 idle_sprite 3D 贴图）
	if combatant.stats and combatant.stats.avatar:
		slot.texture = combatant.stats.avatar
	
	container.add_child(slot)

## 添加"下一回合"分隔线
func _add_divider() -> void:
	var divider = divider_scene.instantiate()
	container.add_child(divider)
