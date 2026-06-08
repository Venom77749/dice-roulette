extends Node3D

var player_hp: int = 20
var ai_hp: int = 20

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

func _ready() -> void:
	print("--- Игра началась! ---")
	print("HP Игрока: ", player_hp, " | HP ИИ: ", ai_hp)
	
	update_ui()
	$CanvasLayer/Button.pressed.connect(_on_button_pressed)
	
func _on_button_pressed() -> void:
	# Проверяем количество живых кубиков в группе "dice"
	if get_tree().get_nodes_in_group("dice").size() > 0:
		print("Сначала разберите оставшиеся кубики!")
		return
		
	print("\n=== РАУНД ", current_round, " ===")
	
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
	# Ход игрока: мгновенно исключаем кубик из группы
	if dice_node.is_in_group("dice"):
		dice_node.remove_from_group("dice")
		
	apply_effect(true, effect, value)
	
	# Смотрим, осталось ли что-то на столе для хода ИИ
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
		
	# ИИ выбирает случайный кубик из тех, что реально остались в группе
	var random_index = randi() % dice_left.size()
	var ai_dice = dice_left[random_index]
	
	# Исключаем его из группы, применяем эффект и удаляем со сцены
	ai_dice.remove_from_group("dice")
	apply_effect(false, ai_dice.hidden_effect, ai_dice.effect_value)
	ai_dice.queue_free()
	
	# Если ИИ забрал самый последний кубик — завершаем раунд
	if get_tree().get_nodes_in_group("dice").size() == 0:
		end_round()

func apply_effect(is_player: bool, effect: String, value: int) -> void:
	var target_name = "Игрок" if is_player else "ИИ"
	
	if effect == "neutral":
		print(target_name, " вытянул пустышку.")
	elif effect == "heal":
		if is_player:
			player_hp += value
		else:
			ai_hp += value
		print(target_name, " лечится: +", value, " HP")
	elif effect == "damage":
		if is_player:
			player_hp -= value
		else:
			ai_hp -= value
		print(target_name, " получает урон: -", value, " HP")
		
	update_ui()
	check_win_condition()

func end_round() -> void:
	current_round += 1
	print("--- Раунд окончен! Нажмите 'Бросок' ---")

func update_ui() -> void:
	player_hp_label.text = "Здоровье Игрока: " + str(player_hp)
	ai_hp_label.text = "Здоровье ИИ: " + str(ai_hp)
	player_hp_bar.value = player_hp
	ai_hp_bar.value = ai_hp

func _process(delta: float) -> void:
	var hp_difference = player_hp - ai_hp
	var raw_angle = hp_difference * 4.0
	var clamped_angle = clamp(raw_angle, -15.0, 15.0)
	var target_angle = deg_to_rad(clamped_angle)
	
	scale_arm.rotation.x = lerp(scale_arm.rotation.x, target_angle, 6.0 * delta)
	left_weight.rotation.x = -scale_arm.rotation.x
	right_weight.rotation.x = -scale_arm.rotation.x

func check_win_condition() -> void:
	if player_hp <= 0:
		print("\nПобедил ИИ!")
	elif ai_hp <= 0:
		print("\nПобеда Игрока!")
