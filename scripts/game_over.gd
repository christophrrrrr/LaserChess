extends CanvasLayer

# === GAME OVER UI ===
var container: Control
var game_over_label: Label
var score_label: Label
var highscore_label: Label
var points_label: Label
var restart_label: Label
var menu_label: Label
var _mobile_restart_btn: Button
var _mobile_menu_btn: Button
var final_score: int = 0
var is_restarting: bool = false

# === INPUT GRACE PERIOD ===
## Prevents accidental restart when player was holding SPACE to hit
## and dies at the same moment. Input is blocked for this duration
## after the game-over screen appears.
const RESTART_GRACE_PERIOD := 0.7
var _grace_timer: float = 0.0
var _accepting_input: bool = false

# === PAUSE MENU ===
var pause_container: Control
var is_paused: bool = false

# === REFERENCES ===
var player: Node2D
var game_board: Node2D
var hazard_spawner: Node
var score_ui: CanvasLayer

func _ready() -> void:
	# CRITICAL: process during pause so ESC / buttons work while tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = get_parent().get_node("Player")
	game_board = get_parent().get_node("GameBoard")
	hazard_spawner = get_parent().get_node("HazardSpawner")
	score_ui = get_parent().get_node("ScoreUI")

	player.died.connect(_on_player_died)

	_setup_ui()
	_setup_pause_menu()
	hide_game_over()
	pause_container.visible = false

func _process(delta: float) -> void:
	# Tick the grace timer (runs even when paused, since process_mode = ALWAYS)
	if container.visible and not _accepting_input:
		_grace_timer -= delta
		if _grace_timer <= 0.0:
			_accepting_input = true
			if GameSettings.is_mobile:
				# Enable the real buttons
				if _mobile_restart_btn:
					_mobile_restart_btn.disabled = false
					_mobile_restart_btn.modulate.a = 1.0
				if _mobile_menu_btn:
					_mobile_menu_btn.disabled = false
					_mobile_menu_btn.modulate.a = 1.0
			else:
				# Fade the restart hint in once input is actually accepted
				var t = create_tween()
				t.tween_property(restart_label, "modulate:a", 1.0, 0.25)

# =====================
# GAME OVER UI
# =====================

func _setup_ui() -> void:
	container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	add_child(container)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	container.add_child(overlay)

	var center_wrapper = CenterContainer.new()
	center_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(center_wrapper)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center_wrapper.add_child(vbox)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 64)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	game_over_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	game_over_label.add_theme_constant_override("shadow_offset_x", 3)
	game_over_label.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(game_over_label)

	_add_spacer(vbox, 24)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(score_label)

	_add_spacer(vbox, 6)

	highscore_label = Label.new()
	highscore_label.text = ""
	highscore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	highscore_label.add_theme_font_size_override("font_size", 28 if GameSettings.is_mobile else 22)
	highscore_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(highscore_label)

	_add_spacer(vbox, 8)

	points_label = Label.new()
	points_label.text = ""
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 24 if GameSettings.is_mobile else 18)
	points_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(points_label)

	_add_spacer(vbox, 30)

	if GameSettings.is_mobile:
		# Real tappable buttons — much easier to hit than text hints
		_mobile_restart_btn = _create_action_button("RESTART", Color(0.18, 0.52, 0.28), 90, 32)
		_mobile_restart_btn.pressed.connect(func():
			if _accepting_input and not is_restarting:
				SoundManager.play("click")
				_restart_game()
		)
		vbox.add_child(_mobile_restart_btn)

		_add_spacer(vbox, 14)

		_mobile_menu_btn = _create_action_button("MENU", Color(0.25, 0.27, 0.35), 80, 28)
		_mobile_menu_btn.pressed.connect(func():
			SoundManager.play("click")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		)
		vbox.add_child(_mobile_menu_btn)

		# Still create restart_label as invisible dummy (referenced by show_game_over)
		restart_label = Label.new()
		restart_label.visible = false
		vbox.add_child(restart_label)
		menu_label = Label.new()
		menu_label.visible = false
		vbox.add_child(menu_label)
	else:
		restart_label = Label.new()
		restart_label.text = "Press SPACE to restart"
		restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		restart_label.add_theme_font_size_override("font_size", 24)
		restart_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(restart_label)

		_add_spacer(vbox, 10)

		menu_label = Label.new()
		menu_label.text = "ESC for menu"
		menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu_label.add_theme_font_size_override("font_size", 18)
		menu_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(menu_label)

# =====================
# PAUSE MENU
# =====================

