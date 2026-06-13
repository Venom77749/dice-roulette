extends Node3D

# --- ИГРОВОЙ БАЛАНС И СТАТИСТИКА ---
@export var max_hp: int = 20 # Максимальное здоровье вынесено сюда для удобной настройки
var player_hp: int = max_hp
var ai_hp: int = max_hp
var is_player_turn: bool = true
var current_round: int = 1

# Статусные эффекты
var player_armor: int = 0
var ai_armor: int = 0
var player_poison: int = 0
var ai_poison: int = 0

enum DiceType { GOOD, BAD }

# --- ИНТЕРФЕЙС (UI) ---
@onready var player_hp_label: Label = $CanvasLayer/PlayerHP
@onready var ai_hp_label: Label = $CanvasLayer/AIHP
@onready var player_hp_bar: ProgressBar = $CanvasLayer/PlayerHealthBar
@onready var ai_hp_bar: ProgressBar = $CanvasLayer/AIHealthBar
@onready var player_effects_label: Label = $CanvasLayer/PlayerEffects
@onready var ai_effects_label: Label = $CanvasLayer/AIEffects
@onready var roll_button: Button = $CanvasLayer/Button # Кэшируем кнопку для управления её активностью

# --- ОБЪЕКТЫ НА СЦЕНЕ ---
@onready var scale_arm: Node3D = $весы/Рука
@onready var left_weight: Node3D = $весы/Рука/LeftWeight
@onready var right_weight: Node3D = $весы/Рука/RightWeight
@onready var ai_animator: AnimationPlayer = $skeleton/AnimationPlayer
@onready var spawn_point: Marker3D = $SpawnPoint # Оптимизация: кэшируем точку спавна кубиков

# --- КАМЕРА ---
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Marker3D = $CameraTarget
var default_pos: Vector3
var default_rot: Vector3
var mouse_sensitivity: float = 0.003
var is_rmb_pressed: bool = false

# --- ЗАГРУЖАЕМЫЕ СЦЕНЫ (ПРЕФАБЫ) ---
@export var dice_scene: PackedScene 
@export var floating_text_scene: PackedScene
@export var heal_particles_scene: PackedScene
@export var damage_particles_scene: PackedScene

# Снаряды душ для каждого эффекта
@export var soul_heal: PackedScene
@export var soul_damage: PackedScene
@export var soul_poison: PackedScene
@export var soul_armor: PackedScene

# Динамическая переменная для резкого "вздрагивания" весов
var scale_jolt: float = 0.0

func _ready() -> void:
	print("--- Игра началась! ---")
	print("HP Игрока: ", player_hp, " | HP ИИ: ", ai_hp)
	
	# Запоминаем изначальное положение камеры для возврата в конце раунда
	if camera:
		default_pos = camera.global_position
		default_rot = camera.global_rotation
	
	update_ui()
	roll_button.pressed.connect(_on_button_pressed)
	
func _on_button_pressed() -> void:
	# Защита: не даем бросить новые кубики, если старые еще на столе
	if get_tree().get_nodes_in_group("dice").size() > 0:
		print("Сначала разберите оставшиеся кубики!")
		return
		
	# Блокируем кнопку, чтобы игрок не спамил её во время раздачи
	roll_button.disabled = true
	is_player_turn = true
		
	# Анимация наезда камеры на стол
	if camera and camera_target:
		var tween = create_tween()
		tween.set_parallel(true) 
		tween.tween_property(camera, "global_position", camera_target.global_position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", camera_target.global_rotation, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
	print("\n=== РАУНД ", current_round, " ===")
	
	# Перед раздачей кубиков яд наносит урон (если он есть)
	process_poison()
	if player_hp <= 0 or ai_hp <= 0:
		return 
	
	# Рассчитываем количество кубиков и бросаем их
	var dice_count = current_round + randi_range(1, 2)
	print("На стол падает кубиков: ", dice_count)
	
	for i in range(dice_count):
		var new_dice = dice_scene.instantiate()
		add_child(new_dice)
		
		# Спавн вокруг центра маркера со случайным смещением
		var base_pos = spawn_point.global_position
		new_dice.global_position = Vector3(base_pos.x + randf_range(-0.5, 0.5), base_pos.y + (i * 0.5), base_pos.z + randf_range(-0.5, 0.5))
		new_dice.global_rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
		
		new_dice.setup(current_round)
		new_dice.selected.connect(_on_dice_selected)
		new_dice.add_to_group("dice")
		
		# Придаем физический импульс для красивого разлета
		var impulse = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1))
		var torque = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		new_dice.apply_central_impulse(impulse)
		new_dice.apply_torque_impulse(torque)

# --- ЛОГИКА ХОДОВ ---

