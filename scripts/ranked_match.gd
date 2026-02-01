extends Node2D

# === MATCH SETTINGS ===
@export var match_duration: float = 75.0
@export var countdown_duration: int = 3

# === STATE ===
enum State { CONNECTING, LOBBY, COUNTDOWN, PLAYING, RESULTS }
var current_state: State = State.CONNECTING

# === NODE REFERENCES ===
var game_board: Node2D
var player: Node2D
var hazard_spawner: Node

# === MATCH DATA ===
var match_time_remaining: float = 0.0
var match_seed: int = 0
var opponent_name: String = "OPP"
var my_best_score: int = 0
var opponent_best_score: int = 0

# === HUD LAYER ===
var match_hud: CanvasLayer
var timer_label: Label
var my_score_label: Label
var opponent_score_label: Label
var opp_name_label: Label
var countdown_label: Label

# === LOBBY ===
var lobby_container: Control
var lobby_content: VBoxContainer
var error_flash: Label

# === RESULTS ===
var result_container: Control

# =====================
# LIFECYCLE
# =====================

func _ready() -> void:
	game_board = $GameBoard
	player = $Player
	hazard_spawner = $HazardSpawner
	
	player.died.connect(_on_player_died_ranked)
	game_board.score_changed.connect(_on_my_score_changed)
	
	# Freeze until match starts
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	_setup_hud()
	_connect_signals()
	
	# Start connecting
	_show_connecting()
	NetworkManager.connect_to_server()

func _exit_tree() -> void:
	# Signals auto-disconnect when this node is freed,
	# but we explicitly close the socket if leaving mid-match.
	pass

# =====================
# SIGNAL CONNECTIONS
# =====================

func _connect_signals() -> void:
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.match_started.connect(_on_match_started)
	NetworkManager.opponent_score_updated.connect(_on_opponent_score)
	NetworkManager.opponent_disconnected.connect(_on_opponent_disconnected)
	NetworkManager.challenge_failed.connect(_on_challenge_failed)

# =====================
# NETWORK CALLBACKS
# =====================

func _on_connected(_my_name: String) -> void:
	NetworkManager.join_lobby()

func _on_connection_failed() -> void:
	_show_error("Could not connect to server.\nCheck your internet connection.")

func _on_disconnected() -> void:
	if current_state == State.PLAYING or current_state == State.COUNTDOWN:
		current_state = State.RESULTS
		hazard_spawner.is_active = false
		hazard_spawner.spawn_timer.stop()
		player.is_dead = true
		_show_connection_lost()
	elif current_state != State.RESULTS:
		_show_error("Disconnected from server.")

func _on_lobby_updated(players_list: Array, total_online: int) -> void:
	if current_state == State.CONNECTING or current_state == State.LOBBY:
		_show_lobby(players_list, total_online)

func _on_match_started(seed_val: int, opp_name: String) -> void:
	match_seed = seed_val
	opponent_name = opp_name
	if opp_name_label:
		opp_name_label.text = opp_name + "  (best)"
	_start_countdown()

