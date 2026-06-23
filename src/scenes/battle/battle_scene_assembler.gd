class_name BattleSceneAssembler
extends RefCounted

## Battle Scene 组合根（Composition Root）
##
## 重构后：完整实现八方旅人2战斗菜单动效体系
##   - "原位滑出"：一级菜单从角色位置展开
##   - "侧翼推窗"：二级面板从一级菜单右侧推出
##   - "半隐退状态"：目标选择时菜单透明化+右移
##   - "镜像逆向动效"：取消时所有动效逆向播放
##   - "一扫而空"：确认执行时菜单飞出

const COMBAT_UNIT_SCENE = preload("res://src/scenes/battle/CombatUnit.tscn")
const COMBAT_ACTION_PANEL_SCENE = preload("res://src/ui/combat_action_panel.tscn")

# Player 行动前移动到舞台中央的位置（仅 XZ 平面偏移，Y 使用角色自身高度）
const PLAYER_CENTER_STAGE_POS: Vector3 = Vector3(0.5, 0.0, -1.0)

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
var _camera: Camera3D

# 统一战斗操作面板（八方旅人2风格）
var _combat_action_panel: CombatActionPanel

# 动态子面板引用（目前最多一个活跃）
var _active_sub_panel: Panel = null

# 菜单隐藏状态标志（hide_menus() 调用后为 true）
var _menus_hidden: bool = false

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

	# 缓存摄像机（Camera3D 是 BattleScene 的直接子节点）
	_camera = _parent.get_node("Camera3D") as Camera3D
	if _camera == null:
		_camera = _parent.get_viewport().get_camera_3d()

	_initialize_parties(player_stats, enemy_stats)
	_initialize_controllers()
	_initialize_hud()
	_initialize_logging()
	_initialize_event_controller()
	_initialize_input_handler()
	_initialize_target_indicator()
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


## ── 公共辅助方法 ──

## 获取单位在屏幕空间的XY位置（用于菜单位置锚定）
## 直接使用 combatant.visual_unit 引用，避免 _unit_map 中 unit_name 重复导致的索引冲突
func get_unit_screen_pos(combatant: Combatant) -> Vector2:
	if _camera == null or not combatant.is_alive():
		return Vector2.ZERO
	var unit_node: CombatUnit = combatant.visual_unit
	if unit_node == null or not is_instance_valid(unit_node):
		return Vector2.ZERO
	return _camera.unproject_position(unit_node.global_position)


## 获取选中行动行的全局 Rect2（用于子面板精确定位）
## 返回选中行的原位位置，子面板直接在该位置展开
func get_main_menu_rect() -> Rect2:
	if _combat_action_panel == null or not _combat_action_panel.visible:
		return Rect2()
	return _combat_action_panel.get_selected_row_global_rect()


## 当前活跃的子面板是否处于打开状态
func is_sub_panel_active() -> bool:
	return _active_sub_panel != null and _active_sub_panel.visible


# ============================================================
#  私有初始化方法
# ============================================================

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

	var player_hp_bar = _ui.get_node("PlayerHPBar") as ProgressBar
	var enemy_hp_bar = _ui.get_node("EnemyHPBar") as ProgressBar
	var player_label = _ui.get_node("PlayerLabel") as Label
	var enemy_label = _ui.get_node("EnemyLabel") as Label

	player_hp_bar.visible = false
	enemy_hp_bar.visible = false
	player_label.visible = false
	enemy_label.visible = false

	_combat_log.scroll_following = true

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
	var router := LogRouter.new()
	router.register_sink(UISink.new(_combat_log))
	router.register_sink(ConsoleSink.new())
	router.register_sink(FileSink.new())
	GameLogger.initialize(router)

	_combat_log_adapter = CombatLogAdapter.new()
	_combat_log_adapter.start_listening()


func _initialize_event_controller() -> void:
	_event_controller = CombatEventController.new()
	_event_controller.setup(_parent, _unit_map, battle_controller.timeline, player_party + enemy_party)
	CombatEventBus.event_dispatched.connect(_event_controller._on_combat_event)


func _initialize_input_handler() -> void:
	_input_handler = PlayerInputHandler.new()
	# 传入 self 引用，让 PlayerAction 可以访问场景级功能
	_input_handler.setup(battle_controller, battle_hud, player_party, enemy_party, _ui, self)

	# 创建统一战斗操作面板
	_combat_action_panel = COMBAT_ACTION_PANEL_SCENE.instantiate()
	_ui.add_child(_combat_action_panel)
	_combat_action_panel.hide_panel()

	# 连接增幅变化信号 → 实时更新 HUD BP 圆点预览
	_combat_action_panel.boost_changed.connect(func(level: int):
		if battle_controller.current_actor:
			battle_hud.show_boost_preview(battle_controller.current_actor, level)
	)


