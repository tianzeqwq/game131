extends Camera3D

@export var target: Node3D
@export var offset: Vector3 = Vector3(0, 7, 10)
@export var follow_speed: float = 8.0

var fixed_rotation: Vector3

func _ready() -> void:
	fixed_rotation = rotation

func _physics_process(delta: float) -> void:
	if target == null:
		return

	global_position = global_position.lerp(
		target.global_position + offset,
		follow_speed * delta
	)

	rotation = fixed_rotation
