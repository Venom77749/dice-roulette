extends Node3D

# --- ИГРОВОЙ БАЛАНС И СТАТИСТИКА ---
@export var max_hp: int = 20
var player_hp: int = max_hp
var ai_hp: int = max_hp
var is_player_turn: bool = true
var current_round: int = 1

# Статусные эффекты
var player_armor: int = 0
var ai_armor: int = 0
var player_poison: int = 0
var ai_poison: int = 0
# Память для магнита
var ai_last_buff_effect: String = ""
var ai_last_buff_value: int = 0
var ai_actual_gained_hp: int = 0

# Поворот камеры
var center_rot_y: float = 0.0
var is_at_shop: bool = false

enum DiceType { GOOD, BAD }

# --- ИНТЕРФЕЙС (UI) ---
@onready var player_hp_label: Label = $CanvasLayer/PlayerHP
@onready var ai_hp_label: Label = $CanvasLayer/AIHP
@onready var player_hp_bar: ProgressBar = $CanvasLayer/PlayerHealthBar
@onready var ai_hp_bar: ProgressBar = $CanvasLayer/AIHealthBar
@onready var player_effects_label: Label = $CanvasLayer/PlayerEffects
@onready var ai_effects_label: Label = $CanvasLayer/AIEffects
@onready var roll_button: Button = $CanvasLayer/throw
@onready var shop_button: Button = $CanvasLayer/ShopButton
@onready var back_button: Button = $CanvasLayer/BackButton

# --- ОБЪЕКТЫ НА СЦЕНЕ ---
@onready var scale_arm: Node3D = $весы/Рука
@onready var left_weight: Node3D = $весы/Рука/LeftWeight
@onready var right_weight: Node3D = $весы/Рука/RightWeight
@onready var ai_animator: AnimationPlayer = $skeleton/AnimationPlayer
@onready var spawn_point: Marker3D = $SpawnPoint

# --- КАМЕРА ---
@onready var camera: Camera3D = $Camera3D
@onready var camera_target: Marker3D = $CameraTarget
@onready var shop_camera_target: Marker3D = $ShopCameraTarget

var default_pos: Vector3
var default_rot: Vector3
var mouse_sensitivity: float = 0.003
var is_rmb_pressed: bool = false

# --- ЗАГРУЖАЕМЫЕ СЦЕНЫ (ПРЕФАБЫ) ---
@export var dice_scene: PackedScene 
@export var floating_text_scene: PackedScene
@export var heal_particles_scene: PackedScene
@export var damage_particles_scene: PackedScene
@export var shop_magnet_scene: PackedScene 

@export var soul_heal: PackedScene
@export var soul_damage: PackedScene
@export var soul_poison: PackedScene
@export var soul_armor: PackedScene

@onready var shop_slots = [
	$shop/ItemSpawns/Slot_1,
	$shop/ItemSpawns/Slot_2,
	$shop/ItemSpawns/Slot_3,
	$shop/ItemSpawns/Slot_4
]

@onready var player_slots = [
	$Table/Player_ItemSpawns/P_Slot,
	$Table/Player_ItemSpawns/P_Slot2,
	$Table/Player_ItemSpawns/P_Slot3,
	$Table/Player_ItemSpawns/P_Slot4
]

@onready var tooltip: PanelContainer = $CanvasLayer/ItemTooltip
@onready var tooltip_label: Label = $CanvasLayer/ItemTooltip/Label

var item_database = {
	"magnet": {"name": "Магнит", "desc": "Притягивает последний эффект протифника на ваш выбор.", "price": 1},
	"antidote": {"name": "Противоядие", "desc": "Очищает кровь от яда.", "price": 1},
	"hammer": {"name": "Молоток", "desc": "Уничтожает любой кубик.", "price": 1},
	"eye": {"name": "Глаз Истины", "desc": "Раскрывает эффект кубика.", "price": 2}
}

# --- НАСТРОЙКИ UI ДЕНЕГ И МЕШКА ---
# Теперь мы назначаем их через Инспектор, чтобы ничего не терялось!
@export var coin_3d_scene: PackedScene
@export var ui_viewport: SubViewport
@export var ui_bag: Node3D
@export var coin_spawn_point: Marker3D
@export var coin_drop_point: Marker3D
@onready var money_ui: Control = $CanvasLayer/MoneyUI
@onready var money_label: Label = $CanvasLayer/MoneyUI/MoneyLabel
@onready var money_coin_node: Node3D = $CanvasLayer/MoneyUI/SubViewportContainer/SubViewport/coin
@export var table_magnet_scene: PackedScene