func _setup_pause_menu() -> void:
	pause_container = Control.new()
	pause_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pause_container)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	pause_container.add_child(overlay)

	# Center wrapper (margin on mobile so panel doesn't touch screen edges)
	var panel = PanelContainer.new()
	if GameSettings.is_mobile:
		var pause_margin = MarginContainer.new()
		pause_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_margin.add_theme_constant_override("margin_left",   28)
		pause_margin.add_theme_constant_override("margin_right",  28)
		pause_margin.add_theme_constant_override("margin_top",    40)
		pause_margin.add_theme_constant_override("margin_bottom", 40)
		pause_container.add_child(pause_margin)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_margin.add_child(panel)
	else:
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		pause_container.add_child(center)
		panel.custom_minimum_size = Vector2(640, 560)
		center.add_child(panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.12)
	panel_style.set_corner_radius_all(14)
	panel_style.border_color = Color(0.35, 0.35, 0.5, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# "PAUSED" title
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	_add_spacer(vbox, 40)

	# Continue button
	var continue_btn = _create_pause_button("CONTINUE", Color(0.0, 0.65, 0.35))
	continue_btn.pressed.connect(_resume_game)
	vbox.add_child(continue_btn)

	_add_spacer(vbox, 14)

	# Main Menu button
	var menu_btn = _create_pause_button("MAIN MENU", Color(0.35, 0.3, 0.4))
	menu_btn.pressed.connect(_pause_to_menu)
	vbox.add_child(menu_btn)

	_add_spacer(vbox, 24)

	# Hint
	var hint = Label.new()
	hint.text = "Tap CONTINUE to resume" if GameSettings.is_mobile else "ESC or SPACE to continue"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	vbox.add_child(hint)

func _create_pause_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(440, 96)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 44)
	btn.add_theme_color_override("font_color", Color.WHITE)

	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.2)
			"pressed": s.bg_color = color.darkened(0.15)
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _pause_game() -> void:
	if is_paused or container.visible:
		return
	is_paused = true
	SoundManager.play("click")
	get_tree().paused = true
	pause_container.visible = true
	pause_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(pause_container, "modulate:a", 1.0, 0.12)

func _resume_game() -> void:
	if not is_paused:
		return
	SoundManager.play("click")
	is_paused = false
	pause_container.visible = false
	get_tree().paused = false

func _pause_to_menu() -> void:
	SoundManager.play("click")
	is_paused = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	var is_key:   bool = event is InputEventKey            and event.pressed and not event.echo
	var is_tap:   bool = event is InputEventScreenTouch    and event.pressed
	var is_click: bool = event is InputEventMouseButton    and event.pressed

	if not (is_key or is_tap or is_click):
		return

	# --- ESC key (keyboard only) ---
	if is_key and (event as InputEventKey).keycode == KEY_ESCAPE:
		if is_paused:
			_resume_game()
		elif container.visible:
			SoundManager.play("click")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		elif not player.is_dead and not is_restarting:
			_pause_game()
		return

	# --- SPACE / ENTER while paused → resume (keyboard only) ---
	if is_paused:
		if is_key:
			var kc := (event as InputEventKey).keycode
			if kc == KEY_SPACE or kc == KEY_ENTER:
				_resume_game()
		return

	# --- Game over inputs (ONLY after grace period) ---
	if container.visible and _accepting_input and not is_restarting:
		var want_restart := false
		if is_key:
			var kc := (event as InputEventKey).keycode
			want_restart = kc == KEY_SPACE or kc == KEY_E or kc == KEY_ENTER
		elif (is_tap or is_click) and GameSettings.is_mobile:
			want_restart = true
		if want_restart:
			SoundManager.play("click")
			_restart_game()

# =====================
# GAME OVER LOGIC
# =====================

func _on_player_died() -> void:
	final_score = game_board.score
	GameSettings.update_high_score(final_score)
	PlayerData.update_solo_highscore(final_score)
	PlayerData.add_points(final_score)
	show_game_over()

func show_game_over() -> void:
	is_restarting = false
	score_label.text = "Score: " + str(final_score)

	if final_score >= PlayerData.solo_highscore and final_score > 0:
		highscore_label.text = "★ NEW HIGH SCORE! ★"
	else:
		highscore_label.text = "Best: " + str(PlayerData.solo_highscore)

	if final_score > 0:
		points_label.text = "+" + str(final_score) + " points  (Total: " + str(PlayerData.total_points) + ")"
		points_label.visible = true
	else:
		points_label.visible = false

	# Start grace period — input blocked for a moment after death
	_accepting_input = false
	_grace_timer = RESTART_GRACE_PERIOD
	if GameSettings.is_mobile:
		# Disable buttons during grace period so they can't be fat-fingered immediately
		if _mobile_restart_btn:
			_mobile_restart_btn.disabled = true
			_mobile_restart_btn.modulate.a = 0.5
		if _mobile_menu_btn:
			_mobile_menu_btn.disabled = true
			_mobile_menu_btn.modulate.a = 0.5
	else:
		restart_label.modulate.a = 0.0  # hidden during grace

	container.visible = true
	container.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.3)

	game_over_label.scale = Vector2(0.5, 0.5)
	var label_tween = create_tween()
	label_tween.tween_property(game_over_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_game_over() -> void:
	container.visible = false
	container.modulate.a = 1.0
	_accepting_input = false

func _restart_game() -> void:
	is_restarting = true
	_accepting_input = false
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
	# CRITICAL: re-enable input and pause after the reset is complete
	is_restarting = false

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _create_action_button(text: String, color: Color, height: int, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	# 560px min width looks good on 1080px-wide portrait phone (centered by CenterContainer)
	btn.custom_minimum_size = Vector2(560, height)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	normal.border_color = color.lightened(0.2)
	normal.set_border_width_all(2)
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.1)
	hover.set_corner_radius_all(10)
	hover.set_border_width_all(2)
	hover.border_color = color.lightened(0.3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.15)
	pressed.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn
