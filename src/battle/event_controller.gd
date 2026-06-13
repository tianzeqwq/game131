class_name CombatEventController
extends RefCounted

## 战斗事件控制器
##
## 职责：监听 CombatEventBus，处理视觉反馈（震动）和 Break 时序管理。
## 从 Main.gd 提取，遵循单一职责原则。

var _main: Node3D
var _unit_map: Dictionary = {}
var _timeline: BattleTimeline
var _log: RichTextLabel
var _all_combatants: Array[Combatant] = []


func setup(main: Node3D, unit_map: Dictionary, timeline: BattleTimeline, all_combatants: Array[Combatant]) -> void:
	_main = main
	_unit_map = unit_map
	_timeline = timeline
	_log = main.get_node("CanvasLayer/UI/CombatLog") as RichTextLabel
	_all_combatants = all_combatants


func _on_combat_event(event: CombatEvent) -> void:
	var unit_name: String = ""
	if event is CombatEventDamage:
		unit_name = (event as CombatEventDamage).target_name
	elif event is CombatEventBreak:
		var break_event = event as CombatEventBreak
		unit_name = break_event.unit_name

		if not break_event.is_recovery:
			var combatant = _find_combatant_by_name(unit_name)
			if combatant != null:
				var was_in_active = _timeline.apply_break(combatant)
				if was_in_active:
					_log.append_text(
						"[color=yellow]⚡ [%s] 被破防，本回合剩余行动被取消！[/color]\n" % unit_name
					)
				else:
					_log.append_text(
						"[color=yellow]⚡ [%s] 被破防，下一回合将被跳过！[/color]\n" % unit_name
					)
	elif event is CombatEventHeat:
		unit_name = (event as CombatEventHeat).unit_name
	elif event is CombatEventAction:
		unit_name = (event as CombatEventAction).unit_name

	if unit_name != "" and _unit_map.has(unit_name):
		_shake_node(_unit_map[unit_name])


func _find_combatant_by_name(name: String) -> Combatant:
	for c in _all_combatants:
		if c.stats.unit_name == name:
			return c
	return null


func _shake_node(node: CombatUnit) -> void:
	if _main == null: return
	var tween = _main.create_tween()
	var orig_pos = node.global_transform.origin
	for i in range(4):
		var rand_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		tween.tween_property(node, "global_transform:origin", orig_pos + rand_offset, 0.05)
	tween.tween_property(node, "global_transform:origin", orig_pos, 0.05)
