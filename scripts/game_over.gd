extends CanvasLayer

var container: Control
var game_over_label: Label
var score_label: Label
var restart_label: Label
var final_score: int = 0
var is_restarting: bool = false

# References
var player: Node2D
var game_board: Node2D
var hazard_spawner: Node
var score_ui: CanvasLayer

func _ready() -> void:
	# Get references
	player = get_parent().get_node("Player")
	game_board = get_parent().get_node("GameBoard")
	hazard_spawner = get_parent().get_node("HazardSpawner")
	score_ui = get_parent().get_node("ScoreUI")
	
	# Connect to player death
	player.died.connect(_on_player_died)
	
	_setup_ui()
	hide_game_over()

func _setup_ui() -> void:
	# Container to hold everything (covers whole screen)
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	
	# Semi-transparent dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	container.add_child(overlay)
	
	# Center container for text
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-150, -100)
	center.custom_minimum_size = Vector2(300, 200)
	container.add_child(center)
	
	# "GAME OVER" text
	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	center.add_child(game_over_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer1)
	
	# Final score
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	center.add_child(score_label)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer2)
	
	# Restart instruction
	restart_label = Label.new()
	restart_label.text = "Press SPACE to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	center.add_child(restart_label)
	
	# Start pulsing animation on restart text
	_pulse_restart_label()

func _pulse_restart_label() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(restart_label, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(restart_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	# Only listen for restart when game over is visible and not already restarting
	if container.visible and not is_restarting and Input.is_action_just_pressed("press_button"):
		_restart_game()

func _on_player_died() -> void:
	final_score = game_board.score
	show_game_over()

func show_game_over() -> void:
	is_restarting = false
	score_label.text = "Score: " + str(final_score)
	container.visible = true
	container.modulate.a = 1.0
	
	# Animate in
	container.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	
	# Pop in the game over text
	game_over_label.scale = Vector2(0.5, 0.5)
	var label_tween = create_tween()
	label_tween.tween_property(game_over_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_game_over() -> void:
	container.visible = false
	container.modulate.a = 1.0

func _restart_game() -> void:
	is_restarting = true
	
	# Hide immediately first
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		container.visible = false
		container.modulate.a = 1.0
	)
	
	# Reset everything (use call_deferred to avoid issues with async reset)
	call_deferred("_do_reset")

func _do_reset() -> void:
	player.reset()
	hazard_spawner.reset()
	# game_board.reset() is async, so we call it last
	game_board.reset()