func _on_opponent_score(best_score: int) -> void:
	if best_score > opponent_best_score:
		opponent_best_score = best_score
		opponent_score_label.text = str(opponent_best_score)
		var tween = create_tween()
		tween.tween_property(opponent_score_label, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(opponent_score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)

func _on_opponent_disconnected() -> void:
	if current_state == State.PLAYING or current_state == State.COUNTDOWN:
		_show_disconnect_win()

func _on_challenge_failed(msg: String) -> void:
	if current_state != State.LOBBY:
		return
	_flash_error(msg)

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
	timer_label.add_theme_color_override("font_color", Color.WHITE)
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
	opp_name_label = opp_panel.get_meta("name_label")
	
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
	
	# --- Lobby container ---
	lobby_container = Control.new()
	lobby_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_container.visible = false
	match_hud.add_child(lobby_container)
	
	var lobby_bg = ColorRect.new()
	lobby_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_bg.color = Color(0.03, 0.03, 0.08, 0.92)
	lobby_container.add_child(lobby_bg)
	
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_container.add_child(center_wrap)
	
	lobby_content = VBoxContainer.new()
	lobby_content.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_content.add_theme_constant_override("separation", 0)
	center_wrap.add_child(lobby_content)
	
	# Error flash (persistent, outside lobby_content so it survives rebuilds)
	error_flash = Label.new()
	error_flash.text = ""
	error_flash.visible = false
	error_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_flash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	error_flash.position = Vector2(-150, -25)
	error_flash.custom_minimum_size = Vector2(300, 0)
	error_flash.add_theme_font_size_override("font_size", 16)
	error_flash.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	lobby_container.add_child(error_flash)
	
	# --- Result container ---
	result_container = Control.new()
	result_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.visible = false
	match_hud.add_child(result_container)
	
	var result_bg = ColorRect.new()
	result_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_bg.color = Color(0, 0, 0, 0.75)
	result_bg.name = "Overlay"
	result_container.add_child(result_bg)

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

# =====================
# LOBBY SCREENS
# =====================

func _clear_lobby_content() -> void:
	for child in lobby_content.get_children():
		lobby_content.remove_child(child)
		child.queue_free()

func _set_match_hud_visible(show: bool) -> void:
	timer_label.visible = show
	match_hud.get_node("MyPanel").visible = show
	match_hud.get_node("OppPanel").visible = show

func _show_connecting() -> void:
	current_state = State.CONNECTING
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud_visible(false)
	countdown_label.visible = false
	
	_clear_lobby_content()
	_add_title()
	_add_spacer(lobby_content, 30)
	
	var lbl = Label.new()
	lbl.text = "Connecting to server..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	lobby_content.add_child(lbl)
	_pulse(lbl)
	
	_add_spacer(lobby_content, 35)
	_add_hint(lobby_content, "ESC to go back")

func _show_error(msg: String) -> void:
	current_state = State.CONNECTING  # Can retry
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud_visible(false)
	countdown_label.visible = false
	
	_clear_lobby_content()
	_add_title()
	_add_spacer(lobby_content, 25)
	
	var err_lbl = Label.new()
	err_lbl.text = msg
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_size_override("font_size", 20)
	err_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lobby_content.add_child(err_lbl)
	
	_add_spacer(lobby_content, 25)
	
	var retry_lbl = Label.new()
	retry_lbl.text = "SPACE to retry  •  ESC to go back"
	retry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_lbl.add_theme_font_size_override("font_size", 18)
	retry_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lobby_content.add_child(retry_lbl)

func _show_lobby(players_list: Array, total_online: int) -> void:
	current_state = State.LOBBY
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud_visible(false)
	countdown_label.visible = false
	
	_clear_lobby_content()
	_add_title()
	_add_spacer(lobby_content, 10)
	
	# Online count
	var count_lbl = Label.new()
	count_lbl.text = str(total_online) + " player" + ("s" if total_online != 1 else "") + " online"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 15)
	count_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	lobby_content.add_child(count_lbl)
	
	_add_spacer(lobby_content, 18)
	
	# Filter out self
	var others: Array = []
	for p in players_list:
		if p["id"] != NetworkManager.my_id:
			others.append(p)
	
	if others.is_empty():
		# No opponents available
		var wait_lbl = Label.new()
		wait_lbl.text = "Waiting for an opponent..."
		wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait_lbl.add_theme_font_size_override("font_size", 22)
		wait_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		lobby_content.add_child(wait_lbl)
		_pulse(wait_lbl, 0.8)
	else:
		# "Click to challenge" hint
		var hint = Label.new()
		hint.text = "Click a player to challenge:"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		lobby_content.add_child(hint)
		
		_add_spacer(lobby_content, 10)
		
		# Player buttons
		for p in others:
			var btn = _create_player_button(p["name"], p["id"])
			lobby_content.add_child(btn)
			_add_spacer(lobby_content, 6)
	
	_add_spacer(lobby_content, 20)
	_add_hint(lobby_content, "ESC to go back")

