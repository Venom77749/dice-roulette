extends Area3D

signal clicked
signal hovered(id: String, is_hovering: bool) # НОВЫЙ СИГНАЛ

@export var item_id: String = ""

func _ready() -> void:
	# Подключаем встроенные сигналы Area3D к нашим функциям
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()

func _on_mouse_entered() -> void:
	hovered.emit(item_id, true) # Сообщаем, что мышка НА предмете

func _on_mouse_exited() -> void:
	hovered.emit(item_id, false) # Сообщаем, что мышка УШЛА
