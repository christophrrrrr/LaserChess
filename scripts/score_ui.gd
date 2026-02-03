extends CanvasLayer

var score_label: Label
var game_board: Node2D

func _ready() -> void:
	_setup_ui()
	
	game_board = get_parent().get_node("GameBoard")
	game_board.score_changed.connect(_on_score_changed)

func _setup_ui() -> void:
	score_label = Label.new()
	score_label.text = "0"
	
	# Use anchors so it stays top-left regardless of window size
	score_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	score_label.position = Vector2(40, 40)
	
	score_label.add_theme_font_size_override("font_size", 96)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	
	add_child(score_label)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)
	
	var tween = create_tween()
	tween.tween_property(score_label, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
