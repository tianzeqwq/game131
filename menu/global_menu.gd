# res://src/global/global_menu.gd
extends Node

# 预加载你之前分离出来的菜单场景
const PAUSE_MENU_PATH = "res://menu/in_game_menu.tscn" # 或者是你具体菜单的路径
var pause_menu_instance: Control = null

func _ready() -> void:
	# 1. 强制让这个全局节点在游戏暂停时也能继续工作
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. 动态实例化菜单，并把它挂载到一个独立渲染层上
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # 确保它的层级极高，永远盖在关卡和玩家上面
	add_child(canvas_layer)
	
	pause_menu_instance = load(PAUSE_MENU_PATH).instantiate()
	canvas_layer.add_child(pause_menu_instance)
	
	# 3. 初始状态隐藏菜单，并确保菜单自身也能在暂停时操作
	pause_menu_instance.hide()
	pause_menu_instance.process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()


func toggle_menu() -> void:
	if pause_menu_instance == null:
		return
		
	if not get_tree().paused:
		# 游戏没暂停：打开菜单，定格游戏世界
		pause_menu_instance.show()
		get_tree().paused = true
	else:
		# 游戏已经暂停：关闭菜单，恢复游戏世界
		pause_menu_instance.hide()
		get_tree().paused = false
