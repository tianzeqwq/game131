extends Node2D

@onready var player_label = $CanvasLayer/UI/PlayerLabel
@onready var enemy_label = $CanvasLayer/UI/EnemyLabel
@onready var attack_btn = $CanvasLayer/UI/Actions/Attack
@onready var hack_btn = $CanvasLayer/UI/Actions/Hack
@onready var skill_btn = $CanvasLayer/UI/Actions/Skill
@onready var combat_log = $CanvasLayer/UI/CombatLog
@onready var player_hp_bar = $CanvasLayer/UI/PlayerHPBar
@onready var enemy_hp_bar = $CanvasLayer/UI/EnemyHPBar

# 现在直接引用场景中的 CombatUnit 节点 (假设你已经把方块做成了 CombatUnit)
@onready var player_unit: CombatUnit = $Visuals/PlayerSquare 
@onready var enemy_unit: CombatUnit = $Visuals/EnemySquare

enum Turn { PLAYER, ENEMY }
var current_turn = Turn.PLAYER

func _ready():
	# 这里的逻辑假设 PlayerSquare 节点上挂了 CombatUnit.gd
	_setup_unit(player_unit, player_hp_bar)
	_setup_unit(enemy_unit, enemy_hp_bar)

	attack_btn.pressed.connect(_on_attack_pressed)
	hack_btn.pressed.connect(_on_hack_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	
	combat_log.scroll_following = true
	_update_ui()

func _setup_unit(unit, bar):
	if unit and unit.stats:
		# 此时 stats 已经在 CombatUnit.gd 的 _ready 中 duplicate 过了
		unit.stats.stats_changed.connect(_update_ui)
		unit.stats.message_logged.connect(_on_log_received.bind(unit))
		bar.max_value = unit.stats.max_hp

func _input(event):
	# Card 102: 回合切换逻辑 (空格键)
	if event.is_action_pressed("ui_accept") and current_turn == Turn.PLAYER:
		_end_player_turn()

func _update_ui():
	var p = player_unit.stats
	var e = enemy_unit.stats
	
	# 更新标签文本
	player_label.text = "%s\nHP: %d/%d | Shield: %d\nHeat: %d%%" % [
		p.unit_name, p.hp, p.max_hp, p.shell, p.heat]
	enemy_label.text = "%s\nHP: %d/%d | Firewall: %d" % [
		e.unit_name, e.hp, e.max_hp, e.firewall]
	
	player_hp_bar.value = p.hp
	player_hp_bar.get_node("ShieldBar").value = p.shell
	enemy_hp_bar.value = e.hp
	enemy_hp_bar.get_node("ShieldBar").value = e.firewall

func _on_log_received(msg: String, target_node: Node2D):
	combat_log.append_text(msg + "\n")
	_shake_node(target_node)

func _shake_node(node: Node2D):
	var tween = create_tween()
	var orig_pos = node.global_position
	for i in range(4):
		var rand_pos = orig_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(node, "global_position", rand_pos, 0.05)
	tween.tween_property(node, "global_position", orig_pos, 0.05)

func _on_attack_pressed():
	if current_turn == Turn.PLAYER:
		var dmg = 20 * player_unit.stats.get_attack_multiplier()
		enemy_unit.stats.take_damage(dmg, "physical", player_unit.stats.unit_name)

func _on_hack_pressed():
	if current_turn == Turn.PLAYER:
		enemy_unit.stats.take_damage(15, "digital", player_unit.stats.unit_name)

func _on_skill_pressed():
	if current_turn == Turn.PLAYER:
		player_unit.stats.add_heat(35)
		var dmg = 40 * player_unit.stats.get_attack_multiplier()
		enemy_unit.stats.take_damage(dmg, "physical", player_unit.stats.unit_name)

func _end_player_turn():
	current_turn = Turn.ENEMY
	combat_log.append_text("[color=gray]--- 敌人回合 ---[/color]\n")
	
	# 模拟敌人行动延迟
	await get_tree().create_timer(1.0).timeout
	enemy_unit.stats.check_turn_start_heat()
	
	player_unit.stats.take_damage(10, "physical", enemy_unit.stats.unit_name)
	
	current_turn = Turn.PLAYER
	combat_log.append_text("[color=gray]--- 玩家回合 ---[/color]\n")
	player_unit.stats.check_turn_start_heat()