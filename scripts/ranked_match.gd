extends Node2D

# === MATCH SETTINGS ===
@export var match_duration: float = 75.0
@export var countdown_duration: int = 3

# === NODE REFERENCES ===
var game_board: Node2D
var player: Node2D
var hazard_spawner: Node
var match_hud: CanvasLayer

# === MATCH STATE ===
var match_time_remaining: float = 0.0
var is_match_active: bool = false
var is_countdown_active: bool = false
var match_seed: int = 0
var opponent_name: String = "OPP"

# === SCORE: peak-based ===
var my_best_score: int = 0
var opponent_best_score: int = 0

# === HUD ELEMENTS ===
var timer_label: Label
var my_score_label: Label
var opponent_score_label: Label
var opponent_name_label: Label
var countdown_label: Label
var result_container: Control
var queue_container: Control
var queue_status_label: Label

func _ready() -> void:
	game_board = $GameBoard
	player = $Player
	hazard_spawner = $HazardSpawner
	
	player.died.connect(_on_player_died_ranked)
	game_board.score_changed.connect(_on_my_score_changed)
	
	# Freeze everything until match starts
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	_setup_hud()
	_connect_network_signals()
	_show_queue_screen()

# =====================
# NETWORK SIGNALS
# =====================

func _connect_network_signals() -> void:
	NetworkManager.connected.connect(_on_server_connected)
	NetworkManager.disconnected.connect(_on_server_disconnected)
	NetworkManager.queued.connect(_on_queued)
	NetworkManager.match_found.connect(_on_match_found)
	NetworkManager.opponent_score_updated.connect(_on_opponent_score_updated)
	NetworkManager.match_result_received.connect(_on_match_result)
	NetworkManager.opponent_disconnected.connect(_on_opponent_disconnected)
	NetworkManager.error_received.connect(_on_network_error)

func _on_server_connected() -> void:
	queue_status_label.text = "Connected! Joining queue..."
	NetworkManager.join_queue()

func _on_server_disconnected() -> void:
	if is_match_active:
		is_match_active = false
		hazard_spawner.is_active = false
		hazard_spawner.spawn_timer.stop()
		player.is_dead = true
	
	queue_status_label.text = "Disconnected from server.\nPress SPACE to reconnect."
	queue_container.visible = true
	result_container.visible = false

func _on_queued() -> void:
	queue_status_label.text = "Searching for opponent..."

func _on_match_found(seed_val: int, opp_name: String) -> void:
	match_seed = seed_val
	opponent_name = opp_name
	
	# Update opponent name on HUD
	if opponent_name_label:
		opponent_name_label.text = opponent_name + "  (best)"
	
	queue_container.visible = false
	_start_countdown()

