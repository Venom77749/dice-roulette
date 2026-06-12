extends Node3D

var player_hp: int = 40
var ai_hp: int = 40
var is_player_turn: bool = true
var player_armor: int = 0
var ai_armor: int = 0
var player_poison: int = 0
var ai_poison: int = 0

enum DiceType { GOOD, BAD }

# Получаем доступ к UI
@onready var player_hp_label: Label = $CanvasLayer/PlayerHP
@onready var ai_hp_label: Label = $CanvasLayer/AIHP

@onready var player_hp_bar: ProgressBar = $CanvasLayer/PlayerHealthBar
@onready var ai_hp_bar: ProgressBar = $CanvasLayer/AIHealthBar

# --- ВЕСЫ ---
@onready var scale_arm: Node3D = $весы/Рука
@onready var left_weight: Node3D = $весы/Рука/LeftWeight
@onready var right_weight: Node3D = $весы/Рука/RightWeight

# --- МЕХАНИКА РАУНДОВ И КУБИКОВ ---
@export var dice_scene: PackedScene 
var current_round: int = 1

@export var floating_text_scene: PackedScene

@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Marker3D = $CameraTarget # Ссылка на нашу новую точку

# --- НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ЧАСТИЦ ---
@export var heal_particles_scene: PackedScene
@export var damage_particles_scene: PackedScene

@onready var player_effects_label: Label = $CanvasLayer/PlayerEffects
@onready var ai_effects_label: Label = $CanvasLayer/AIEffects

@onready var ai_animator: AnimationPlayer = $skeleton/AnimationPlayer

var default_pos: Vector3
var default_rot: Vector3

func _ready() -> void:
	print("--- Игра началась! ---")
	print("HP Игрока: ", player_hp, " | HP ИИ: ", ai_hp)
	
	# Запоминаем стартовую позицию и вращение
	if camera:
		default_pos = camera.global_position
		default_rot = camera.global_rotation
	
	update_ui()
	$CanvasLayer/Button.pressed.connect(_on_button_pressed)
	
func _on_button_pressed() -> void:
	if get_tree().get_nodes_in_group("dice").size() > 0:
		print("Сначала разберите оставшиеся кубики!")
		return
		
	# Возвращаем ход игроку, когда появляются новые кубики
	is_player_turn = true
		
	# --- ПЕРЕМЕЩАЕМ КАМЕРУ К МАРКЕРУ ---
	if camera and camera_target:
		var tween = create_tween()
		tween.set_parallel(true) # Двигаем и вращаем одновременно
		
		# Плавный полет к координатам таргета за 1 секунду
		tween.tween_property(camera, "global_position", camera_target.global_position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", camera_target.global_rotation, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
	print("\n=== РАУНД ", current_round, " ===")
	
	# --- ПРИМЕНЯЕМ ЯД В НАЧАЛЕ РАУНДА ---
	process_poison()
	
	# Если после применения яда кто-то умер, прерываем раздачу кубиков
	if player_hp <= 0 or ai_hp <= 0:
		return 
	
	var dice_count = current_round + randi_range(1, 2)
	print("На стол падает кубиков: ", dice_count)
	
	for i in range(dice_count):
		var new_dice = dice_scene.instantiate()
		add_child(new_dice)
		
		# Получаем точные координаты нашего маркера из 3D-сцены
		var spawn_pos = $SpawnPoint.global_position
		
		# Спавним кубики, добавляя небольшой разброс вокруг центра маркера
		new_dice.global_position = Vector3(spawn_pos.x + randf_range(-0.5, 0.5), spawn_pos.y + (i * 0.5), spawn_pos.z + randf_range(-0.5, 0.5))
		new_dice.global_rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
		
		new_dice.setup(current_round)
		new_dice.selected.connect(_on_dice_selected)
		
		# Добавляем кубик в группу вместо старого массива
		new_dice.add_to_group("dice")
		
		var impulse = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1))
		var torque = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		new_dice.apply_central_impulse(impulse)
		new_dice.apply_torque_impulse(torque)

# --- ЛОГИКА ХОДОВ ---

