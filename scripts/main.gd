extends Node2D

func _ready() -> void:
	var board = $GameBoard
	var cam   = $Camera2D
	board.player_hit.connect(func(): cam.shake(5.0, 0.20))
	board.score_changed.connect(func(_s): cam.shake(1.8, 0.10))