func _on_opponent_score_updated(best_score: int) -> void:
	if best_score > opponent_best_score:
		opponent_best_score = best_score
		opponent_score_label.text = str(opponent_best_score)
		
		var tween = create_tween()
		tween.tween_property(opponent_score_label, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(opponent_score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)

func _on_match_result(result: String, my_score: int, opp_score: int) -> void:
	# Server confirmed result — show it
	# (we may have already shown results from our own timer, so just update if needed)
	pass

func _on_opponent_disconnected(my_score: int, opp_score: int) -> void:
	if is_match_active:
		is_match_active = false
		hazard_spawner.is_active = false
		hazard_spawner.spawn_timer.stop()
		player.is_dead = true
		_show_disconnect_win()

func _on_network_error(msg: String) -> void:
	print("[RANKED] Network error: ", msg)

# =====================
# HUD SETUP
# =====================

func _setup_hud() -> void:
	match_hud = CanvasLayer.new()
	match_hud.layer = 10
	add_child(match_hud)
	
	# --- Timer (top center) ---
	timer_label = Label.new()
	timer_label.text = _format_time(match_duration)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position = Vector2(-60, 12)
	timer_label.custom_minimum_size = Vector2(120, 0)
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	timer_label.add_theme_constant_override("shadow_offset_x", 2)
	timer_label.add_theme_constant_override("shadow_offset_y", 2)
	timer_label.visible = false
	match_hud.add_child(timer_label)
	
	# --- My score (bottom left) ---
	var my_panel = _create_score_panel("YOU  (best)", Color(0.0, 0.8, 0.4, 0.15), Color(0.0, 0.8, 0.4))
	my_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	my_panel.position = Vector2(15, -80)
	my_panel.visible = false
	my_panel.name = "MyPanel"
	match_hud.add_child(my_panel)
	my_score_label = my_panel.get_meta("score_label")
	
	# --- Opponent score (bottom right) ---
	var opp_panel = _create_score_panel("OPP  (best)", Color(1.0, 0.3, 0.3, 0.15), Color(1.0, 0.4, 0.4))
	opp_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	opp_panel.position = Vector2(-145, -80)
	opp_panel.visible = false
	opp_panel.name = "OppPanel"
	match_hud.add_child(opp_panel)
	opponent_score_label = opp_panel.get_meta("score_label")
	opponent_name_label = opp_panel.get_meta("name_label")
	
	# --- Countdown (center) ---
	countdown_label = Label.new()
	countdown_label.text = ""
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.position = Vector2(-100, -60)
	countdown_label.custom_minimum_size = Vector2(200, 120)
	countdown_label.add_theme_font_size_override("font_size", 96)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	countdown_label.visible = false
	match_hud.add_child(countdown_label)
	
	# --- Queue screen ---
	_setup_queue_screen()
	
	# --- Result screen ---
	_setup_result_screen()

func _create_score_panel(label_text: String, bg_color: Color, text_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(130, 65)
	
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	style.border_color = text_color.darkened(0.3)
	style.border_color.a = 0.4
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = label_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", text_color.darkened(0.1))
	vbox.add_child(name_lbl)
	
	var score_lbl = Label.new()
	score_lbl.text = "0"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 32)
	score_lbl.add_theme_color_override("font_color", text_color)
	vbox.add_child(score_lbl)
	
	panel.set_meta("score_label", score_lbl)
	panel.set_meta("name_label", name_lbl)
	return panel

func _setup_queue_screen() -> void:
	queue_container = Control.new()
	queue_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_container.visible = false
	match_hud.add_child(queue_container)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.03, 0.03, 0.08, 0.92)
	queue_container.add_child(overlay)
	
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_container.add_child(center_wrap)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center_wrap.add_child(vbox)
	
	var title = Label.new()
	title.text = "RANKED MATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	vbox.add_child(title)
	
	_add_spacer(vbox, 30)
	
	queue_status_label = Label.new()
	queue_status_label.text = "Connecting to server..."
	queue_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_status_label.add_theme_font_size_override("font_size", 22)
	queue_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(queue_status_label)
	
	_add_spacer(vbox, 15)
	
	# Dots animation
	var dots_label = Label.new()
	dots_label.name = "DotsLabel"
	dots_label.text = ""
	dots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots_label.add_theme_font_size_override("font_size", 28)
	dots_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	vbox.add_child(dots_label)
	
	# Animate dots
	var tween = create_tween()
	tween.set_loops()
	tween.tween_callback(func(): dots_label.text = ".").set_delay(0.3)
	tween.tween_callback(func(): dots_label.text = "..").set_delay(0.3)
	tween.tween_callback(func(): dots_label.text = "...").set_delay(0.3)
	tween.tween_callback(func(): dots_label.text = "").set_delay(0.3)
	
	_add_spacer(vbox, 30)
	
	var esc_label = Label.new()
	esc_label.text = "ESC to cancel"
	esc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_label.add_theme_font_size_override("font_size", 16)
	esc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	vbox.add_child(esc_label)

func _setup_result_screen() -> void:
	result_container = Control.new()
	result_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.visible = false
	match_hud.add_child(result_container)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.name = "Overlay"
	result_container.add_child(overlay)

# =====================
# QUEUE SCREEN
# =====================

func _show_queue_screen() -> void:
	queue_container.visible = true
	result_container.visible = false
	timer_label.visible = false
	match_hud.get_node("MyPanel").visible = false
	match_hud.get_node("OppPanel").visible = false
	
	# Connect to server
	if not NetworkManager.is_connected_to_server():
		queue_status_label.text = "Connecting to server..."
		NetworkManager.connect_to_server()
	else:
		queue_status_label.text = "Joining queue..."
		NetworkManager.join_queue()

# =====================
# COUNTDOWN
# =====================

func _start_countdown() -> void:
	is_countdown_active = true
	countdown_label.visible = true
	timer_label.visible = true
	match_hud.get_node("MyPanel").visible = true
	match_hud.get_node("OppPanel").visible = true
	
	for i in range(countdown_duration, 0, -1):
		countdown_label.text = str(i)
		countdown_label.scale = Vector2(1.5, 1.5)
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout
	
	countdown_label.text = "GO!"
	countdown_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	countdown_label.scale = Vector2(1.8, 1.8)
	var go_tween = create_tween()
	go_tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
	go_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	go_tween.tween_callback(func():
		countdown_label.visible = false
		countdown_label.modulate.a = 1.0
		countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	)
	
	is_countdown_active = false
	_start_match()

func _start_match() -> void:
	is_match_active = true
	match_time_remaining = match_duration
	
	game_board.set_match_seed(match_seed)
	
	player.is_dead = false
	player.is_moving = false
	
	hazard_spawner.is_active = true
	hazard_spawner.spawn_timer.start(hazard_spawner.initial_delay)

# =====================
# PROCESS
# =====================

func _process(delta: float) -> void:
	if not is_match_active:
		return
	
	match_time_remaining -= delta
	timer_label.text = _format_time(match_time_remaining)
	
	if match_time_remaining <= 10.0:
		var pulse = abs(sin(match_time_remaining * 3.0))
		timer_label.add_theme_color_override("font_color", Color(1.0, pulse * 0.5 + 0.5, pulse * 0.5 + 0.5))
	
	if match_time_remaining <= 0.0:
		match_time_remaining = 0.0
		timer_label.text = "0:00"
		_end_match()
		return

# =====================
# SCORE & DEATH
# =====================

