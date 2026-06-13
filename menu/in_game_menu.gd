extends Control

# 使用唯一节点访问（请在编辑器里将新增的 LoadBtn 和 ExitBtn 右键勾选“作为唯一名称访问”）
@onready var menu_list_vbox: VBoxContainer = %MenuListVBox
@onready var content_label: Label = %ContentLabel
@onready var first_button: Button = %MapBtn

func _ready() -> void:
	# 1. 游戏内菜单打开时，默认让第一个按钮（地图）获取焦点
	first_button.grab_focus()
	
	# 2. 动态遍历这 10 个功能按钮，绑定高亮、失去高亮以及点击信号
	for child in menu_list_vbox.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_menu_hovered.bind(child))
			child.focus_entered.connect(_on_menu_hovered.bind(child))
			child.mouse_exited.connect(_on_menu_unhovered.bind(child))
			child.focus_exited.connect(_on_menu_unhovered.bind(child))
			child.pressed.connect(_on_menu_pressed.bind(child.name))
			
	# 3. 游戏内菜单专属的视觉初始化
	_beautify_in_game_menu()

# 🎯 动效博弈：选中菜单时向右滑动，并动态刷新右侧的测试面板内容
func _on_menu_hovered(btn: Button) -> void:
	# 💡 【核心修复】如果当前按钮没有焦点，强制让它夺取焦点！
	# 这样可以立刻解除上一个按钮（比如地图）的焦点状态，让上一个按钮触发 _on_menu_unhovered 缩回去
	if not btn.has_focus():
		btn.grab_focus()
		return # 抢到焦点后会再次触发 focus_entered，所以直接返回，避免 Tween 重复播放

	btn.set("theme_override_constants/outline_size", 0)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "position:x", 25.0, 0.12) # 向右平滑移出一点
	
	# 赛博高亮青色
	var neon_cyan = Color(0.0, 2.5, 2.5, 1.0)
	tween.tween_property(btn, "modulate", neon_cyan, 0.12)
	
	# 当手柄/键盘滑到某个菜单时，右侧内容实时联动预览
	_update_right_panel_preview(btn.name)

func _on_menu_unhovered(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "position:x", 0.0, 0.12) # 缩回原位
	tween.tween_property(btn, "modulate", Color.WHITE, 0.12)

# 🖥️ 右侧面板实时预览内容控制（已补齐新增按钮的预览文本）
func _update_right_panel_preview(menu_name: String) -> void:
	match menu_name:
		"MapBtn":
			content_label.text = "[ 地图 ]\n\n查看地图"
		"LoadBtn":
			content_label.text = "[ 读取存档 ]\n\n重新加载最近一次保存的数据。\n\n⚠️ 警告：当前未保存的进度将会丢失。"
		"BagBtn":
			content_label.text = "[ 背包 ]\n\n查看你背包"
		"CharBtn":
			content_label.text = "[ 角色 ]\n\n查看角色的数值和装备等"
		"TeamBtn":
			content_label.text = "[ 队伍 ]\n\n编辑队伍"
		"SkillBtn":
			content_label.text = "[ 技能 ]\n\n查看技能"
		"HealBtn":
			content_label.text = "[ 治疗技能 ]\n\n使用治疗技能在战斗外恢复"
		"QuestBtn":
			content_label.text = "[ 任务日志 ]\n\n查看任务详情"
		"GuideBtn":
			content_label.text = "[ 教学和说明 ]\n\n查看说明和教学"
		"ExitBtn":
			content_label.text = "[ 退出游戏 ]\n\n退出游戏"

# 🛠️ 按钮实际点击确认事件
func _on_menu_pressed(menu_name: String) -> void:
	print("你点击了功能: ", menu_name)
	match menu_name:
		"LoadBtn":
			print("【系统】正在安全调取底层存档...")
			# 这里预留给你们小队的程序A未来对接具体的读档逻辑
		"ExitBtn":
			print("【系统】切断连接，正在安全关闭游戏进程...")
			get_tree().quit() # 退出整个游戏

# 🎨 纯代码动态样式注入
func _beautify_in_game_menu() -> void:
	menu_list_vbox.custom_minimum_size = Vector2(240, 0) # 锁死左侧菜单宽度
	
	for child in menu_list_vbox.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 28)
			child.alignment = HORIZONTAL_ALIGNMENT_LEFT
			child.custom_minimum_size = Vector2(0, 55) # 💡 高度稍微收紧到55，保证 10 个按钮能在各种屏幕完美排开
			
			# 清空垃圾灰色背景，保持透明扁平赛博风
			var style_empty = StyleBoxEmpty.new()
			child.add_theme_stylebox_override("normal", style_empty)
			child.add_theme_stylebox_override("hover", style_empty)
			child.add_theme_stylebox_override("pressed", style_empty)
			child.add_theme_stylebox_override("focus", style_empty)
			
			# 基础青蓝色，激活时变为亮青色
			child.add_theme_color_override("font_color", Color(0.5, 0.8, 0.8, 0.8))
			child.add_theme_color_override("font_focus_color", Color(0.0, 2.5, 2.5, 1.0))
			child.add_theme_color_override("font_hover_color", Color(0.0, 2.5, 2.5, 1.0))
			
	# 初始化右侧预览字体字号
	content_label.add_theme_font_size_override("font_size", 24)
	content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 0.9))
	

func _unhandled_input(event: InputEvent) -> void:
	# 监听按键：当玩家按下 ESC 键（ui_cancel 默认绑定了键盘 ESC 和手柄的 Start/Back）
	if event.is_action_pressed("ui_cancel"):
		toggle_menu()

func toggle_menu() -> void:
	# 1. 用标准的 if-else 切换显示状态与大世界暂停状态，防止三元表达式报错
	if visible == true:
		visible = false
		get_tree().paused = false # 关闭菜单，大世界恢复运转
	else:
		visible = true
		get_tree().paused = true  # 打开菜单，大世界完全冻结
		
		# 2. 只有在菜单打开时，才强行抢占输入焦点到第一个按钮
		if first_button:
			first_button.grab_focus()
