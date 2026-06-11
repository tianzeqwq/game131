extends CharacterBody3D

@export var move_speed: float = 5.0
@export var gravity: float = 20.0

@onready var visuals: Node3D = $Visuals
@onready var sprite: AnimatedSprite3D = $Visuals/AnimatedSprite3D

func _physics_process(delta):

	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
        "move_down"
	)

	velocity.x = input_dir.x * move_speed
	velocity.z = input_dir.y * move_speed

	if !is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	update_sprite()
	face_camera()


func update_sprite() -> void:
	var move_vec: Vector2 = Vector2(velocity.x, velocity.z)

	if move_vec.length() < 0.1:
		if sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != "idle":
				sprite.play("idle")
		return

	# 左右移动优先
	if abs(velocity.x) > abs(velocity.z):
		if sprite.sprite_frames.has_animation("move_right"):
			if sprite.animation != "move_right":
				sprite.play("move_right")

		if velocity.x < 0.0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	# 上下移动
	else:
		sprite.flip_h = false

		if velocity.z < 0.0:
			if sprite.sprite_frames.has_animation("move_up"):
				if sprite.animation != "move_up":
					sprite.play("move_up")
			else:
				sprite.play("move_down")
		else:
			if sprite.sprite_frames.has_animation("move_down"):
				if sprite.animation != "move_down":
					sprite.play("move_down")


func face_camera():

	var cam := get_viewport().get_camera_3d()

	if cam == null:
		return

	visuals.look_at(
		Vector3(
			cam.global_position.x,
			visuals.global_position.y,
			cam.global_position.z
		),
		Vector3.UP
	)

var current_interactable: Interactable = null

func _ready():
	print("当前节点:", self.name)
	for child in get_children():
		print("子节点:", child.name)
	var interact_area = get_node_or_null("InteractArea")
	if interact_area == null:
		push_error("Player 下没有找到 InteractArea 节点，请检查节点名字和位置")
		return
	interact_area.area_entered.connect(_on_interact_area_entered)
	interact_area.area_exited.connect(_on_interact_area_exited)

@warning_ignore("unused_parameter")
func _process(delta):
	if current_interactable and Input.is_action_just_pressed("interact"):
		current_interactable.interact()

func _on_interact_area_entered(area):
	if area is Interactable:
		current_interactable = area
		print(area.prompt_text)

func _on_interact_area_exited(area):
	if area == current_interactable:
		current_interactable = null