func _on_dice_selected(dice_node: Node3D, effect: String, value: int) -> void:
	# Если сейчас ход ИИ — полностью игнорируем клик игрока
	if not is_player_turn:
		return
		
	# Как только игрок сделал выбор, забираем у него право хода
	is_player_turn = false
	
	if dice_node.is_in_group("dice"):
		dice_node.remove_from_group("dice")
		
	# Вызываем спавнер текста над кубиком
	spawn_floating_text(dice_node.global_position, effect, value)
	spawn_particles(dice_node.global_position, effect)
		
	apply_effect(true, effect, value)
	
	# ТЕПЕРЬ КУБИК УНИЧТОЖАЕТСЯ ЗДЕСЬ
	dice_node.queue_free()
	
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
		
	# ИИ "думает" перед ходом
	var think_time = randf_range(1.0, 2.0)
	await get_tree().create_timer(think_time).timeout
	
	# Снова проверяем кубики после задержки
	dice_left = get_tree().get_nodes_in_group("dice")
	if dice_left.size() == 0:
		end_round()
		return
		
	# ИИ выбирает кубик
	var random_index = randi() % dice_left.size()
	var ai_dice = dice_left[random_index]
	ai_dice.remove_from_group("dice")
	
	# --- МАГИЯ АНИМАЦИИ НАЧИНАЕТСЯ ЗДЕСЬ ---
	if ai_animator:
		ai_animator.play("take") # Скелет начинает тянуться к столу
		
		# Ждем 0.8 секунд (момент, когда его рука опускается к кубику)
		# Если в твоей анимации он касается стола раньше/позже - поменяй эту цифру!
		await get_tree().create_timer(0.8).timeout
	
	# Вычисляем значение (рука коснулась стола, кубик срабатывает)
	var ai_real_value = 0
	if ai_dice.hidden_effect != "neutral":
		ai_real_value = ai_dice.get_top_number()
	
	spawn_floating_text(ai_dice.global_position, ai_dice.hidden_effect, ai_real_value)
	spawn_particles(ai_dice.global_position, ai_dice.hidden_effect)
	
	apply_effect(false, ai_dice.hidden_effect, ai_real_value)
	ai_dice.queue_free() # Кубик исчезает прямо из-под руки
	
	# Ждем, пока скелет выпрямится (доиграет анимацию `take`)
	if ai_animator:
		# Если общая длина твоей анимации take = 1.5 сек, 
		# а мы уже подождали 0.8 сек, значит осталось дождаться еще 0.7 сек:
		await get_tree().create_timer(0.7).timeout 
		ai_animator.play("idle") # Возвращаем скелета в расслабленную стойку
	
	# Проверяем, остались ли еще кубики
	if get_tree().get_nodes_in_group("dice").size() == 0:
		end_round()
	else:
		is_player_turn = true # Возвращаем ход игроку

func apply_effect(is_player: bool, effect: String, value: int) -> void:
	var target_name = "Игрок" if is_player else "ИИ"
	
	if effect == "neutral":
		print(target_name, " вытянул пустышку.")
		
	elif effect == "heal":
		if is_player:
			player_hp = min(player_hp + value, 20)
		else:
			ai_hp = min(ai_hp + value, 20)
		print(target_name, " лечится (выпало: +", value, ")")
		
	elif effect == "armor":
		if is_player:
			player_armor += value
		else:
			ai_armor += value
		print(target_name, " получает броню: +", value)
		
	elif effect == "poison":
		if is_player:
			player_poison += value # Яд может накапливаться!
		else:
			ai_poison += value
		print(target_name, " отравлен! Уровень яда: ", value)
		
	elif effect == "damage":
		var actual_damage = value
		
		# Логика поглощения урона для игрока
		if is_player:
			if player_armor > 0:
				var absorbed = min(player_armor, actual_damage)
				player_armor -= absorbed
				actual_damage -= absorbed
				print("🛡️ Броня Игрока поглотила ", absorbed, " урона. Осталось брони: ", player_armor)
			player_hp -= actual_damage
			
		# Логика поглощения урона для ИИ
		else:
			if ai_armor > 0:
				var absorbed = min(ai_armor, actual_damage)
				ai_armor -= absorbed
				actual_damage -= absorbed
				print("🛡️ Броня ИИ поглотила ", absorbed, " урона. Осталось брони: ", ai_armor)
			ai_hp -= actual_damage
			
		print(target_name, " получает урон: -", actual_damage, " HP")
		
	update_ui()
	check_win_condition()

