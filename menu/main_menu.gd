extends Control

# 预加载战斗原型场景
const GAME_SCENE_PATH = "res://world/tscn/world.tscn"

@onready var start_btn: Button = %StartBtn
@onready var buttons_vbox: VBoxContainer = %ButtonsVBox
@onready var game_title: Label = %GameTitle
# 💡 引入音频节点
@onready var menu_bgm: AudioStreamPlayer = %MenuBGM

func _ready() -> void:
	# 1. 允许菜单通过键盘/手柄操控，默认让第一个按钮获取焦点
	start_btn.grab_focus()
	
	# 2. 动态遍历所有按钮，绑定通用动效信号
	for child in buttons_vbox.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_button_hovered.bind(child))
			child.focus_entered.connect(_on_button_hovered.bind(child))
			child.mouse_exited.connect(_on_button_unhovered.bind(child))
			child.focus_exited.connect(_on_button_unhovered.bind(child))
			child.pressed.connect(_on_button_pressed.bind(child.name))

	# 3. 动态代码美化：标题居中样式
	game_title.add_theme_color_override("font_color", Color(2.028, 0.004, 2.031, 1.0)) # 霓虹洋红
	game_title.text = "赛博朋克 · 八方旅人"
	game_title.add_theme_font_size_override("font_size", 72)
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 4. 动态代码美化：左侧按钮调大
	for child in buttons_vbox.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 36)
			child.custom_minimum_size = Vector2(300, 80)
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
			var style_empty = StyleBoxEmpty.new()
			child.add_theme_stylebox_override("normal", style_empty)
			child.add_theme_stylebox_override("hover", style_empty)
			child.add_theme_stylebox_override("pressed", style_empty)
			child.add_theme_stylebox_override("focus", style_empty)
			
			child.add_theme_color_override("font_color", Color(0.5, 0.8, 0.8, 1.0))
			child.add_theme_color_override("font_focus_color", Color(0.0, 2.5, 2.5, 1.0))
			child.add_theme_color_override("font_hover_color", Color(0.0, 2.5, 2.5, 1.0))

func _on_button_hovered(btn: Button) -> void:
	btn.set("theme_override_constants/outline_size", 0)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "theme_override_constants/outline_size", 8, 0.1)
	tween.tween_property(btn, "position:x", 30.0, 0.15)
	
	var neon_cyan = Color(0.0, 2.5, 2.5, 1.0) 
	tween.tween_property(btn, "modulate", neon_cyan, 0.15)

func _on_button_unhovered(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "theme_override_constants/outline_size", 0, 0.1)
	tween.tween_property(btn, "position:x", 0.0, 0.15)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.15)

# 🛠️ 按钮点击事件处理
func _on_button_pressed(button_name: String) -> void:
	match button_name:
		"StartBtn":
			if ResourceLoader.exists(GAME_SCENE_PATH):
				
				var fade_tween = create_tween()
				fade_tween.tween_property(menu_bgm, "volume_db", -60.0, 1.0)
				
				# 当淡出动画结束时，再执行场景切换
				fade_tween.finished.connect(func():
					get_tree().change_scene_to_file(GAME_SCENE_PATH)
				)
			else:
				print_debug("错误：未找到战斗原型场景，请检查路径！")
		"LoadBtn":
			print("读取底层神经存档...")
		"SettingsBtn":
			print("打开义体设置面板...")
		"ExitBtn":
			get_tree().quit()
