extends RigidBody3D

signal selected(dice_node, effect_type, value)

var hidden_effect: String = "neutral"
var effect_value: int = 0

func setup(round_num: int) -> void:
	if round_num == 1:
		hidden_effect = "neutral"
		effect_value = 0
	else:
		if randf() > 0.5:
			hidden_effect = "heal"
			effect_value = randi_range(1, 4)
		else:
			hidden_effect = "damage"
			effect_value = randi_range(1, 4)

func _input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self, hidden_effect, effect_value)
		input_ray_pickable = false
		queue_free()
