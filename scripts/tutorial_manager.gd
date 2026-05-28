extends Node

# =====================
# TUTORIAL MANAGER
# Teaches movement → rook → bishop → knight → pawn, then exits to main.
# =====================

enum Step { MOVEMENT, ROOK, BISHOP, KNIGHT, PAWN, COMPLETE }

const DODGE_GOAL   := 1   # hazard dodges needed to advance
const MOVE_GOAL    := 3   # free moves needed before first hazard

# ── Node refs (set by tutorial.tscn parent) ──
var game_board: Node2D
var player:     Node2D

# ── Overlay UI nodes (built in _build_overlay) ──
var _overlay_layer: CanvasLayer
var _dim_rect:      ColorRect
var _card_panel:    PanelContainer
var _title_label:   Label
var _body_label:    Label
var _confirm_btn:   Button
var _progress_dots: Array[ColorRect] = []

# ── State ──
var _current_step:   Step = Step.MOVEMENT
var _move_count:     int  = 0
var _dodge_count:    int  = 0
# _pending_dodge is true only when a hazard we spawned is still running AND the
# player has not been hit yet.  It is cleared immediately on player_hit so that
# hazard_finished (which fires a bit later as the piece exits) is ignored.
var _pending_dodge:  bool = false

# Piece names used in UI copy
const PIECE_NAMES := {
	Step.ROOK:   "Rook",
	Step.BISHOP: "Bishop",
	Step.KNIGHT: "Knight",
	Step.PAWN:   "Pawn",
}

# =====================
# LIFECYCLE
# =====================

func _ready() -> void:
	_build_overlay()
	_connect_board_signals()
	_advance_to(_current_step)


func _connect_board_signals() -> void:
	game_board.player_hit.connect(_on_player_hit)
	game_board.hazard_finished.connect(_on_hazard_finished)


# =====================
# STEP MACHINE
# =====================

func _advance_to(step: Step) -> void:
	_current_step  = step
	_pending_dodge = false
	_update_dots()

	match step:
		Step.MOVEMENT:
			_move_count = 0
			var _move_body: String
			if GameSettings.is_mobile:
				_move_body = "Move around the board!\nUse the D-Pad to move your King.\nTap the board to collect glowing squares."
			else:
				_move_body = "Move around the board!\nUse arrow keys or WASD to move your King.\nPress SPACE or E to collect glowing squares."
			_show_card("MOVEMENT", _move_body, "Got it!")
		Step.ROOK:
			_dodge_count = 0
			_show_card(
				"THE ROOK",
				"The Rook sweeps across an entire row or column.\nThe red squares warn you — dodge it!",
				"Got it!"
			)
		Step.BISHOP:
			_dodge_count = 0
			_show_card(
				"THE BISHOP",
				"The Bishop sweeps along diagonals.\nWatch the orange squares and step off the diagonal!",
				"Got it!"
			)
		Step.KNIGHT:
			_dodge_count = 0
			_show_card(
				"THE KNIGHT",
				"The Knight jumps in an L-shape.\nThe marked square shows exactly where it lands — get off it!",
				"Got it!"
			)
		Step.PAWN:
			_dodge_count = 0
			_show_card(
				"THE PAWN",
				"The Pawn marches forward and lunges diagonally.\nStep off the danger squares before it strikes!",
				"Got it!"
			)
		Step.COMPLETE:
			var _complete_body: String
			if GameSettings.is_mobile:
				_complete_body = "Tap the board to collect glowing squares.\nSurvive as long as you can. Good luck!"
			else:
				_complete_body = "Press SPACE or E to collect glowing squares.\nSurvive as long as you can. Good luck!"
			_show_card("YOU'RE READY!", _complete_body, "PLAY!")


# Called when the player presses "Got it!" / "PLAY!"
func _on_confirm_pressed() -> void:
	_hide_card()

	if _current_step == Step.COMPLETE:
		GameSettings.tutorial_complete = true
		GameSettings.save_settings()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return

	# Re-enable player movement and start listening
	player.is_dead = false

	if _current_step == Step.MOVEMENT:
		# Just let the player move; position_changed signal counts progress
		player.position_changed.connect(_on_player_moved)
	else:
		# Spawn the appropriate hazard
		_spawn_step_hazard()


func _spawn_step_hazard() -> void:
	_pending_dodge = true
	match _current_step:
		Step.ROOK:   game_board.spawn_rook_hazard()
		Step.BISHOP: game_board.spawn_bishop_hazard()
		Step.KNIGHT: game_board.spawn_knight_hazard()
		Step.PAWN:   game_board.spawn_pawn_hazard()


# =====================
# SIGNAL HANDLERS
# =====================

func _on_player_moved(_new_pos: Vector2i) -> void:
	if _current_step != Step.MOVEMENT:
		return
	_move_count += 1
	if _move_count >= MOVE_GOAL:
		player.position_changed.disconnect(_on_player_moved)
		player.is_dead = true  # freeze while card is shown
		_advance_to(Step.ROOK)