func process_poison() -> void:
	if player_poison > 0:
		print("\nЯд действует на Игрока: -", player_poison, " HP")
		player_hp -= player_poison # Яд наносит прямой урон (игнорируя броню)
		player_poison -= 1
		
	if ai_poison > 0:
		print("\n☠️ Яд действует на ИИ: -", ai_poison, " HP")
		ai_hp -= ai_poison
		ai_poison -= 1
		
	update_ui()
	check_win_condition()

func spawn_particles(pos: Vector3, effect: String) -> void:
	# Меняем тип на точный, чтобы получить доступ к свойству emitting
	var particles: CPUParticles3D = null 
	
	if effect == "heal" and heal_particles_scene:
		particles = heal_particles_scene.instantiate()
	elif effect == "damage" and damage_particles_scene:
		particles = damage_particles_scene.instantiate()
		
	if particles:
		add_child(particles) 
		# Шаг 1: Перемещаем невидимый узел в координаты кубика
		particles.global_position = pos
		# Шаг 2: Только теперь даем команду на "Взрыв"!
		particles.emitting = true 
		
		get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)
func end_round() -> void:
	current_round += 1
	print("--- Раунд окончен! Нажмите 'Бросок' ---")
	
	# --- ВОЗВРАЩАЕМ КАМЕРУ ОБРАТНО ---
	if camera:
		var tween = create_tween()
		tween.set_parallel(true)
		
		tween.tween_property(camera, "global_position", default_pos, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", default_rot, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func update_ui() -> void:
	# Обновляем базовое здоровье
	player_hp_label.text = "Здоровье Игрока: " + str(player_hp)
	ai_hp_label.text = "Здоровье ИИ: " + str(ai_hp)
	player_hp_bar.value = player_hp
	ai_hp_bar.value = ai_hp

	# --- СОБИРАЕМ ЭФФЕКТЫ ИГРОКА ---
	var p_effects_text = ""
	
	if player_armor > 0:
		p_effects_text += "🛡️ " + str(player_armor) + "   "
	if player_poison > 0:
		p_effects_text += "☠️ " + str(player_poison) + "   "
		
	# Применяем собранную строку к тексту
	player_effects_label.text = p_effects_text

	# --- СОБИРАЕМ ЭФФЕКТЫ ИИ ---
	var ai_effects_text = ""
	
	if ai_armor > 0:
		ai_effects_text += "🛡️ " + str(ai_armor) + "   "
	if ai_poison > 0:
		ai_effects_text += "☠️ " + str(ai_poison) + "   "
		
	# Применяем собранную строку к тексту
	ai_effects_label.text = ai_effects_text

func _process(delta: float) -> void:
	var hp_difference = player_hp - ai_hp
	var raw_angle = hp_difference * 4.0
	var clamped_angle = clamp(raw_angle, -13.0, 13.0)
	var target_angle = deg_to_rad(clamped_angle)
	
	scale_arm.rotation.x = lerp(scale_arm.rotation.x, target_angle, 6.0 * delta)
	left_weight.rotation.x = -scale_arm.rotation.x
	right_weight.rotation.x = -scale_arm.rotation.x

func spawn_floating_text(pos: Vector3, effect: String, value: int) -> void:
	if floating_text_scene:
		# Создаем копию сцены
		var ft = floating_text_scene.instantiate()
		
		# Добавляем ее в игровой мир
		add_child(ft)
		
		# Ставим текст в координаты кубика, но на 0.5 метра выше
		ft.global_position = pos + Vector3(0, 0.5, 0)
		
		# Запускаем нашу анимацию из скрипта floating_text.gd
		ft.setup(effect, value)

func check_win_condition() -> void:
	if player_hp <= 0:
		print("\nПобедил ИИ!")
	elif ai_hp <= 0:
		print("\nПобеда Игрока!")
