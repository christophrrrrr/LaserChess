extends CanvasLayer

var container: Control
var game_over_label: Label
var score_label: Label
var restart_label: Label
var menu_label: Label
var final_score: int = 0
var is_restarting: bool = false

var player: Node2D
var game_board: Node2D
var hazard_spawner: Node
var score_ui: CanvasLayer

func _ready() -> void:
	player = get_parent().get_node("Player")
	game_board = get_parent().get_node("GameBoard")
	hazard_spawner = get_parent().get_node("HazardSpawner")
	score_ui = get_parent().get_node("ScoreUI")
	
	player.died.connect(_on_player_died)
	
	_setup_ui()
	hide_game_over()

func _setup_ui() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	container.add_child(overlay)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-150, -120)
	center.custom_minimum_size = Vector2(300, 240)
	container.add_child(center)
	
	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	center.add_child(game_over_label)
	
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	center.add_child(spacer1)
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	center.add_child(score_label)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	center.add_child(spacer2)
	
	restart_label = Label.new()
	restart_label.text = "Press SPACE to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	center.add_child(restart_label)
	
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	center.add_child(spacer3)
	
	menu_label = Label.new()
	menu_label.text = "Press ESC for menu"
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.add_theme_font_size_override("font_size", 18)
	menu_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	center.add_child(menu_label)
	
	_pulse_restart_label()

func _pulse_restart_label() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(restart_label, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(restart_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if container.visible and not is_restarting:
		if Input.is_action_just_pressed("press_button"):
			_restart_game()
		elif Input.is_action_just_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_player_died() -> void:
	final_score = game_board.score
	GameSettings.update_high_score(final_score)
	show_game_over()

func show_game_over() -> void:
	is_restarting = false
	score_label.text = "Score: " + str(final_score)
	
	if final_score >= GameSettings.high_score:
		score_label.text += " (NEW HIGH!)"
	
	container.visible = true
	container.modulate.a = 1.0
	
	container.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)
	
	game_over_label.scale = Vector2(0.5, 0.5)
	var label_tween = create_tween()
	label_tween.tween_property(game_over_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_game_over() -> void:
	container.visible = false
	container.modulate.a = 1.0

func _restart_game() -> void:
	is_restarting = true
	
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): 
		container.visible = false
		container.modulate.a = 1.0
	)
	
	call_deferred("_do_reset")

func _do_reset() -> void:
	player.reset()
	hazard_spawner.reset()
	game_board.reset()
