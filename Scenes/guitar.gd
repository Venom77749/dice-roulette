extends AudioStreamPlayer

func _ready():
	_on_timer_timeout()

func _on_timer_timeout() -> void:
	# 1. Играем первую ноту (оригинальный звук)
	pitch_scale = 1.0
	volume_db = randf_range(-5.0, -2.0) 
	play()
	
	# 2. Ждем 1.5 секунды (встроенный микро-таймер Godot)
	await get_tree().create_timer(1.5).timeout
	
	# 3. Играем вторую ноту (занижаем тон, чтобы звучало тревожно)
	pitch_scale = 0.8
	play()
	
	# 4. Задаем таймеру долгую паузу до следующего "приступа"
	$Timer.wait_time = randf_range(8.0, 15.0)