func _on_dice_selected(dice_node: Node3D, effect: String, value: int) -> void:
	if not is_player_turn:
		return
		
	is_player_turn = false
	
	if dice_node.is_in_group("dice"):
		dice_node.remove_from_group("dice")
		
	# Запоминаем позицию кубика, чтобы снаряд вылетел оттуда
	var start_pos = dice_node.global_position
	dice_node.queue_free()
	
	# Ждем, пока снаряд долетит и применит эффект
	await shoot_soul_to_scales(start_pos, true, effect, value)
	
	# Передаем ход ИИ или завершаем раунд
	var dice_left = get_tree().get_nodes_in_group("dice")
	if dice_left.size() > 0:
		ai_turn()
	else:
		end_round()

func ai_turn() -> void:
	var dice_left = get_tree().get_nodes_in_group("dice")
	if dice_left.size() == 0:
		end_round()
		return
		
	# ИИ "думает" перед выбором
	var think_time = randf_range(1.0, 2.0)
	await get_tree().create_timer(think_time).timeout
	
	# Двойная проверка на случай, если кубики исчезли за время раздумий
	dice_left = get_tree().get_nodes_in_group("dice")
	if dice_left.size() == 0:
		end_round()
		return
		
	var random_index = randi() % dice_left.size()
	var ai_dice = dice_left[random_index]
	ai_dice.remove_from_group("dice")
	
	# Анимация: скелет тянется к кубику
	if ai_animator:
		ai_animator.play("take")
		await get_tree().create_timer(0.35).timeout
	
	var ai_real_value = 0
	if ai_dice.hidden_effect != "neutral":
		ai_real_value = ai_dice.get_top_number()
	
	var start_pos = ai_dice.global_position
	var effect_type = ai_dice.hidden_effect
	ai_dice.queue_free() 
	
	# Запускаем полет души ИИ
	await shoot_soul_to_scales(start_pos, false, effect_type, ai_real_value)
	
	# Возвращаем скелета в нейтральную стойку
	if ai_animator:
		ai_animator.play("idle")
	
	if get_tree().get_nodes_in_group("dice").size() == 0:
		end_round()
	else:
		is_player_turn = true

# --- ВИЗУАЛИЗАЦИЯ И МЕХАНИКА ЭФФЕКТОВ ---

func shoot_soul_to_scales(start_pos: Vector3, is_player: bool, effect: String, value: int) -> void:
	var duration: float = 0.65 # Скорость полета снарядов
	
	# 1. ОБРАБОТКА ПУСТЫШЕК (Ранний выход)
	if effect == "neutral":
		spawn_floating_text(start_pos, effect, 0)
		await get_tree().create_timer(duration).timeout
		return
		
	# 2. ВЫБОР СНАРЯДА
	var proj_scene: PackedScene = null
	match effect:
		"heal": proj_scene = soul_heal
		"damage": proj_scene = soul_damage
		"poison": proj_scene = soul_poison
		"armor": proj_scene = soul_armor
		
	if not proj_scene: 
		return
	
	# 3. СОЗДАНИЕ СНАРЯДА НА СЦЕНЕ
	var soul = proj_scene.instantiate()
	var target_node = left_weight if is_player else right_weight
	var end_pos = target_node.global_position
	
	# Собираем и направляем снаряд ДО добавления в мир
	soul.position = start_pos
	soul.look_at_from_position(start_pos, end_pos, Vector3.UP)
	add_child(soul)
	
	# Ждем 1 системный кадр, чтобы скрипты шлейфов (Trail3D) сбросили свои координаты
	await get_tree().process_frame
	
	# 4. АНИМАЦИЯ ПОЛЕТА
	var tween = create_tween()
	tween.tween_property(soul, "global_position", end_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# 5. ОЖИДАНИЕ ПРИБЫТИЯ
	await get_tree().create_timer(duration).timeout
	
	# 6. УДАР О ВЕСЫ И ПОСЛЕДСТВИЯ
	if is_instance_valid(soul):
		soul.queue_free()
	
	# Спавн визуала
	spawn_floating_text(end_pos, effect, value)
	spawn_particles(end_pos, effect)
	
	# Физический пинок весам
	scale_jolt = -15.0 if is_player else 15.0 
	
	# Итоговое применение математики эффекта
	apply_effect(is_player, effect, value)

func apply_effect(is_player: bool, effect: String, value: int) -> void:
	var target_name = "Игрок" if is_player else "ИИ"
	
	if effect == "neutral":
		print(target_name, " вытянул пустышку.")
		
	elif effect == "heal":
		if is_player:
			player_hp = min(player_hp + value, max_hp)
		else:
			ai_hp = min(ai_hp + value, max_hp)
		print(target_name, " лечится (выпало: +", value, ")")
		
	elif effect == "armor":
		if is_player:
			player_armor += value
		else:
			ai_armor += value
		print(target_name, " получает броню: +", value)
		
	elif effect == "poison":
		if is_player:
			player_poison += value 
		else:
			ai_poison += value
		print(target_name, " отравлен! Уровень яда: ", value)
		
	elif effect == "damage":
		var actual_damage = value
		
		# Логика поглощения урона (Броня берет удар на себя)
		if is_player:
			if player_armor > 0:
				var absorbed = min(player_armor, actual_damage)
				player_armor -= absorbed
				actual_damage -= absorbed
				print("🛡️ Броня Игрока поглотила ", absorbed, " урона.")
			player_hp -= actual_damage
		else:
			if ai_armor > 0:
				var absorbed = min(ai_armor, actual_damage)
				ai_armor -= absorbed
				actual_damage -= absorbed
				print("🛡️ Броня ИИ поглотила ", absorbed, " урона.")
			ai_hp -= actual_damage
			
		print(target_name, " получает урон: -", actual_damage, " HP")
		
	update_ui()
	check_win_condition()

func process_poison() -> void:
	# Вызывается каждый раунд перед раздачей кубиков
	if player_poison > 0:
		print("\nЯд действует на Игрока: -", player_poison, " HP")
		player_hp -= player_poison 
		player_poison -= 1
		
	if ai_poison > 0:
		print("\n☠️ Яд действует на ИИ: -", ai_poison, " HP")
		ai_hp -= ai_poison
		ai_poison -= 1
		
	update_ui()
	check_win_condition()

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (VFX и UI) ---

func spawn_particles(pos: Vector3, effect: String) -> void:
	var particles: CPUParticles3D = null 
	
	if effect == "heal" and heal_particles_scene:
		particles = heal_particles_scene.instantiate()
	elif effect == "damage" and damage_particles_scene:
		particles = damage_particles_scene.instantiate()
		
	if particles:
		add_child(particles) 
		particles.global_position = pos
		particles.emitting = true 
		# Автоматическое удаление системы частиц после завершения
		get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)

