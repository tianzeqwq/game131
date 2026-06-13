class_name BattleSceneAssembler
extends RefCounted

## Battle Scene 组合根（Composition Root）
##
## 职责：创建并组装战斗系统的所有组件。
## 战斗单位位置从场景中的 SpawnPoint 节点读取，不硬编码。

const COMBAT_UNIT_SCENE = preload("res://src/scenes/battle/CombatUnit.tscn")

# 被组装的组件
var battle_controller: BattleController
var battle_hud: BattleHUD
var player_party: Array[Combatant] = []
var enemy_party: Array[Combatant] = []

var is_battle_active: bool:
	get: return battle_controller.is_battle_active if battle_controller else false

# 内部引用（由 assemble() 注入）
var _parent: Node3D
var _stage: Node3D
var _ui: Control
var _combat_log: RichTextLabel
var _player_spawns: Node3D
var _enemy_spawns: Node3D
var _unit_map: Dictionary = {}
var _input_handler: PlayerInputHandler
var _event_controller: CombatEventController
var _combat_log_adapter: CombatLogAdapter

# 信号桥接
signal battle_ended(players_won: bool)


## 组装所有组件
func assemble(
	parent: Node3D,
	stage: Node3D,
	ui: Control,
	combat_log: RichTextLabel,
	player_spawns: Node3D,
	enemy_spawns: Node3D,
	player_stats: Array[CharacterStats],
	enemy_stats: Array[CharacterStats]
) -> void:
	_parent = parent
	_stage = stage
	_ui = ui
	_combat_log = combat_log
	_player_spawns = player_spawns
	_enemy_spawns = enemy_spawns
	randomize()

	_initialize_parties(player_stats, enemy_stats)
	_initialize_controllers()
	_initialize_hud()
	_initialize_logging()
	_initialize_event_controller()
	_initialize_input_handler()
	_connect_battle_signals()

	battle_hud.update_all()


## 计算战斗结果
func calculate_battle_result() -> Dictionary:
	var players_won = enemy_party.all(func(e): return not e.is_alive())
	var money = 0
	var drops: Array[String] = []
	if players_won:
		for e in enemy_party:
			if not e.is_alive() and e.stats is EnemyStats:
				var enemy_stats := e.stats as EnemyStats
				money += enemy_stats.money
				for item in enemy_stats.drop_items:
					drops.append(item)
				if enemy_stats.held_item != "":
					drops.append("[携带] " + enemy_stats.held_item)
	return {
		"won": players_won,
		"money": money,
		"drops": drops
	}


# ============================================================
#  私有初始化方法
# ============================================================

## 从 SpawnPoint 节点读取位置，不硬编码 Vector3
func _initialize_parties(player_stats: Array[CharacterStats], enemy_stats: Array[CharacterStats]) -> void:
	player_party.clear()
	enemy_party.clear()
	_unit_map.clear()

	var idx = 0
	for stats_res in player_stats:
		if stats_res == null:
			continue
		var unit = COMBAT_UNIT_SCENE.instantiate()
		unit.name = "Player%d" % (idx + 1)
		unit.stats = stats_res
		unit.transform = _player_spawns.get_child(idx).transform
		unit.unit_color = Color(1.0, 1.0 - idx * 0.3, 1.0 - idx * 0.3)
		_stage.add_child(unit)

		var combatant = Combatant.new(unit, true)
		player_party.append(combatant)
		_unit_map[stats_res.unit_name] = unit
		idx += 1

	idx = 0
	for stats_res in enemy_stats:
		if stats_res == null:
			continue
		var unit = COMBAT_UNIT_SCENE.instantiate()
		unit.name = "Enemy%d" % (idx + 1)
		unit.stats = stats_res
		unit.transform = _enemy_spawns.get_child(idx).transform
		unit.unit_color = Color(0.4 + idx * 0.3, 0.8, 1.0)
		_stage.add_child(unit)

		var combatant = Combatant.new(unit, false)
		enemy_party.append(combatant)
		_unit_map[stats_res.unit_name] = unit
		idx += 1


