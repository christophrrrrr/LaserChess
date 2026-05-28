extends Camera2D

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0

func shake(intensity: float, duration: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(_shake_duration, duration)

func _process(delta: float) -> void:
	if _shake_duration > 0.0:
		_shake_duration -= delta
		offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		if _shake_duration <= 0.0:
			_shake_intensity = 0.0
			offset = Vector2.ZERO
