extends Node3D

## ============================================================
#  Main — 编辑器测试入口
#
#  仅在编辑器中打开 main.tscn 时生效，
#  用于直接调试战斗场景，不需从世界地图进入。
#
#  外部调用方请使用 battle_scene.tscn：
#    var battle = preload("res://src/scenes/battle/battle_scene.tscn").instantiate()
#    add_child(battle)
#    battle.init_battle(party_stats, enemy_stats)
#    battle.start_fight()
#    var result = await battle.battle_finished
# ============================================================

@export var player_stats_templates: Array[CharacterStats] = []
@export var enemy_stats_templates: Array[CharacterStats] = []


func _ready():
	var battle_scene = $BattleScene as BattleScene
	battle_scene.init_battle(player_stats_templates, enemy_stats_templates)
	battle_scene.start_fight()
	await battle_scene.battle_finished
	print("战斗测试结束")
