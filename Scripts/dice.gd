extends RigidBody3D

signal selected(dice_node, effect_type, value)

var hidden_effect: String = "neutral"

# --- НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ОБВОДКИ ---
# ВАЖНО: убедись, что имя "MeshInstance3D" совпадает с именем узла твоей 3D-модели в сцене кубика!
@onready var mesh: MeshInstance3D = $D6_B_red2/D6_B_red
var outline_mat: StandardMaterial3D
var is_hovered: bool = false

func _ready() -> void:
	# 1. Создаем материал обводки прямо в коде, чтобы не настраивать его вручную
	outline_mat = StandardMaterial3D.new()
	outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Светится сам по себе
	outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT # Рисуем полигоны наизнанку для эффекта обводки
	outline_mat.grow = true # Включаем режим "расширения" модели
	outline_mat.grow_amount = 0.05 # Базовая толщина обводки
	outline_mat.albedo_color = Color(1.0, 0.8, 0.2) # Золотистый цвет (можешь поменять цифры RGB)

	# 2. Подключаем встроенные сигналы Godot для отслеживания курсора
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

# --- НОВЫЕ ФУНКЦИИ ДЛЯ МЫШИ ---
func _on_mouse_entered() -> void:
	# Получаем доступ к главной сцене игры
	var main_scene = get_tree().current_scene
	
	# Подсвечиваем кубик ТОЛЬКО если сейчас ход игрока (чтобы не дразнить во время хода ИИ)
	if main_scene and "is_player_turn" in main_scene and main_scene.is_player_turn:
		mesh.material_overlay = outline_mat
		is_hovered = true

func _on_mouse_exited() -> void:
	# Убираем обводку, когда курсор уходит
	mesh.material_overlay = null
	is_hovered = false

func _process(delta: float) -> void:
	# Анимация "переливания": заставляем толщину обводки пульсировать с помощью синусоиды
	if is_hovered and outline_mat:
		var time = Time.get_ticks_msec() / 1000.0
		# Толщина будет плавно меняться от 0.025 до 0.055
		outline_mat.grow_amount = 0.04 + (sin(time * 8.0) * 0.015)

# --- ТВОИ СТАРЫЕ ФУНКЦИИ ОСТАЮТСЯ БЕЗ ИЗМЕНЕНИЙ ---

func setup(round_num: int) -> void:
	if round_num == 1:
		hidden_effect = "neutral"
	else:
		# Рандомизируем все 4 эффекта
		var roll = randf()
		if roll <= 0.25:
			hidden_effect = "heal"
		elif roll <= 0.50:
			hidden_effect = "damage"
		elif roll <= 0.75:
			hidden_effect = "armor"
		else:
			hidden_effect = "poison"

func get_top_number() -> int:
	# ... твой код без изменений ...
	var up_vector = Vector3.UP
	var b = global_transform.basis
	
	var faces_dirs = [
		b.x.normalized(),   # 0: Локальный +X
		(-b.x).normalized(),# 1: Локальный -X
		b.y.normalized(),   # 2: Локальный +Y
		(-b.y).normalized(),# 3: Локальный -Y
		b.z.normalized(),   # 4: Локальный +Z
		(-b.z).normalized() # 5: Локальный -Z
	]
	
	var max_dot = -1.0
	var best_index = -1
	
	for i in range(6):
		var dot_product = faces_dirs[i].dot(up_vector)
		if dot_product > max_dot:
			max_dot = dot_product
			best_index = i
			
	var face_values = [2, 5, 6, 1, 3, 4]
	return face_values[best_index]

func _input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var real_value = 0
		if hidden_effect != "neutral":
			real_value = get_top_number()
			
		selected.emit(self, hidden_effect, real_value)