func _connect_battle_signals() -> void:
	battle_controller.round_started.connect(_on_battle_round_started)
	battle_controller.turn_advanced.connect(_on_battle_turn_advanced)
	battle_controller.player_action_requested.connect(_on_battle_player_action_requested)
	battle_controller.unit_skipped_broken.connect(_on_battle_unit_skipped)
	battle_controller.enemy_analyzing.connect(_on_battle_enemy_analyzing)

	battle_controller.battle_ended.connect(func(players_won):
		battle_hud.update_all()
		battle_hud.update_timeline()
		_combat_action_panel.hide_panel()

		if players_won:
			_combat_log.append_text("[color=gold]⚔️ 战斗胜利！所有敌人已被消灭！[/color]\n")
		else:
			_combat_log.append_text("[color=red]💀 战斗失败！我方全部阵亡...[/color]\n")

		battle_ended.emit(players_won)
	)


# ============================================================
#  目标指示器（左侧箭头 + 摄像机跟随）
# ============================================================

## 箭头指示器（3D Mesh 白色带箭头，出现在高亮敌人左侧）
var _target_indicator: Node3D = null
var _indicator_tween: Tween = null

## 摄像机跟随状态
var _saved_cam_transform: Transform3D
var _saved_fov: float
var _cam_tween: Tween = null
var _is_first_indicator_call: bool = true

## Idle Sway（待机摆动）
var _idle_sway_time: float = 0.0
var _idle_sway_active: bool = true

## 创建 3D 目标选择指示器（白色锥体箭头，朝右指向敌人）
func _initialize_target_indicator() -> void:
	var indicator = Node3D.new()
	indicator.name = "TargetIndicator"
	indicator.visible = false

	# ── 箭头头部：锥体（CylinderMesh top_radius=0 形成圆锥），朝右 ──
	var head = MeshInstance3D.new()
	head.name = "ArrowHead"
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.25
	cone.height = 0.6
	cone.material = _make_white_emissive_mat()
	head.mesh = cone
	# CylinderMesh 默认沿 Y 轴，旋转使锥尖朝右
	head.rotation_degrees = Vector3(0, 0, -90)
	head.position = Vector3(0.4, 0, 0)

	indicator.add_child(head)
	_stage.add_child(indicator)
	_target_indicator = indicator

	# 保存初始摄像机位置
	if _camera:
		_saved_cam_transform = _camera.transform


## 创建白色发光材质
func _make_white_emissive_mat() -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 1.0, 1.0)
	m.emission_enabled = true
	m.emission = Color(1.0, 1.0, 1.0)
	m.emission_energy_multiplier = 2.0
	return m


## 保存摄像机初始位置
func save_camera_transform() -> void:
	if _camera:
		_saved_cam_transform = _camera.transform


## 将指示器移动到指定敌人左侧（基于角色自身朝向），箭头朝右指向敌人
func show_target_indicator(combatant: Combatant) -> void:
	if _target_indicator == null or _camera == null:
		return
	var unit_node: Node3D = combatant.visual_unit
	if unit_node == null:
		return

	# 暂停待机摆动
	pause_idle_sway()

	# 第一次调用时保存摄像机位置与 FOV
	if _is_first_indicator_call:
		_saved_cam_transform = _camera.transform
		_saved_fov = _camera.fov
		_is_first_indicator_call = false

	# 取角色自身的左侧方向（角色 local -X 轴）
	var left_dir = -unit_node.global_transform.basis.x.normalized()
	# 取角色自身的上方
	var up_dir = unit_node.global_transform.basis.y.normalized()

	# 箭头位置 = 敌人位置左侧，与敌人同一高度
	var target_pos = unit_node.global_position \
		+ left_dir * 1.0
	_target_indicator.global_position = target_pos
	_target_indicator.scale = Vector3(0.25, 0.25, 0.25)
	_target_indicator.visible = true

	if _indicator_tween and _indicator_tween.is_running():
		_indicator_tween.kill()

	# ── 镜头微动效果（Target Framing + Micro Zoom）──
	# 1. 极小位置偏移：摄像机向目标方向滑动约 0.12 单位（画面宽度的 ~3%）
	var dir_to_target = (unit_node.global_position - _saved_cam_transform.origin).normalized()
	var target_origin = _saved_cam_transform.origin + dir_to_target * 0.12

	# 2. 微 FOV 缩放：FOV 减小 0.5°，几乎察觉不到但有"注意力被拉过去"的感觉
	var target_fov = _saved_fov - 0.5

	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()
	_cam_tween = _camera.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(_camera, "transform:origin", target_origin, 0.3)
	_cam_tween.tween_property(_camera, "fov", target_fov, 0.3)