var scale_jolt: float = 0.0

@export var shop_antidote_scene: PackedScene 
@export var table_antidote_scene: PackedScene

@export var shop_hammer_scene: PackedScene 
@export var table_hammer_scene: PackedScene

@export var shop_eye_scene: PackedScene 
@export var table_eye_scene: PackedScene

var is_waiting_for_hammer_target: bool = false # Ждём ли мы выбора кубика для молотка
var is_waiting_for_eye_target: bool = false

func _ready() -> void:
	print("--- Игра началась! ---")
	print("HP Игрока: ", player_hp, " | HP ИИ: ", ai_hp)
	
	if camera:
		default_pos = camera.global_position
		default_rot = camera.global_rotation
		center_rot_y = default_rot.y
		
	if ui_bag:
		ui_bag.scale = Vector3.ZERO
	if money_ui:
		money_ui.modulate.a = 0.0
		
	update_ui()
	roll_button.pressed.connect(_on_button_pressed)
	generate_shop()
	shop_button.hide()
	shop_button.pressed.connect(_on_shop_button_pressed)
	
	if back_button:
		back_button.hide()
		back_button.pressed.connect(_on_back_button_pressed)
	
func _on_button_pressed() -> void:
	is_at_shop = false
	if get_tree().get_nodes_in_group("dice").size() > 0:
		print("Сначала разберите оставшиеся кубики!")
		return
		
	if ui_bag and ui_bag.scale != Vector3.ZERO:
		var hide_tween = create_tween()
		hide_tween.tween_property(ui_bag, "scale", Vector3.ZERO, 0.3)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		
	# Прячем счетчик в начале раунда
	if money_ui and money_ui.modulate.a > 0.0:
		var hide_ui_tween = create_tween()
		hide_ui_tween.tween_property(money_ui, "modulate:a", 0.0, 0.3)
			
	roll_button.disabled = true
	is_player_turn = true
		
	if camera and camera_target:
		center_rot_y = camera_target.global_rotation.y 
		var tween = create_tween()
		tween.tween_property(camera, "global_transform", camera_target.global_transform, 1.0)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
	print("\n=== РАУНД ", current_round, " ===")
	
	process_poison()
	if player_hp <= 0 or ai_hp <= 0:
		return 
	
	var dice_count = current_round + randi_range(1, 2)
	print("На стол падает кубиков: ", dice_count)
	
	for i in range(dice_count):
		var new_dice = dice_scene.instantiate()
		add_child(new_dice)
		
		var base_pos = spawn_point.global_position
		new_dice.global_position = Vector3(base_pos.x + randf_range(-0.5, 0.5), base_pos.y + (i * 0.5), base_pos.z + randf_range(-0.5, 0.5))
		new_dice.global_rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
		
		new_dice.setup(current_round)
		new_dice.selected.connect(_on_dice_selected)
		new_dice.add_to_group("dice")
		
		var impulse = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1))
		var torque = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
		new_dice.apply_central_impulse(impulse)
		new_dice.apply_torque_impulse(torque)
		
func _on_dice_selected(dice_node: Node3D, effect: String, value: int) -> void:
	if not is_player_turn:
		return
		
# --- ПРОВЕРКА МОЛОТКА ---
	if is_waiting_for_hammer_target:
		print("Кубик уничтожен молотком!")
		is_waiting_for_hammer_target = false
		
		# Прячем подсказку
		if tooltip: tooltip.hide()
		
		# Выключаем подсветку молотка
		for die in get_tree().get_nodes_in_group("dice"):
			if die.has_method("set_hammer_highlight"):
				die.set_hammer_highlight(false)
				
		# Удаляем из группы СРАЗУ (для честной проверки в конце раунда)
		dice_node.remove_from_group("dice")
		
		# === ЗАМЕНЯЕМ rough queue_free() НА КРАСИВУЮ АНИМАЦИЮ ===
		play_item_selection_animation(dice_node)
		# ========================================================
		
		# Проверяем, остались ли еще кубики
		var dice_left = get_tree().get_nodes_in_group("dice")
		if dice_left.size() == 0:
			print("🔨 Последний кубик сломан! Завершаем раунд.")
			end_round()
			
		return		
		
