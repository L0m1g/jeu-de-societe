extends PathFollow2D

var step_ratios: Array = []

func _ready() -> void:
	GameManager.turn_changed.connect(_on_turn_changed)
	_compute_step_ratios()

func _compute_step_ratios() -> void:
	var curve: Curve2D = get_parent().curve
	var total_length: float = curve.get_baked_length()
	
	for i in range(curve.point_count):
		var point_position: Vector2 = curve.get_point_position(i)
		var offset: float = curve.get_closest_offset(point_position)
		var ratio: float = offset / total_length
		step_ratios.append(ratio)

func _on_turn_changed(turn: int) -> void:
	var target_ratio: float = step_ratios[turn]
	var tween = create_tween()
	tween.tween_property(self, "progress_ratio", target_ratio, 0.3)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
