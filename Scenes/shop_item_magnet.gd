extends Area3D

signal clicked 

func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	# Проверяем, что кликнули левой кнопкой мыши
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit() # Сообщаем главной сцене, что на магнит нажали!