# --- ПРОВЕРКА ГЛАЗА ---
	if is_waiting_for_eye_target:
		# Для удобства давай выводить в консоль и эффект, и цифру
		print("👁️ Истинное зрение! Эффект: ", effect, ", Значение: ", value)
		is_waiting_for_eye_target = false
		
		# Выключаем голубую подсветку
		for die in get_tree().get_nodes_in_group("dice"):
			if die.has_method("set_eye_highlight"):
				die.set_eye_highlight(false)
				
		# ТЕПЕРЬ ПЕРЕДАЕМ НАСТОЯЩЕЕ ЗНАЧЕНИЕ (value вместо 0)
		spawn_floating_text(dice_node.global_position, effect, value)
		
		# Важно: прерываем функцию, чтобы игрок мог сделать свой настоящий ход
		return
		
# --- ОБЫЧНЫЙ ХОД ---
	is_player_turn = false
	
	if dice_node.is_in_group("dice"):
		dice_node.remove_from_group("dice")
		
	var start_pos = dice_node.global_position
	dice_node.queue_free()
	
	await shoot_soul_to_scales(start_pos, true, effect, value)
	
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
		
	var think_time = randf_range(1.0, 2.0)
	await get_tree().create_timer(think_time).timeout
	
	dice_left = get_tree().get_nodes_in_group("dice")
	if dice_left.size() == 0:
		end_round()
		return
		
	var random_index = randi() % dice_left.size()
	var ai_dice = dice_left[random_index]
	ai_dice.remove_from_group("dice")
	
	if ai_animator:
		ai_animator.play("take")
		await get_tree().create_timer(0.35).timeout
	
	var ai_real_value = 0
	if ai_dice.hidden_effect != "neutral":
		ai_real_value = ai_dice.get_top_number()
	
	var start_pos = ai_dice.global_position
	var effect_type = ai_dice.hidden_effect
	ai_dice.queue_free() 
	
	await shoot_soul_to_scales(start_pos, false, effect_type, ai_real_value)
	
	if ai_animator:
		ai_animator.play("idle")
	
	if get_tree().get_nodes_in_group("dice").size() == 0:
		end_round()
	else:
		is_player_turn = true