# =====================
# PLAYER BUTTON
# =====================

func _create_player_button(player_name: String, player_id: int) -> Button:
	var btn = Button.new()
	btn.text = "   " + player_name + "   "
	btn.custom_minimum_size = Vector2(260, 44)

	# Normal
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.16)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(0.25, 0.25, 0.35)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.14, 0.22)
	hover.set_corner_radius_all(6)
	hover.border_color = Color(0.85, 0.55, 0.1)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.18, 0.1)
	pressed.set_corner_radius_all(6)
	pressed.border_color = Color(0.85, 0.55, 0.1)
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Focus (keyboard navigation)
	var focus = hover.duplicate()
	btn.add_theme_stylebox_override("focus", focus)

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.7, 0.3))

	btn.pressed.connect(_on_player_button_pressed.bind(player_id))
	return btn

func _on_player_button_pressed(player_id: int) -> void:
	if current_state != State.LOBBY:
		return
	NetworkManager.challenge_player(player_id)

func _flash_error(msg: String) -> void:
	error_flash.text = msg
	error_flash.visible = true
	error_flash.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(error_flash, "modulate:a", 0.0, 1.2).set_delay(1.0)
	tween.tween_callback(func(): error_flash.visible = false)

# =====================
# COUNTDOWN
# =====================

func _start_countdown() -> void:
	current_state = State.COUNTDOWN
	lobby_container.visible = false
	countdown_label.visible = true
	_set_match_hud_visible(true)
	
	for i in range(countdown_duration, 0, -1):
		countdown_label.text = str(i)
		countdown_label.scale = Vector2(1.5, 1.5)
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or current_state == State.RESULTS:
			return
	
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
	
	_start_match()

func _start_match() -> void:
	current_state = State.PLAYING
	match_time_remaining = match_duration
	
	game_board.set_match_seed(match_seed)
	
	player.is_dead = false
	player.is_moving = false
	
	hazard_spawner.is_active = true
	hazard_spawner.spawn_timer.start(hazard_spawner.initial_delay)

# =====================
# GAME LOOP
# =====================

func _process(delta: float) -> void:
	if current_state != State.PLAYING:
		return
	
	match_time_remaining -= delta
	timer_label.text = _format_time(match_time_remaining)
	
	# Flash timer red in last 10 seconds
	if match_time_remaining <= 10.0:
		var pulse = abs(sin(match_time_remaining * 3.0))
		timer_label.add_theme_color_override("font_color", Color(1.0, pulse * 0.5 + 0.5, pulse * 0.5 + 0.5))
	
	if match_time_remaining <= 0.0:
		match_time_remaining = 0.0
		timer_label.text = "0:00"
		_end_match()