## 隐藏指示器，摄像机还原，同时清除所有 CombatUnit 上的白色自发光高亮
func hide_target_indicator() -> void:
	if _target_indicator:
		if _indicator_tween and _indicator_tween.is_running():
			_indicator_tween.kill()
		_target_indicator.scale = Vector3.ONE
		_target_indicator.visible = false

	# 摄像机平滑还原（位置 + FOV）
	if _camera and _cam_tween:
		if _cam_tween.is_running():
			_cam_tween.kill()
		_cam_tween = _camera.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_cam_tween.tween_property(_camera, "transform", _saved_cam_transform, 0.4)
		_cam_tween.tween_property(_camera, "fov", _saved_fov, 0.4)
		_cam_tween.finished.connect(_resume_idle_sway_after_restore)
	else:
		# 无 tween 时直接恢复
		_idle_sway_active = true

	_is_first_indicator_call = true

	# 安全网：清理所有 CombatUnit 的白色高亮（防止 TargetSelector 未清理的残留）
	_clear_all_unit_highlights()


## Tween 还原完成后恢复 Idle Sway
func _resume_idle_sway_after_restore() -> void:
	_idle_sway_active = true
	_idle_sway_time = 0.0


## 安全网：遍历所有已注册的 CombatUnit，清除白色自发光高亮
func _clear_all_unit_highlights() -> void:
	for c in player_party + enemy_party:
		var unit: CombatUnit = c.visual_unit
		if unit and is_instance_valid(unit):
			unit.unhighlight()


# ============================================================
#  Idle Sway（待机摆动）
# ============================================================

## 每帧更新摄像机待机摆动（正弦波驱动，画面空间偏移）
func update_camera_idle_sway(delta: float) -> void:
	if _camera == null or not _idle_sway_active:
		return
	# 如果镜头正在播放 Tween（目标选择中），不叠加 Idle Sway
	if _cam_tween and _cam_tween.is_running():
		return

	_idle_sway_time += delta

	# 极轻微画面抖动（几乎不可察觉，仅增加呼吸感）
	_camera.h_offset = sin(_idle_sway_time * 1.7) * 0.01
	_camera.v_offset = sin(_idle_sway_time * 2.3 + 1.2) * 0.01


## 暂停 Idle Sway 并重置偏移
func pause_idle_sway() -> void:
	_idle_sway_active = false
	if _camera:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


# ============================================================
#  BattleController 信号处理
# ============================================================

func _on_battle_round_started(round_number: int) -> void:
	CombatEventBus.publish(CombatEventFlow.new("", "round_started", round_number))
	battle_hud.update_timeline()
	battle_hud.update_all()

func _on_battle_turn_advanced(actor: Combatant) -> void:
	battle_hud.update_timeline()
	battle_hud.update_all()