func shoot_soul_to_scales(start_pos: Vector3, is_player: bool, effect: String, value: int) -> void:
	var duration: float = 0.65 
	
	if effect == "neutral":
		spawn_floating_text(start_pos, effect, 0)
		await get_tree().create_timer(duration).timeout
		return
		
	var proj_scene: PackedScene = null
	match effect:
		"heal": proj_scene = soul_heal
		"damage": proj_scene = soul_damage
		"poison": proj_scene = soul_poison
		"armor": proj_scene = soul_armor
		
	if not proj_scene: 
		return
	
	var soul = proj_scene.instantiate()
	var target_node = left_weight if is_player else right_weight
	var end_pos = target_node.global_position
	
	soul.position = start_pos
	soul.look_at_from_position(start_pos, end_pos, Vector3.UP)
	add_child(soul)
	
	await get_tree().process_frame
	
	var tween = create_tween()
	tween.tween_property(soul, "global_position", end_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(duration).timeout
	
	if is_instance_valid(soul):
		var emitters = soul.get_node_or_null("Emitters")
		if emitters:
			for child in emitters.get_children():
				child.emitting = false
				
		var impact = soul.get_node_or_null("Impact")
		if impact:
			for child in impact.get_children():
				if child.has_method("restart"):
					child.restart() 
				child.emitting = true
				
		get_tree().create_timer(1.5).timeout.connect(soul.queue_free)
	
	spawn_floating_text(end_pos, effect, value)
	scale_jolt = -15.0 if is_player else 15.0 
	apply_effect(is_player, effect, value)

func apply_effect(is_player: bool, effect: String, value: int) -> void:
	var target_name = "Игрок" if is_player else "ИИ"
	var actual_gained = 0 # Считаем, сколько реально получил ИИ
	
	if effect == "neutral":
		print(target_name, " вытянул пустышку.")
	elif effect == "heal":
		if is_player: 
			player_hp = min(player_hp + value, max_hp)
		else: 
			var hp_before = ai_hp
			ai_hp = min(ai_hp + value, max_hp)
			actual_gained = ai_hp - hp_before # Запоминаем разницу до и после хила!
		print(target_name, " лечится (выпало: +", value, ")")
	elif effect == "armor":
		if is_player: player_armor += value
		else: 
			ai_armor += value
			actual_gained = value # Броня не имеет лимита, берем полное значение
		print(target_name, " получает броню: +", value)
	elif effect == "poison":
		if is_player: player_poison += value 
		else: ai_poison += value
		print(target_name, " отравлен! Уровень яда: ", value)
	elif effect == "damage":
		var actual_damage = value
		if is_player:
			if player_armor > 0:
				var absorbed = min(player_armor, actual_damage)
				player_armor -= absorbed
				actual_damage -= absorbed
			player_hp -= actual_damage
		else:
			if ai_armor > 0:
				var absorbed = min(ai_armor, actual_damage)
				ai_armor -= absorbed
				actual_damage -= absorbed
			ai_hp -= actual_damage
			
	# --- ОБНОВЛЕННЫЙ КОД ДЛЯ ПАМЯТИ МАГНИТА ---
	if not is_player:
		if effect == "heal" or effect == "armor":
			ai_last_buff_effect = effect
			ai_last_buff_value = value
			ai_actual_gained_hp = actual_gained # Запоминаем реальный профит ИИ
		else:
			ai_last_buff_effect = ""
			ai_last_buff_value = 0
			ai_actual_gained_hp = 0
	# ----------------------------------------
		
	update_ui()
	check_win_condition()

func process_poison() -> void:
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
		get_tree().create_timer(particles.lifetime).timeout.connect(particles.queue_free)

func spawn_floating_text(pos: Vector3, effect: String, value: int) -> void:
	if floating_text_scene:
		var ft = floating_text_scene.instantiate()
		add_child(ft)
		ft.global_position = pos + Vector3(0, 0.5, 0)
		ft.setup(effect, value)

func update_ui() -> void:
	player_hp_label.text = "Здоровье Игрока: " + str(player_hp)
	ai_hp_label.text = "Здоровье ИИ: " + str(ai_hp)
	player_hp_bar.value = player_hp
	ai_hp_bar.value = ai_hp

	var p_effects_text = ""
	if player_armor > 0:
		p_effects_text += "🛡️ " + str(player_armor) + "   "
	if player_poison > 0:
		p_effects_text += "☠️ " + str(player_poison) + "   "
	player_effects_label.text = p_effects_text

	var ai_effects_text = ""
	if ai_armor > 0:
		ai_effects_text += "🛡️ " + str(ai_armor) + "   "
	if ai_poison > 0:
		ai_effects_text += "☠️ " + str(ai_poison) + "   "
	ai_effects_label.text = ai_effects_text

	# Обновляем текст счетчика монет!
	if money_label:
		money_label.text = "x " + str(Global.money)

# Универсальная анимация убирания предмета со стола (эффект "схлопывания")
func play_item_selection_animation(item_node: Node3D) -> void:
	# 1. Защита от вылетов: проверяем, существует ли еще объект
	if not is_instance_valid(item_node):
		return
		
	# 2. Создаем Tween для плавных анимаций
	var tween = create_tween()
	
	# Шаг 1: Быстрое увеличение (эффект "пульса перед сжатием")
	# TRANS_BACK добавляет сочности (эффект отпружинивания)
	tween.tween_property(item_node, "scale", Vector3(1.3, 1.3, 1.3), 0.1) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
		
	# Шаг 2: Вращение (запускается ПАРАЛЛЕЛЬНО с увеличением и длится 0.3 секунды)
	# Объект сделает два полных оборота (720 градусов)
	tween.parallel().tween_property(item_node, "rotation_degrees:y", item_node.rotation_degrees.y + 720.0, 0.3) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN_OUT)
		
	# Шаг 3: Сжатие в ноль 
	# Вызывается без parallel(), поэтому начнется строго ПОСЛЕ того, как закончится первый шаг (увеличение)
	tween.tween_property(item_node, "scale", Vector3.ZERO, 0.2) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
		
	# Шаг 4: Безопасное удаление объекта из памяти
	# Сработает только тогда, когда завершатся абсолютно все анимации Твина
	tween.finished.connect(func():
		if is_instance_valid(item_node): # Еще одна проверка на всякий случай
			item_node.queue_free()
	)

func check_win_condition() -> void:
	if player_hp <= 0:
		print("\nПобедил ИИ!")
	elif ai_hp <= 0:
		print("\nПобеда Игрока!")