func _on_my_score_changed(new_score: int) -> void:
	if new_score > my_best_score:
		my_best_score = new_score
		my_score_label.text = str(my_best_score)
		
		var tween = create_tween()
		tween.tween_property(my_score_label, "scale", Vector2(1.3, 1.3), 0.05)
		tween.tween_property(my_score_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
		
		NetworkManager.send_score(my_best_score)

func _on_player_died_ranked() -> void:
	if current_state != State.PLAYING:
		return
	
	await get_tree().create_timer(1.0).timeout
	
	if not is_inside_tree() or current_state != State.PLAYING:
		return
	
	player.reset()
	game_board.reset()
	hazard_spawner.reset()
	
	# Invincibility flash
	var flash = create_tween()
	flash.set_loops(3)
	flash.tween_property(player, "modulate:a", 0.3, 0.1)
	flash.tween_property(player, "modulate:a", 1.0, 0.1)

# =====================
# MATCH END
# =====================

func _end_match() -> void:
	current_state = State.RESULTS
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	NetworkManager.send_match_end(my_best_score)
	_show_results()

func _show_results() -> void:
	_clear_result_content()
	result_container.visible = true
	result_container.modulate.a = 0
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)
	
	# Result text
	var result_lbl = Label.new()
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 56)
	result_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	result_lbl.add_theme_constant_override("shadow_offset_x", 3)
	result_lbl.add_theme_constant_override("shadow_offset_y", 3)
	
	if my_best_score > opponent_best_score:
		result_lbl.text = "VICTORY!"
		result_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	elif my_best_score < opponent_best_score:
		result_lbl.text = "DEFEAT"
		result_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		result_lbl.text = "DRAW"
		result_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
	vbox.add_child(result_lbl)
	
	_add_spacer(vbox, 20)
	
	# Score comparison
	var score_lbl = Label.new()
	score_lbl.text = str(my_best_score) + "  —  " + str(opponent_best_score)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 40)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_lbl)
	
	_add_spacer(vbox, 6)
	
	var names_lbl = Label.new()
	names_lbl.text = "YOU              " + opponent_name
	names_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names_lbl.add_theme_font_size_override("font_size", 15)
	names_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(names_lbl)
	
	_add_spacer(vbox, 20)
	
	# Seed
	var seed_lbl = Label.new()
	seed_lbl.text = "seed: " + str(match_seed)
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	vbox.add_child(seed_lbl)
	
	_add_spacer(vbox, 30)
	_add_result_hints(vbox)
	
	var fade = create_tween()
	fade.tween_property(result_container, "modulate:a", 1.0, 0.4)

func _show_disconnect_win() -> void:
	current_state = State.RESULTS
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	_clear_result_content()
	result_container.visible = true
	result_container.modulate.a = 0
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "OPPONENT LEFT"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	vbox.add_child(lbl)
	
	_add_spacer(vbox, 12)
	
	var sub = Label.new()
	sub.text = "You win by default!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(sub)
	
	_add_spacer(vbox, 40)
	_add_result_hints(vbox)
	
	var fade = create_tween()
	fade.tween_property(result_container, "modulate:a", 1.0, 0.4)

func _show_connection_lost() -> void:
	_clear_result_content()
	result_container.visible = true
	result_container.modulate.a = 0
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_container.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "CONNECTION LOST"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	vbox.add_child(lbl)
	
	_add_spacer(vbox, 35)
	_add_result_hints(vbox)
	
	var fade = create_tween()
	fade.tween_property(result_container, "modulate:a", 1.0, 0.4)

func _add_result_hints(vbox: VBoxContainer) -> void:
	var restart = Label.new()
	restart.text = "SPACE to play again"
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart.add_theme_font_size_override("font_size", 22)
	restart.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(restart)
	_pulse(restart, 0.6)
	
	_add_spacer(vbox, 8)
	_add_hint(vbox, "ESC for menu")

func _clear_result_content() -> void:
	for child in result_container.get_children():
		if child.name == "Overlay":
			continue
		result_container.remove_child(child)
		child.queue_free()

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	
	if event.keycode == KEY_ESCAPE:
		NetworkManager.disconnect_from_server()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	
	# Retry connection on error screen
	if current_state == State.CONNECTING and not NetworkManager.is_online():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_show_connecting()
			NetworkManager.connect_to_server()
			return
	
	# Results → back to lobby
	if current_state == State.RESULTS:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_back_to_lobby()

func _back_to_lobby() -> void:
	result_container.visible = false
	
	my_best_score = 0
	opponent_best_score = 0
	my_score_label.text = "0"
	opponent_score_label.text = "0"
	timer_label.text = _format_time(match_duration)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	
	player.reset()
	game_board.reset()
	hazard_spawner.reset()
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	
	if NetworkManager.is_online():
		NetworkManager.rejoin_lobby()
		# Will get lobby_updated → _show_lobby()
		current_state = State.CONNECTING  # Temporary until lobby_updated arrives
	else:
		_show_connecting()
		NetworkManager.connect_to_server()

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

func _add_title() -> void:
	var title = Label.new()
	title.text = "RANKED MATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	lobby_content.add_child(title)

func _add_hint(parent: Control, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	parent.add_child(lbl)

func _pulse(node: Control, duration: float = 0.6) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", 0.3, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
