extends Node3D

var time_passed = 0.0
var start_y = 0.0

func _ready():
	# Запоминаем изначальную высоту духа на столе, чтобы он не улетел в космос
	start_y = position.y

func _process(delta):
	time_passed += delta
	
	# 1. Плавное парение (медленно летаем вверх-вниз)
	position.y = start_y + sin(time_passed * 3.0) * 0.1
	
	# 2. Имитация пламени (быстрые микро-пульсации: сплющиваем и вытягиваем)
	var pulse = sin(time_passed * 15.0) * 0.05
	scale = Vector3(1.0 - pulse, 1.0 + pulse, 1.0 - pulse)