func _initialize_controllers() -> void:
	battle_controller = BattleController.new()
	_parent.add_child(battle_controller)
	battle_controller.player_party = player_party
	battle_controller.enemy_party = enemy_party


func _initialize_hud() -> void:
	var timeline_bar = _ui.get_node("TimelineBar") as TimelineBar

	# 隐藏模板 UI 元素（运行时动态创建每个战斗单位的独立条）
	var player_hp_bar = _ui.get_node("PlayerHPBar") as ProgressBar
	var enemy_hp_bar = _ui.get_node("EnemyHPBar") as ProgressBar
	var player_label = _ui.get_node("PlayerLabel") as Label
	var enemy_label = _ui.get_node("EnemyLabel") as Label

	player_hp_bar.visible = false
	enemy_hp_bar.visible = false
	player_label.visible = false
	enemy_label.visible = false

	_combat_log.scroll_following = true
	_combat_log.visible = true

	battle_hud = BattleHUD.new()
	_parent.add_child(battle_hud)
	battle_hud.setup(timeline_bar, battle_controller, player_hp_bar, enemy_hp_bar, player_label, enemy_label, _ui)

	for i in range(player_party.size()):
		battle_hud.setup_for_combatant(player_party[i], i, true)
	for i in range(enemy_party.size()):
		battle_hud.setup_for_combatant(enemy_party[i], i, false)

	for c in player_party + enemy_party:
		c.state_changed.connect(battle_hud.update_all)


func _initialize_logging() -> void:
	# 创建通用日志路由器
	var router := LogRouter.new()
	router.register_sink(UISink.new(_combat_log))
	router.register_sink(ConsoleSink.new())
	router.register_sink(FileSink.new())
	GameLogger.initialize(router)

	# 桥接战斗领域事件 → 通用日志
	_combat_log_adapter = CombatLogAdapter.new()
	_combat_log_adapter.start_listening()


func _initialize_event_controller() -> void:
	_event_controller = CombatEventController.new()
	_event_controller.setup(_parent, _unit_map, battle_controller.timeline, player_party + enemy_party)
	CombatEventBus.event_dispatched.connect(_event_controller._on_combat_event)


func _initialize_input_handler() -> void:
	_input_handler = PlayerInputHandler.new()
	_input_handler.setup(battle_controller, battle_hud, player_party, enemy_party, _ui)


func _connect_battle_signals() -> void:
	battle_controller.round_started.connect(_on_battle_round_started)
	battle_controller.turn_advanced.connect(_on_battle_turn_advanced)
	battle_controller.player_action_requested.connect(_on_battle_player_action_requested)
	battle_controller.unit_skipped_broken.connect(_on_battle_unit_skipped)
	battle_controller.enemy_analyzing.connect(_on_battle_enemy_analyzing)

	battle_controller.battle_ended.connect(func(players_won):
		battle_hud.update_all()
		battle_hud.update_timeline()
		battle_ended.emit(players_won)
	)


# ============================================================
#  BattleController 信号 → UI/日志
# ============================================================

func _on_battle_round_started(round_number: int) -> void:
	CombatEventBus.publish(CombatEventFlow.new("", "round_started", round_number))
	battle_hud.update_timeline()
	battle_hud.update_all()

func _on_battle_turn_advanced(actor: Combatant) -> void:
	battle_hud.update_timeline()
	battle_hud.update_all()

func _on_battle_player_action_requested(actor: Combatant) -> void:
	# 先刷新 HUD，确保 current_actor 的标记（▶、高亮）指向正确的单位
	battle_hud.update_all()
	# 轮到玩家行动时自动打开技能选择面板
	_input_handler._on_skill_pressed()

func _on_battle_unit_skipped(actor: Combatant) -> void:
	CombatEventBus.publish(CombatEventFlow.new(actor.stats.unit_name, "unit_skipped"))

func _on_battle_enemy_analyzing(actor: Combatant) -> void:
	CombatEventBus.publish(CombatEventFlow.new(actor.stats.unit_name, "enemy_analyzing"))
