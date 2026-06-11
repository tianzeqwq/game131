extends Area3D
class_name Interactable

@export var prompt_text: String = "按 E 交互"

func interact():
	print("触发交互：", name)