func end_round() -> void:
	current_round += 1
	print("--- Раунд окончен! Нажмите 'Бросок' ---")
	
	roll_button.disabled = false 
	shop_button.show()
	
	drop_coins_into_ui_bag()
	play_money_ui_animation()
	
	if camera:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(camera, "global_position", default_pos, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", default_rot, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func _input(event: InputEvent) -> void:
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
				camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))
				if is_at_shop:
					var limit_y = deg_to_rad(25)
					camera.rotation.y = clamp(camera.rotation.y, center_rot_y - limit_y, center_rot_y + limit_y)
				
func _process(delta: float) -> void:
	var hp_difference = player_hp - ai_hp
	var raw_angle = hp_difference * 4.0
	var clamped_angle = clamp(raw_angle, -11.0, 11.0)
	scale_jolt = lerp(scale_jolt, 0.0, 10.0 * delta)
	var target_angle = deg_to_rad(clamped_angle + scale_jolt)
	scale_arm.rotation.x = lerp(scale_arm.rotation.x, target_angle, 6.0 * delta)
	left_weight.rotation.x = -scale_arm.rotation.x
	right_weight.rotation.x = -scale_arm.rotation.x
	
	if tooltip and tooltip.visible:
		tooltip.global_position = get_viewport().get_mouse_position() + Vector2(15, 15)

func generate_shop() -> void:
	for slot in shop_slots:
		for child in slot.get_children():
			child.queue_free()
			
		var chance = randf()
		var new_item: Node3D = null
		
		# Распределяем шансы (по 0.2 на каждый предмет)
		if chance <= 0.20 and shop_magnet_scene:
			new_item = shop_magnet_scene.instantiate()
		elif chance > 0.20 and chance <= 0.40 and shop_antidote_scene:
			new_item = shop_antidote_scene.instantiate()
		elif chance > 0.40 and chance <= 0.60 and shop_hammer_scene:
			new_item = shop_hammer_scene.instantiate()
		elif chance > 0.60 and chance <= 0.80 and shop_eye_scene: # ДОБАВЛЕНО ДЛЯ ГЛАЗА
			new_item = shop_eye_scene.instantiate()
			
		# Если предмет выпал — ставим его на полку
# Если предмет заспавнился, ставим его на полку и слушаем клик/наведение
		if new_item:
			slot.add_child(new_item)
			new_item.position = Vector3.ZERO
			if new_item.has_signal("clicked"):
				new_item.clicked.connect(_on_shop_item_clicked.bind(new_item))
			if new_item.has_signal("hovered"):
				new_item.hovered.connect(_on_item_hovered) # ДОБАВИТЬ ЭТУ СТРОЧКУ
				
func use_magnet(magnet_node: Node3D) -> void:
	if ai_last_buff_effect == "":
		print("У ИИ нет свежих баффов для кражи! Магнит не сработал.")
		return
		
	var stolen_effect = ai_last_buff_effect
	var stolen_value = ai_last_buff_value
	var ai_loss = ai_actual_gained_hp 
	
	print("Игрок ВОРУЕТ у ИИ: ", stolen_effect, " на ", stolen_value)
	
	if stolen_effect == "heal":
		ai_hp -= ai_loss
	elif stolen_effect == "armor":
		ai_armor = max(0, ai_armor - ai_loss)
		
	if stolen_effect == "heal":
		player_hp = min(player_hp + stolen_value, max_hp)
	elif stolen_effect == "armor":
		player_armor += stolen_value
		
	ai_last_buff_effect = ""
	ai_last_buff_value = 0
	ai_actual_gained_hp = 0
	
	update_ui()
	steal_soul_animation(stolen_effect, stolen_value)
	
	if tooltip:
		tooltip.hide()
		
	# Запускаем красивую анимацию исчезновения (она сама удалит предмет)
	play_item_selection_animation(magnet_node)


