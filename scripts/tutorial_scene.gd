extends Node2D

## Thin parent for the tutorial scene.
## Sets up the TutorialManager node and wires shake signals.

func _ready() -> void:
	var board  := $GameBoard as Node2D
	var player := $Player    as Node2D
	var cam    := $Camera2D

	# Screen shake
	board.player_hit.connect(func(): cam.shake(4.0, 0.18))

	# Player starts frozen — TutorialManager releases it after the first card is dismissed
	player.is_dead = true

	# Build TutorialManager as a child node
	var mgr := preload("res://scripts/tutorial_manager.gd").new()
	mgr.name       = "TutorialManager"
	mgr.game_board = board
	mgr.player     = player
	add_child(mgr)
