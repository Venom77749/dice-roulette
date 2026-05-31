extends Node3D

var player_hp: int = 20
var ai_hp: int = 20

enum DiceType { GOOD, BAD }

# @onready позволяет получить ссылку на узел RigidBody3D, когда сцена загрузится
@onready var dice_rigid_body: RigidBody3D = $PhysicsDice

func _ready() -> void:
	print("--- Игра началась! ---")
	print("HP Игрока: ", player_hp, " | HP ИИ: ", ai_hp)

# Подключаем сигнал нажатия кнопки напрямую кодом
	$CanvasLayer/Button.pressed.connect(_on_button_pressed)
	
func _on_button_pressed() -> void:
	print("\nИгрок бросает кубик...")
	
	
	# 1. Возвращаем кубик в исходную точку над столом, если он улетел
	dice_rigid_body.global_position = Vector3(0, 2, 0)
	# Сбрасываем старую скорость движения и вращения
	dice_rigid_body.linear_velocity = Vector3.ZERO
	dice_rigid_body.angular_velocity = Vector3.ZERO
	
	# 2. Задаем случайный импульс вверх и немного вбок
	var impulse = Vector3(randf_range(-0.1, 0.1), randf_range(1, 1.5), randf_range(-0.5, 0.5))
	# Задаем случайное закручивание (чтобы он вращался в воздухе)
	var torque = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
	
	# Применяем силы к физическому телу
	dice_rigid_body.apply_central_impulse(impulse)
	dice_rigid_body.apply_torque_impulse(torque)
	
	# Вызываем нашу логику расчета (пока мгновенную)
	roll_dice(true)

func roll_dice(is_player: bool) -> void:
	var value: int = randi_range(1, 6)
	var hidden_type: DiceType = DiceType.GOOD if randf() > 0.5 else DiceType.BAD
	apply_effect(is_player, value, hidden_type)

func apply_effect(is_player: bool, value: int, type: DiceType) -> void:
	var target_name: String = "Игрок" if is_player else "ИИ"
	var effect_text: String = ""
	
	if type == DiceType.GOOD:
		if is_player: player_hp += value
		else: ai_hp += value
		effect_text = "Лечение (+%d HP)" % value
	else:
		if is_player: player_hp -= value
		else: ai_hp -= value
		effect_text = "Урон (-%d HP)" % value
		
	print("%s вытянул: %d. Эффект: %s" % [target_name, value, effect_text])
	print("Текущие HP -> Игрок: %d | ИИ: %d" % [player_hp, ai_hp])
	check_win_condition()

func check_win_condition() -> void:
	if player_hp <= 0:
		print("\nПобедил ИИ!")
	elif ai_hp <= 0:
		print("\nПобеда Игрока!")
