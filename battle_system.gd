extends Node2D

@export var player_character: CharacterStats
var enemy_stats: CharacterStats

enum TurnState { PLAYER, ENEMY }
var current_turn = TurnState.PLAYER

@onready var player_label = $CanvasLayer/UI/PlayerLabel
@onready var enemy_label = $CanvasLayer/UI/EnemyLabel
@onready var combat_log = $CanvasLayer/UI/CombatLog
@onready var player_hp_bar = $CanvasLayer/UI/PlayerHPBar
@onready var enemy_hp_bar = $CanvasLayer/UI/EnemyHPBar
@onready var player_rect = $Visuals/PlayerSquare
@onready var enemy_rect = $Visuals/EnemySquare

func _ready():
	# Setup Enemy for demo
	enemy_stats = CharacterStats.new()
	enemy_stats.unit_name = "Enemy"
	
	# 绑定信号
	player_character.stats_changed.connect(_update_interface)
	player_character.message_logged.connect(_on_log_received.bind(player_rect))
	enemy_stats.stats_changed.connect(_update_interface)
	enemy_stats.message_logged.connect(_on_log_received.bind(enemy_rect))
	
	# 初始化进度条
	player_hp_bar.max_value = player_character.max_hp
	enemy_hp_bar.max_value = enemy_stats.max_hp
	
	$CanvasLayer/UI/Actions/Attack.pressed.connect(_on_attack_pressed)
	$CanvasLayer/UI/Actions/Hack.pressed.connect(_on_hack_pressed)
	$CanvasLayer/UI/Actions/Skill.pressed.connect(_on_skill_pressed)
	
	_update_interface()

func _input(event):
	# Card 102: Turn switching with Space
	if event.is_action_pressed("ui_accept") and current_turn == TurnState.PLAYER:
		_start_enemy_turn()

func _update_interface():
	player_label.text = "Player\nHeat: %d%%" % player_character.heat
	player_hp_bar.value = player_character.hp
	player_hp_bar.get_node("ShieldBar").value = player_character.shell
	
	enemy_label.text = "Enemy"
	enemy_hp_bar.value = enemy_stats.hp
	enemy_hp_bar.get_node("ShieldBar").value = enemy_stats.firewall

func _on_log_received(msg: String, target_rect: ColorRect):
	combat_log.append_text(msg + "\n")
	_shake_obj(target_rect)

func _shake_obj(obj: Control):
	var tween = create_tween()
	var orig = obj.position
	for i in range(4):
		var rand_pos = orig + Vector2(randf_range(-5,5), randf_range(-5,5))
		tween.tween_property(obj, "position", rand_pos, 0.05)
	tween.tween_property(obj, "position", orig, 0.05)

func _start_enemy_turn():
	current_turn = TurnState.ENEMY
	print("敌人回合开始")
	await get_tree().create_timer(1.0).timeout
	
	# Simple Enemy Action
	player_character.take_damage(10, "physical")
	
	current_turn = TurnState.PLAYER
	print("玩家回合开始")

func _on_attack_pressed():
	if current_turn == TurnState.PLAYER:
		print("剑士攻击信号收到")
		enemy_stats.take_damage(20, "physical")

func _on_hack_pressed():
	if current_turn == TurnState.PLAYER:
		print("黑客标记信号收到")
		enemy_stats.take_damage(15, "digital")

func _on_skill_pressed():
	if current_turn == TurnState.PLAYER:
		print("高级技能执行")
		player_character.add_heat(35)
		enemy_stats.take_damage(30, "physical")
