extends Label3D

func setup(effect: String, value: int) -> void:
	if effect == "heal":
		text = "+" + str(value)
		modulate = Color(0.2, 0.8, 0.2)
	elif effect == "damage":
		text = "-" + str(value)
		modulate = Color(0.8, 0.1, 0.1)
	else:
		text = "Пустышка"
		modulate = Color(0.6, 0.6, 0.6)

	var tween = create_tween()
	tween.set_parallel(true) 
	
	# Поднимаем текст всего на 0.6 метра (было 1.5) за 1.5 секунды (было 1.0)
	tween.tween_property(self, "position:y", position.y + 0.6, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Растворение теперь тоже длится 1.5 секунды, чтобы совпадать с движением
	tween.tween_property(self, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(queue_free)
