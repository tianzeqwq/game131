extends Resource
class_name CharacterStats

signal stats_changed
signal message_logged(msg: String)

@export var unit_name: String = "Unit"
@export var max_hp: float = 100.0
@export var hp: float = 100.0:
	set(v):
		hp = clamp(v, 0, max_hp)
		stats_changed.emit()

@export var shell: float = 50.0    # Physical Shield
@export var firewall: float = 50.0 # Digital Shield
@export var heat: float = 0.0:
	set(v):
		heat = clamp(v, 0, 100)
		stats_changed.emit()

var shell_broken: bool = false
var firewall_broken: bool = false

func take_damage(amount: float, type: String, attacker_name: String = "未知单位"):
	if hp <= 0: return

	var multiplier = 1.0
	var detail = "[color=yellow]%s[/color] 发动攻击 -> [color=white]%s[/color] (%s)" % [attacker_name, unit_name, type]
	
	if type == "physical":
		if shell > 0:
			shell = max(0, shell - amount)
			if shell <= 0:
				shell_broken = true
				detail += " (物理破盾!)"
		elif shell_broken:
			multiplier = 2.0
			detail += " x 2.0 (破防加成)"
			
	elif type == "digital":
		if firewall > 0:
			firewall = max(0, firewall - amount)
			if firewall <= 0:
				firewall_broken = true
				detail += " (数字破盾!)"
		elif firewall_broken:
			multiplier = 2.0
			detail += " x 2.0 (破防加成)"

	var final_damage = amount * multiplier
	hp -= final_damage
	
	message_logged.emit("%s | 基础:%.0f x 倍率:%.1f -> [color=red]损血:%.0f[/color]" % [detail, amount, multiplier, final_damage])
	
	if hp <= 0:
		hp = 0
		message_logged.emit("[color=gray]--- %s 已倒下 ---[/color]" % unit_name)

func add_heat(amount: float) -> void:
	heat += amount
	message_logged.emit("[color=cyan][%s] 负载上升 %.0f%% (当前: %.0f%%)[/color]" % [unit_name, amount, heat])
	if heat >= 100.0:
		apply_overload_penalty()
	elif heat >= 80.0:
		message_logged.emit("[color=orange][%s] 警告：进入超频状态 (80%%+)。攻击力提升 50%%，但下回合开始将反噬生命！[/color]" % unit_name)

func apply_overload_penalty() -> void:
	var damage = max_hp * 0.3
	hp -= damage
	heat = 0
	message_logged.emit("[color=red][%s] !!! 负载 100%% 瞬间过载 !!! 受到 %.0f 点反噬伤害并强制清零负载。[/color]" % [unit_name, damage])

## 新增：由 BattleManager 在回合开始时调用
func check_turn_start_heat() -> void:
	if heat >= 80.0 and heat < 100.0:
		var tick_damage = max_hp * 0.3
		hp -= tick_damage
		message_logged.emit("[color=orange][%s] 超频反噬：维持负载损耗了 %.0f 生命值。[/color]" % [unit_name, tick_damage])

## 判定是否有攻击力加成
func get_attack_multiplier() -> float:
	return 1.5 if heat >= 80.0 else 1.0

func get_status_string() -> String:
	return "%s：当前血量 %.0f，热量 %.0f%%" % [unit_name, hp, heat]
