extends Area3D

# 1. Создаем сигнал для главной сцены
signal clicked 

# 2. Создаем ту самую переменную для Инспектора
@export var item_id: String = "" 

# 3. Отправляем сигнал при клике
func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