func spawn_floating_text(pos: Vector3, effect: String, value: int) -> void:
	if floating_text_scene:
		var ft = floating_text_scene.instantiate()
		add_child(ft)
		# Поднимаем текст немного над чашей весов
		ft.global_position = pos + Vector3(0, 0.5, 0)
		ft.setup(effect, value)

func update_ui() -> void:
	player_hp_label.text = "Здоровье Игрока: " + str(player_hp)
	ai_hp_label.text = "Здоровье ИИ: " + str(ai_hp)
	player_hp_bar.value = player_hp
	ai_hp_bar.value = ai_hp

	# Формируем строку иконок для Игрока
	var p_effects_text = ""
	if player_armor > 0:
		p_effects_text += "🛡️ " + str(player_armor) + "   "
	if player_poison > 0:
		p_effects_text += "☠️ " + str(player_poison) + "   "
	player_effects_label.text = p_effects_text

	# Формируем строку иконок для ИИ
	var ai_effects_text = ""
	if ai_armor > 0:
		ai_effects_text += "🛡️ " + str(ai_armor) + "   "
	if ai_poison > 0:
		ai_effects_text += "☠️ " + str(ai_poison) + "   "
	ai_effects_label.text = ai_effects_text

func check_win_condition() -> void:
	if player_hp <= 0:
		print("\nПобедил ИИ!")
	elif ai_hp <= 0:
		print("\nПобеда Игрока!")

func end_round() -> void:
	current_round += 1
	print("--- Раунд окончен! Нажмите 'Бросок' ---")
	
	# Снова разрешаем игроку нажать на кнопку
	roll_button.disabled = false 
	
	if camera:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(camera, "global_position", default_pos, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", default_rot, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

# --- УПРАВЛЕНИЕ И ФИЗИКА ВЕСОВ ---

func _input(event: InputEvent) -> void:
	# Свободная камера на ПКМ
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rmb_pressed = event.pressed
			if is_rmb_pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseMotion and is_rmb_pressed:
		if camera:
			camera.rotation.y -= event.relative.x * mouse_sensitivity
			camera.rotation.x -= event.relative.y * mouse_sensitivity
			# Ограничиваем угол, чтобы камера не переворачивалась
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(delta: float) -> void:
	# Физика покачивания весов в зависимости от разницы здоровья
	var hp_difference = player_hp - ai_hp
	var raw_angle = hp_difference * 4.0
	var clamped_angle = clamp(raw_angle, -11.0, 11.0)
	
	# scale_jolt добавляет резкий рывок при попадании снаряда, который плавно затухает
	scale_jolt = lerp(scale_jolt, 0.0, 10.0 * delta)
	
	var target_angle = deg_to_rad(clamped_angle + scale_jolt)
	
	# Применяем вращение к руке и компенсируем его для чаш, чтобы они всегда смотрели вверх
	scale_arm.rotation.x = lerp(scale_arm.rotation.x, target_angle, 6.0 * delta)
	left_weight.rotation.x = -scale_arm.rotation.x
	right_weight.rotation.x = -scale_arm.rotation.x