func steal_soul_animation(effect: String, value: int) -> void:
	var proj_scene: PackedScene = null
	match effect:
		"heal": proj_scene = soul_heal
		"armor": proj_scene = soul_armor
		
	if not proj_scene: 
		return
	
	# Создаем снаряд
	var soul = proj_scene.instantiate()
	
	# Летим ОТ чаши ИИ К чаше Игрока
	var start_pos = right_weight.global_position + Vector3(0, 0.5, 0)
	var end_pos = left_weight.global_position
	
	soul.position = start_pos
	soul.look_at_from_position(start_pos, end_pos, Vector3.UP)
	add_child(soul)
	
	await get_tree().process_frame
	
	var tween = create_tween()
	tween.tween_property(soul, "global_position", end_pos, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await get_tree().create_timer(0.65).timeout
	
	# Взрыв на нашей чаше
	if is_instance_valid(soul):
		var emitters = soul.get_node_or_null("Emitters")
		if emitters:
			for child in emitters.get_children(): child.emitting = false
				
		var impact = soul.get_node_or_null("Impact")
		if impact:
			for child in impact.get_children():
				if child.has_method("restart"): child.restart() 
				child.emitting = true
				
		get_tree().create_timer(1.5).timeout.connect(soul.queue_free)
	
	# Рисуем цифру, которую мы украли, и дергаем НАШИ весы
	spawn_floating_text(end_pos, effect, value)
	scale_jolt = -15.0

func _on_shop_button_pressed() -> void:
	is_at_shop = true
	shop_button.hide()
	roll_button.hide() # Прячем кнопку Броска
	if back_button:
		back_button.show() # Показываем кнопку Назад
		
	generate_shop()
	print("Добро пожаловать в магазин!")
	
	if camera and shop_camera_target:
		center_rot_y = shop_camera_target.global_rotation.y
		var tween = create_tween()
		tween.tween_property(camera, "global_transform", shop_camera_target.global_transform, 1.2)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_back_button_pressed() -> void:
	is_at_shop = false
	if back_button:
		back_button.hide() # Прячем кнопку Назад
	
	shop_button.show() # Снова показываем кнопку магазина
	roll_button.show() # Возвращаем кнопку Броска
	
	print("Возвращаемся к столу.")
	
	# Анимируем камеру обратно за стол
	if camera:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(camera, "global_position", default_pos, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(camera, "global_rotation", default_rot, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		
		# Как только анимация закончится, возвращаем центральную ось поворота мыши
		tween.finished.connect(func(): center_rot_y = default_rot.y)

func drop_coins_into_ui_bag() -> void:
	if not ui_viewport or not ui_bag or not coin_3d_scene:
		print("ВНИМАНИЕ: Не назначены элементы мешка в инспекторе!")
		return

	var bag_target_scale = Vector3(1.0, 1.0, 1.0) 
	var bag_tween = create_tween()
	bag_tween.tween_property(ui_bag, "scale", bag_target_scale, 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Показываем счетчик в конце раунда
	if money_ui:
		var ui_tween = create_tween()
		ui_tween.tween_property(money_ui, "modulate:a", 1.0, 0.4)
	
	var amount = randi_range(3, 5)

	for i in range(amount):
		var coin = coin_3d_scene.instantiate()
		ui_viewport.add_child(coin)

		var final_scale = Vector3(0.4, 0.4, 0.4)
		coin.scale = Vector3.ZERO 
		
		var end_pos = coin_drop_point.position 
		var start_pos = coin_spawn_point.position 
		
		coin.position = start_pos
		coin.rotation.y = randf_range(0, PI)

		var tween = create_tween()
		var delay = 0.4 + (i * 0.2) 
		
		tween.tween_property(coin, "scale", final_scale, 0.2)\
			.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		tween.parallel().tween_property(coin, "position", end_pos, 0.45)\
			.set_delay(delay + 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
			
		var target_rot_y = coin.rotation.y + deg_to_rad(1080)
		tween.parallel().tween_property(coin, "rotation:y", target_rot_y, 0.45)\
			.set_delay(delay + 0.1)
			
		tween.tween_callback(func():
			coin.queue_free()
			Global.money += 1
			update_ui()
		).set_delay(delay + 0.55)

func play_money_ui_animation() -> void:
	if not money_coin_node:
		print("ВНИМАНИЕ: Не назначена монетка счетчика в инспекторе!")
		return
		
	var tween = create_tween()
	money_coin_node.rotation_degrees.y = 0 # Сброс перед вращением, чтобы не перекрутилась
	tween.tween_property(money_coin_node, "rotation_degrees:y", 360, 0.5)\
		 .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func use_antidote(bottle_node: Node3D) -> void:
	if player_poison <= 0:
		print("В крови нет яда! Ты выпиваешь горькую жижу впустую.")
	else:
		print("Игрок выпивает противоядие! Яд нейтрализован.")
		player_poison = 0
		player_hp = min(player_hp + 1, max_hp) 
		spawn_particles(left_weight.global_position, "heal")
	
	update_ui()
	
	if tooltip:
		tooltip.hide()
		
	# Запускаем красивую анимацию исчезновения
	play_item_selection_animation(bottle_node)

func use_hammer(hammer_node: Node3D) -> void:
	if not is_player_turn:
		print("Сейчас ход ИИ! Молоток не работает.")
		return
		
	if get_tree().get_nodes_in_group("dice").size() == 0:
		print("На столе нет кубиков, чтобы их ломать!")
		play_item_selection_animation(hammer_node)
		return

	print("МОЛОТОК АКТИВЕН! Выберите кубик на столе для уничтожения.")
	is_waiting_for_hammer_target = true
	
	for die in get_tree().get_nodes_in_group("dice"):
		if die.has_method("set_hammer_highlight"):
			die.set_hammer_highlight(true)
			
	if tooltip:
		tooltip.hide()
		
	# Запускаем красивую анимацию исчезновения
	play_item_selection_animation(hammer_node)

func use_eye(eye_node: Node3D) -> void:
	if not is_player_turn:
		print("Сейчас ход ИИ! Глаз использовать нельзя.")
		return
		
	if get_tree().get_nodes_in_group("dice").size() == 0:
		print("На столе нет кубиков!")
		play_item_selection_animation(eye_node)
		return

	print("ГЛАЗ АКТИВЕН! Выберите кубик, чтобы узнать его секрет.")
	is_waiting_for_eye_target = true
	
	for die in get_tree().get_nodes_in_group("dice"):
		if die.has_method("set_eye_highlight"):
			die.set_eye_highlight(true)
			
	if tooltip:
		tooltip.hide()
		
	# Запускаем красивую анимацию исчезновения
	play_item_selection_animation(eye_node)

func _on_shop_item_clicked(item_node: Node3D) -> void:
	var free_slot: Node3D = null
	for slot in player_slots:
		if slot.get_child_count() == 0:
			free_slot = slot
			break
			
	if free_slot == null:
		print("📦 Нет места на столе!")
		return
		
	# --- НОВАЯ УМНАЯ ПОКУПКА ---
	var id = item_node.get("item_id")
	
	# Проверяем, есть ли предмет в базе данных
	if item_database.has(id):
		var item_cost = item_database[id]["price"]
		
		if Global.money >= item_cost:
			Global.money -= item_cost
			update_ui()
			print("🛒 Куплен предмет: ", id)
			
			item_node.queue_free() # Удаляем с витрины
			
			if tooltip:
				tooltip.hide()
			
			var real_item: Node3D = null
			
			# Спавним нужный предмет на стол
			if id == "magnet" and table_magnet_scene:
				real_item = table_magnet_scene.instantiate()
				free_slot.add_child(real_item)
				real_item.clicked.connect(use_magnet.bind(real_item))
			elif id == "antidote" and table_antidote_scene:
				real_item = table_antidote_scene.instantiate()
				free_slot.add_child(real_item)
				real_item.clicked.connect(use_antidote.bind(real_item))
			elif id == "hammer" and table_hammer_scene:
				real_item = table_hammer_scene.instantiate()
				free_slot.add_child(real_item)
				real_item.clicked.connect(use_hammer.bind(real_item))
			elif id == "eye" and table_eye_scene:
				real_item = table_eye_scene.instantiate()
				free_slot.add_child(real_item)
				real_item.clicked.connect(use_eye.bind(real_item))
				
			if real_item and real_item.has_signal("hovered"):
				real_item.hovered.connect(_on_item_hovered)
				
			# Анимация падения на стол
			if real_item:
				real_item.position = Vector3(0, 2, 0)
				var tween = create_tween()
				tween.tween_property(real_item, "position", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		else:
			print("❌ Не хватает денег!")

func _on_item_hovered(id: String, is_hovering: bool) -> void:
	if is_hovering and item_database.has(id):
		var info = item_database[id]
		# Собираем красивый текст: Название (Цена монет) \n Описание
		tooltip_label.text = info["name"] + " (" + str(info["price"]) + " монет)\n" + info["desc"]
		tooltip.show()
	else:
		tooltip.hide()
