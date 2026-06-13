extends Node3D

func _process(delta):
	var cam = get_viewport().get_camera_3d()

	if cam == null:
		return

	look_at(
		Vector3(
			cam.global_position.x,
			global_position.y,
			cam.global_position.z
		),
		Vector3.UP
	)
