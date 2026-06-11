extends RigidBody3D

signal selected(dice_node, effect_type, value)

var hidden_effect: String = "neutral"

func setup(round_num: int) -> void:
	if round_num == 1:
		hidden_effect = "neutral"
	else:
		# Эффект (яд/лечение) все еще определяется случайно при спавне
		if randf() > 0.5:
			hidden_effect = "heal"
		else:
			hidden_effect = "damage"

# Функция, которая определяет, какая грань смотрит вверх
func get_top_number() -> int:
	var up_vector = Vector3.UP
	var b = global_transform.basis
	
	# Получаем направления всех 6 сторон кубика
	var faces_dirs = [
		b.x.normalized(),   # 0: Локальный +X
		(-b.x).normalized(),# 1: Локальный -X
		b.y.normalized(),   # 2: Локальный +Y
		(-b.y).normalized(),# 3: Локальный -Y
		b.z.normalized(),   # 4: Локальный +Z
		(-b.z).normalized() # 5: Локальный -Z
	]
	
	# Ищем ту сторону, которая сильнее всего совпадает с направлением "Вверх"
	var max_dot = -1.0
	var best_index = -1
	
	for i in range(6):
		var dot_product = faces_dirs[i].dot(up_vector)
		if dot_product > max_dot:
			max_dot = dot_product
			best_index = i
			
	# значения зависят от того, как нарисована текстура на кубике.
	var face_values = [
		2, # Индекс 0 (+X)
		5, # Индекс 1 (-X)
		6, # Индекс 2 (+Y)
		1, # Индекс 3 (-Y)
		3, # Индекс 4 (+Z)
		4  # Индекс 5 (-Z)
	]
	
	return face_values[best_index]

func _input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# Если это первый раунд - значение 0. Иначе - считываем физическую грань!
		var real_value = 0
		if hidden_effect != "neutral":
			real_value = get_top_number()
			
		selected.emit(self, hidden_effect, real_value)
		
		# input_ray_pickable = false
		# queue_free()