func _on_my_score_changed(new_score: int) -> void:
	if new_score > my_best_score:
		my_best_score = new_score
		my_score_label.text = str(my_best_score)
		
		var tween = create_tween()
		tween.tween_property(my_score_label, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(my_score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
		
		# Send to server
		NetworkManager.send_score_update(my_best_score)

func _on_player_died_ranked() -> void:
	if not is_match_active:
		return
	
	await get_tree().create_timer(1.0).timeout
	
	if not is_match_active:
		return
	
	player.reset()
	game_board.reset()
	hazard_spawner.reset()
	
	var flash_tween = create_tween()
	flash_tween.set_loops(3)
	flash_tween.tween_property(player, "modulate:a", 0.3, 0.1)
	flash_tween.tween_property(player, "modulate:a", 1.0, 0.1)

# =====================
# MATCH END
# =====================

func _end_match() -> void:
	is_match_active = false
	
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	# Tell server our final score
	NetworkManager.send_match_end(my_best_score)
	
	_show_results()

func _show_results() -> void:
	for child in result_container.get_children():
		if child.name == "Overlay":
			continue
		child.queue_free()
	
	result_container.visible = true
	result_container.modulate.a = 0
	
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.add_child(center_wrap)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center_wrap.add_child(vbox)
	
	# Result
	var result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 56)
	result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	result_label.add_theme_constant_override("shadow_offset_x", 3)
	result_label.add_theme_constant_override("shadow_offset_y", 3)
	
	if my_best_score > opponent_best_score:
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	elif my_best_score < opponent_best_score:
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		result_label.text = "DRAW"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	vbox.add_child(result_label)
	
	_add_spacer(vbox, 20)
	
	# Score comparison
	var score_text = Label.new()
	score_text.text = str(my_best_score) + "  —  " + str(opponent_best_score)
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_text.add_theme_font_size_override("font_size", 40)
	score_text.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(score_text)
	
	_add_spacer(vbox, 6)
	
	var you_opp = Label.new()
	you_opp.text = "YOU              " + opponent_name
	you_opp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you_opp.add_theme_font_size_override("font_size", 15)
	you_opp.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(you_opp)
	
	_add_spacer(vbox, 25)
	
	# Seed display
	var seed_lbl = Label.new()
	seed_lbl.text = "seed: " + str(match_seed)
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	vbox.add_child(seed_lbl)
	
	_add_spacer(vbox, 30)
	
	var restart_lbl = Label.new()
	restart_lbl.text = "SPACE to queue again"
	restart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_lbl.add_theme_font_size_override("font_size", 22)
	restart_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(restart_lbl)
	
	_add_spacer(vbox, 8)
	
	var menu_lbl = Label.new()
	menu_lbl.text = "ESC for menu"
	menu_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_lbl.add_theme_font_size_override("font_size", 16)
	menu_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(menu_lbl)
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(restart_lbl, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(restart_lbl, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	
	var fade = create_tween()
	fade.tween_property(result_container, "modulate:a", 1.0, 0.4)

func _show_disconnect_win() -> void:
	for child in result_container.get_children():
		if child.name == "Overlay":
			continue
		child.queue_free()
	
	result_container.visible = true
	result_container.modulate.a = 0
	
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.add_child(center_wrap)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center_wrap.add_child(vbox)
	
	var result_label = Label.new()
	result_label.text = "OPPONENT LEFT"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 48)
	result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	vbox.add_child(result_label)
	
	_add_spacer(vbox, 12)
	
	var sub = Label.new()
	sub.text = "You win by default!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(sub)
	
	_add_spacer(vbox, 40)
	
	var restart_lbl = Label.new()
	restart_lbl.text = "SPACE to queue again"
	restart_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_lbl.add_theme_font_size_override("font_size", 22)
	restart_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(restart_lbl)
	
	_add_spacer(vbox, 8)
	
	var menu_lbl = Label.new()
	menu_lbl.text = "ESC for menu"
	menu_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_lbl.add_theme_font_size_override("font_size", 16)
	menu_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(menu_lbl)
	
	var fade = create_tween()
	fade.tween_property(result_container, "modulate:a", 1.0, 0.4)

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			NetworkManager.disconnect_from_server()
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return
		
		# From result screen or queue (reconnect) -> queue again
		if result_container.visible or (queue_container.visible and not NetworkManager.is_connected_to_server()):
			if event.keycode == KEY_SPACE or event.keycode == KEY_E or event.keycode == KEY_ENTER:
				_restart_to_queue()

func _restart_to_queue() -> void:
	result_container.visible = false
	
	my_best_score = 0
	opponent_best_score = 0
	my_score_label.text = "0"
	opponent_score_label.text = "0"
	timer_label.text = _format_time(match_duration)
	timer_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	
	player.reset()
	game_board.reset()
	hazard_spawner.reset()
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	_show_queue_screen()

# =====================
# HELPERS
# =====================

func _format_time(seconds: float) -> String:
	var s = max(0, int(ceil(seconds)))
	var mins = s / 60
	var secs = s % 60
	return str(mins) + ":" + ("0" + str(secs) if secs < 10 else str(secs))

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)