func _on_player_hit() -> void:
	if _current_step == Step.MOVEMENT or _current_step == Step.COMPLETE:
		return

	# Clear the pending-dodge flag immediately so hazard_finished (which fires
	# a bit later as the piece exits) is not counted as a successful dodge.
	_pending_dodge = false
	player.is_dead = true

	var piece_name: String = PIECE_NAMES.get(_current_step, "hazard")
	_show_card(
		"TRY AGAIN!",
		"The " + piece_name + " got you.\nWatch the danger squares and move out of the way.",
		"Try again"
	)
	# Dodge count is NOT reset — progress is saved, just re-attempt this hazard


func _on_hazard_finished() -> void:
	if _current_step == Step.MOVEMENT or _current_step == Step.COMPLETE:
		return
	if not _pending_dodge:
		return   # hazard_finished from a hit-then-cleared piece, or spurious fire

	_pending_dodge = false
	_dodge_count += 1

	if _dodge_count >= DODGE_GOAL:
		player.is_dead = true  # freeze while card is shown
		var next := _next_step(_current_step)
		_advance_to(next)
	else:
		# Show a small "Well done!" hint, then spawn the same hazard again
		var remaining := DODGE_GOAL - _dodge_count
		var piece_name: String = PIECE_NAMES.get(_current_step, "hazard")
		_show_card(
			"NICE DODGE!",
			"Dodge the " + piece_name + " " + str(remaining) + " more time" + ("s" if remaining > 1 else "") + ".",
			"Next"
		)


func _next_step(step: Step) -> Step:
	match step:
		Step.MOVEMENT: return Step.ROOK
		Step.ROOK:     return Step.BISHOP
		Step.BISHOP:   return Step.KNIGHT
		Step.KNIGHT:   return Step.PAWN
		_:             return Step.COMPLETE


# =====================
# OVERLAY UI
# =====================

func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 200
	add_child(_overlay_layer)

	# Dim background
	_dim_rect = ColorRect.new()
	_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_rect.color = Color(0.0, 0.0, 0.0, 0.65)
	_overlay_layer.add_child(_dim_rect)

	# Centred card
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(center)

	_card_panel = PanelContainer.new()
	_card_panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color        = Color(0.055, 0.06, 0.10)
	style.border_color    = Color(0.25, 0.30, 0.48, 0.80)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(48)
	style.shadow_color    = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size     = 24
	_card_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_card_panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_title_label)

	_spacer(vbox, 20)

	# Divider
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 2)
	div.color = Color(0.25, 0.30, 0.48, 0.50)
	vbox.add_child(div)

	_spacer(vbox, 20)

	# Body
	_body_label = Label.new()
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(460, 0)
	_body_label.add_theme_font_size_override("font_size", 28)
	_body_label.add_theme_color_override("font_color", Color(0.78, 0.80, 0.88))
	vbox.add_child(_body_label)

	_spacer(vbox, 32)

	# Progress dots
	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.add_theme_constant_override("separation", 14)
	vbox.add_child(dot_row)

	var step_count := Step.size() - 1  # all steps except COMPLETE
	for i in step_count:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = Color(0.35, 0.38, 0.55)
		_progress_dots.append(dot)
		dot_row.add_child(dot)

	_spacer(vbox, 28)

	# Confirm button
	_confirm_btn = Button.new()
	_confirm_btn.text = "Got it!"
	_confirm_btn.custom_minimum_size = Vector2(280, 72)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_btn.add_theme_font_size_override("font_size", 28)
	_confirm_btn.add_theme_color_override("font_color", Color.WHITE)

	var btn_n := StyleBoxFlat.new()
	btn_n.bg_color = Color(0.18, 0.52, 0.28)
	btn_n.set_corner_radius_all(10)
	btn_n.border_color = Color(0.28, 0.72, 0.42)
	btn_n.set_border_width_all(2)
	_confirm_btn.add_theme_stylebox_override("normal", btn_n)

	var btn_h := StyleBoxFlat.new()
	btn_h.bg_color = Color(0.24, 0.62, 0.34)
	btn_h.set_corner_radius_all(10)
	_confirm_btn.add_theme_stylebox_override("hover", btn_h)

	var btn_p := StyleBoxFlat.new()
	btn_p.bg_color = Color(0.12, 0.40, 0.20)
	btn_p.set_corner_radius_all(10)
	_confirm_btn.add_theme_stylebox_override("pressed", btn_p)
	_confirm_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_confirm_btn.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_btn)


func _show_card(title: String, body: String, btn_text: String) -> void:
	_title_label.text = title
	_body_label.text  = body
	_confirm_btn.text = btn_text
	_overlay_layer.visible = true
	_update_dots()

	# Pop-in animation
	_card_panel.scale = Vector2(0.85, 0.85)
	_card_panel.modulate.a = 0.0
	var t := _card_panel.create_tween()
	t.tween_property(_card_panel, "scale",      Vector2.ONE,  0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_card_panel, "modulate:a", 1.0, 0.15)


func _hide_card() -> void:
	_overlay_layer.visible = false


func _update_dots() -> void:
	for i in _progress_dots.size():
		var active := (i == int(_current_step))
		_progress_dots[i].color = Color(0.85, 0.70, 0.20) if active else Color(0.30, 0.33, 0.48)


func _spacer(parent: Control, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)
