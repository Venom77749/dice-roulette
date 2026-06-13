@tool
extends OmniLight3D

# @export позволяет настраивать эти параметры прямо в Инспекторе справа!
@export var base_energy: float = 1.0 # Нормальная яркость свечи
@export var flicker_speed: float = 8.0 # Как быстро дергается пламя (ветер)
@export var flicker_intensity: float = 0.3 # Насколько сильно тускнеет/разгорается свет



var noise: FastNoiseLite
var time_passed: float = 0.0

func _ready() -> void:
	# Настраиваем генератор "природного" шума
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	# Задаем случайное зерно. Если у тебя будет 10 свечей, все они будут мерцать по-разному!
	noise.seed = randi() 

func _process(delta: float) -> void:
	# Время идет вперед со скоростью мерцания
	time_passed += delta * flicker_speed
	
	# Получаем плавное случайное число от -1.0 до 1.0
	var noise_value = noise.get_noise_1d(time_passed)
	
	# Меняем яркость света: 
	# Базовая яркость + (случайное число * сила мерцания)
	light_energy = base_energy + (noise_value * flicker_intensity)
