extends Node3D
class_name BattleScene

## ============================================================
#  Battle Scene — 对外公共接口
#
#  外部调用方使用方式：
#    var battle = preload("res://src/scenes/battle/battle_scene.tscn").instantiate()
#    add_child(battle)
#    battle.init_battle(party_stats, enemy_stats)
#    battle.start_fight()
#    var result = await battle.battle_finished
#    battle.queue_free()
# ============================================================

signal battle_finished(result: Dictionary)

var is_in_battle: bool:
	get: return _assembler != null and _assembler.is_battle_active

var _assembler: BattleSceneAssembler

@onready var _stage: Node3D = $Stage
@onready var _ui: Control = $CanvasLayer/UI
@onready var _combat_log: RichTextLabel = $CanvasLayer/UI/CombatLog
@onready var _player_spawns: Node3D = $Stage/PlayerSpawns
@onready var _enemy_spawns: Node3D = $Stage/EnemySpawns


# Idle Sway 暂时屏蔽
#func _process(delta: float) -> void:
#	if _assembler != null:
#		_assembler.update_camera_idle_sway(delta)


func init_battle(player_stats: Array[CharacterStats], enemy_stats: Array[CharacterStats]) -> void:
	_assemble(player_stats, enemy_stats)


func start_fight() -> void:
	_assembler.battle_controller.start_battle()


func _assemble(player_stats: Array[CharacterStats], enemy_stats: Array[CharacterStats]) -> void:
	_assembler = BattleSceneAssembler.new()
	_assembler.assemble(self, _stage, _ui, _combat_log, _player_spawns, _enemy_spawns, player_stats, enemy_stats)
	_assembler.battle_ended.connect(_on_battle_ended)


func _on_battle_ended(players_won: bool) -> void:
	var result = _assembler.calculate_battle_result()
	battle_finished.emit(result)
