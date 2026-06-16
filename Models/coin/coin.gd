extends Node3D

func _process(delta: float) -> void:
	# Медленное вращение вокруг оси Y
	rotate_y(delta * 1.0)