func _on_battle_player_action_requested(actor: Combatant) -> void:
	# 0. Player 单位移动到舞台中央（面板弹出前），仅偏移 XZ，Y 保持角色自身高度
	var unit: CombatUnit = actor.visual_unit
	if unit and is_instance_valid(unit):
		unit.store_original_position()
		var center_pos = Vector3(PLAYER_CENTER_STAGE_POS.x, unit.global_position.y, PLAYER_CENTER_STAGE_POS.z)
		unit.move_to_stage_center(center_pos)
		# ★ 同步偏移 HUD 元素向左 40px（与角色移动方向一致）
		battle_hud.animate_ui_shift(actor, Vector2(-40, 0), 0.4)
		await _parent.get_tree().create_timer(0.4).timeout

	# 1. 刷新 HUD
	battle_hud.update_all()

	# 2. 用角色实际 BP 初始化增幅面板（新角色从 0 开始，上限=可用BP）
	_combat_action_panel.setup_boost(actor.bp, actor.bp, 0)

	# 3. 获取当前角色的可用行动列表
	var available_actions = _input_handler.get_available_actions(actor)

	# 4. 获取角色屏幕位置用于菜单锚定（此时已在舞台中央）
	var actor_screen_pos = get_unit_screen_pos(actor)

	# 5. 显示主菜单（带"原位滑出"动效）
	_combat_action_panel.show_for(available_actions, actor_screen_pos)

	while battle_controller.is_waiting_for_player:
		var _action_result: Array = await _combat_action_panel.action_confirmed
		var chosen_strategy: PlayerAction = _action_result[0] as PlayerAction

		# 5. 执行选中的策略（传入 assembler 引用以协调动效）
		var completed := await _input_handler.execute_action(chosen_strategy)
		if completed:
			# 清除所有子面板
			_cleanup_sub_panel()
			if _menus_hidden:
				# 面板已被 hide_menus() 隐藏（目标选择确认场景），无需恢复和飞离
				_menus_hidden = false
			else:
				# 面板仍可见（防御/全体攻击/随机目标场景），正常飞离
				if not _combat_action_panel.visible:
					_combat_action_panel.show()
				_combat_action_panel.set_disabled(false)
				await _combat_action_panel.play_execute_flyout()
			# 等待一小段时间让攻击动画和伤害数字等视觉效果完成
			await _parent.get_tree().create_timer(0.5).timeout
			# Player 单位返回原位
			if unit and is_instance_valid(unit):
				# ★ 同步还原 HUD 元素到原始位置
				battle_hud.restore_ui_positions(actor, 0.4)
				unit.return_to_original_position()
				await _parent.get_tree().create_timer(0.4).timeout
			# 延迟一帧发射完成信号
			await _parent.get_tree().process_frame
			battle_controller.player_action_completed.emit()
			return

		# 子面板取消后，恢复主菜单
		_cleanup_sub_panel()
		_combat_action_panel.restore()


func _on_battle_unit_skipped(actor: Combatant) -> void:
	CombatEventBus.publish(CombatEventFlow.new(actor.stats.unit_name, "unit_skipped"))

func _on_battle_enemy_analyzing(actor: Combatant) -> void:
	CombatEventBus.publish(CombatEventFlow.new(actor.stats.unit_name, "enemy_analyzing"))


## ── 子面板管理 ──

## 设置当前活跃子面板
func set_active_sub_panel(panel: Panel) -> void:
	_cleanup_sub_panel()
	_active_sub_panel = panel


## 清理子面板
func _cleanup_sub_panel() -> void:
	if _active_sub_panel and is_instance_valid(_active_sub_panel):
		_active_sub_panel.queue_free()
	_active_sub_panel = null


## 隐藏所有菜单（进入目标选择前）
## 直接 hide() 保留位置，而非 hide_panel() 重置位置
func hide_menus() -> void:
	_menus_hidden = true
	_combat_action_panel.hide()
	if _active_sub_panel and _active_sub_panel.has_method("hide"):
		_active_sub_panel.hide()
	# 高亮敌方单位
	battle_hud.highlight_enemies(enemy_party)


## 显示所有菜单（目标选择取消时恢复）
## 直接 show() 恢复原位，不重新定位
func show_menus() -> void:
	_menus_hidden = false
	_combat_action_panel.show()
	_combat_action_panel.restore()
	if _active_sub_panel and _active_sub_panel.has_method("show"):
		_active_sub_panel.show()
	# 取消敌方高亮
	battle_hud.unhighlight_enemies(enemy_party)
	hide_target_indicator()


## 最终确认执行时，让所有菜单飞离
func play_all_flyout() -> void:
	# 取消所有高亮
	battle_hud.unhighlight_enemies(enemy_party)
	hide_target_indicator()
	if _active_sub_panel and _active_sub_panel.has_method("play_execute_flyout"):
		await _active_sub_panel.play_execute_flyout()


# ============================================================
#  BoostPanel 代理方法（统一挂载在 CombatActionPanel 上）
# ============================================================

## 设置增幅面板
func setup_boost_panel(bp: int, limit: int, default_level: int = 0) -> void:
	if _combat_action_panel:
		_combat_action_panel.setup_boost(bp, limit, default_level)


## 显示增幅面板
func show_boost_panel() -> void:
	if _combat_action_panel:
		_combat_action_panel.show_boost()


## 隐藏增幅面板
func hide_boost_panel() -> void:
	if _combat_action_panel:
		_combat_action_panel.hide_boost()


## 获取当前增幅等级
func get_boost_level() -> int:
	if _combat_action_panel:
		return _combat_action_panel.get_boost_level()
	return 0


## 获取增幅面板的 boost_changed 信号（供外部连接）
func get_boost_changed_signal() -> Signal:
	if _combat_action_panel:
		return _combat_action_panel.boost_changed
	return Signal()


## 获取 CombatActionPanel 引用
func get_combat_action_panel() -> CombatActionPanel:
	return _combat_action_panel
