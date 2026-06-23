@tool
extends Node3D
class_name CombatUnit

## 战斗单位视觉组件
##
## 统一使用 AnimatedSprite3D 播放帧动画。
## 动画轨道命名约定见 CharacterStats.sprite_frames。

## 策划可以在编辑器里直接拖入不同的 .tres 配置文件
@export var stats: CharacterStats:
	set(v):
		stats = v
		if Engine.is_editor_hint():
			update_visuals()

@export var unit_color: Color = Color.WHITE

@onready var anim_billboard: AnimatedSprite3D = $AnimatedSprite3D


func _ready():
	update_visuals()
	if stats:
		if not Engine.is_editor_hint():
			stats = stats.duplicate()


func _process(_delta):
	if Engine.is_editor_hint():
		if stats and stats.sprite_frames != null:
			if anim_billboard.sprite_frames != stats.sprite_frames:
				update_visuals()


## 更新视觉显示
func update_visuals():
	if anim_billboard == null:
		anim_billboard = get_node_or_null("AnimatedSprite3D")
	
	if stats and stats.sprite_frames:
		anim_billboard.sprite_frames = stats.sprite_frames
		if anim_billboard.sprite_frames and anim_billboard.sprite_frames.has_animation("idle"):
			anim_billboard.play("idle")
		elif anim_billboard.sprite_frames and anim_billboard.sprite_frames.get_animation_names().size() > 0:
			anim_billboard.play(anim_billboard.sprite_frames.get_animation_names()[0])
	else:
		# 兜底：无 sprite_frames 时创建一个占位纹理显示
		anim_billboard.sprite_frames = null
		anim_billboard.visible = true
	
	anim_billboard.modulate = unit_color


## ── 死亡状态管理 ──

var _is_dead: bool = false

## 标记为死亡并永久隐藏视觉
func mark_dead() -> void:
	_is_dead = true
	anim_billboard.modulate = Color.TRANSPARENT
	if _highlight_tween and _highlight_tween.is_running():
		_highlight_tween.kill()


## ── 白色高亮（modulate 调亮）──

var _highlight_tween: Tween = null

# 舞台移动相关
var _movement_tween: Tween = null
var _original_position: Vector3

## 记录当前世界位置作为原始位置
func store_original_position() -> void:
	_original_position = global_position


## 播放移动到舞台中央的动画
func move_to_stage_center(center_position: Vector3) -> void:
	if _movement_tween and _movement_tween.is_running():
		_movement_tween.kill()
	_movement_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_movement_tween.tween_property(self, "global_position", center_position, 0.4)


## 播放返回到原始位置的动画
func return_to_original_position() -> void:
	if _movement_tween and _movement_tween.is_running():
		_movement_tween.kill()
	_movement_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_movement_tween.tween_property(self, "global_position", _original_position, 0.4)


## 高亮为白色
func highlight_white() -> void:
	if _is_dead:
		return
	if _highlight_tween and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(anim_billboard, "modulate", Color(10, 10, 10), 0.2)


## 恢复原样
func unhighlight() -> void:
	if _is_dead:
		return
	if _highlight_tween and _highlight_tween.is_running():
		_highlight_tween.kill()
	_highlight_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(anim_billboard, "modulate", unit_color, 0.15)


## ── 攻击动画 ──
## 播放 "attack" 轨道，播完自动回到 "idle"
## 双保险：animation_finished 信号为主，计时器为兜底

func play_attack_animation():
	if not stats or not stats.sprite_frames: return
	
	if anim_billboard.sprite_frames.has_animation("attack"):
		anim_billboard.play("attack")
		
		# 计算动画时长作为兜底超时
		var sf = anim_billboard.sprite_frames
		var frame_count = sf.get_frame_count("attack")
		var total := 0.0
		for i in range(frame_count):
			total += sf.get_frame_duration("attack", i)
		var speed = sf.get_animation_speed("attack")
		var anim_time = total / speed if speed > 0 else 1.0
		
		# 双保险：信号先到则继续，超时到达也继续
		var signal_emitted = false
		var on_finished = func(): signal_emitted = true
		anim_billboard.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
		await anim_billboard.get_tree().create_timer(anim_time + 0.05).timeout
		if not signal_emitted:
			push_warning("play_attack_animation: animation_finished 信号未触发，用时器兜底")
		
		if is_instance_valid(anim_billboard):
			anim_billboard.play("idle")


## ── 受击动画 ──
## 优先播放 "hit" 轨道，缺失则闪烁红色

func play_hit_animation():
	if not is_instance_valid(self):
		return
	
	if anim_billboard.visible and anim_billboard.sprite_frames \
		and anim_billboard.sprite_frames.has_animation("hit"):
		anim_billboard.play("hit")
		await anim_billboard.animation_finished
		if is_instance_valid(anim_billboard):
			anim_billboard.play("idle")
		return
	
	# 回退：红色闪烁
	await _flash_red()


## ── 死亡动画 ──
## 优先播放 "death" 轨道，缺失则淡出

func play_death_animation():
	if not is_instance_valid(self) or _is_dead:
		return
	
	if anim_billboard.visible and anim_billboard.sprite_frames \
		and anim_billboard.sprite_frames.has_animation("death"):
		anim_billboard.play("death")
		await anim_billboard.animation_finished
		mark_dead()
		return
	
	# 回退：淡出
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(anim_billboard, "modulate", Color.TRANSPARENT, 0.3)
	await tween.finished
	mark_dead()


## ── 回退效果：红色闪烁 ──

func _flash_red() -> void:
	var original_modulate = anim_billboard.modulate
	anim_billboard.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(anim_billboard):
		anim_billboard.modulate = original_modulate
