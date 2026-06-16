extends Area3D

func _input_event(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Global.money >= 20:
			Global.money -= 20
			Global.inventory.append("magnet")
			print("Куплено! Осталось: ", Global.money)
			
			# Команда главному скрипту: "Заспавнь магнит на столе!"
			var main_scene = get_tree().current_scene
			if main_scene.has_method("spawn_items_on_table"):
				main_scene.spawn_items_on_table()
				
			queue_free() # Исчезаем с витрины
