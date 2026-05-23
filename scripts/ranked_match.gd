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
var opponent_elo: int = 1000
var opponent_player_id: String = ""
var my_best_score: int = 0
var opponent_best_score: int = 0
var last_elo_change: int = 0

# === SPECTATE / GHOST ===
const RESPAWN_TIMEOUT := 10.0
var _ghost_sprite: Sprite2D = null
var _ghost_slide_tween: Tween = null
var _is_spectating: bool = false

# === HUD LAYER ===
@onready var timer_label: Label             = $MatchHUD/TimerLabel
@onready var my_panel: PanelContainer       = $MatchHUD/MyPanel
@onready var my_score_label: Label          = $MatchHUD/MyPanel/VBox/MyScoreLabel
@onready var opp_panel: PanelContainer      = $MatchHUD/OppPanel
@onready var opponent_score_label: Label    = $MatchHUD/OppPanel/VBox/OppScoreLabel
@onready var opp_name_label: Label          = $MatchHUD/OppPanel/VBox/OppNameLabel
@onready var my_king_rect: TextureRect      = $MatchHUD/MyPanel/VBox/MyKingRect
@onready var opp_king_rect: TextureRect     = $MatchHUD/OppPanel/VBox/OppKingRect
@onready var countdown_label: Label         = $MatchHUD/CountdownLabel

# === LOBBY ===
@onready var lobby_container: Control       = $MatchHUD/LobbyContainer
@onready var lobby_content: VBoxContainer   = $MatchHUD/LobbyContainer/LobbyCenter/LobbyContent
@onready var error_flash: Label             = $MatchHUD/LobbyContainer/ErrorFlash

# === RESULTS ===
@onready var result_container: Control      = $MatchHUD/ResultContainer

# === SPECTATE ===
@onready var spectate_label: Label          = $MatchHUD/SpectateLabel

# === BACK BUTTON (Mobile) ===
@onready var back_button: Button            = $BackButtonLayer/BackButtonRoot/BackButton

# =====================
# LIFECYCLE
# =====================

func _ready() -> void:
	game_board = $GameBoard
	player = $Player
	hazard_spawner = $HazardSpawner

	player.died.connect(_on_player_died_ranked)
	game_board.score_changed.connect(_on_my_score_changed)

	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true

	_apply_styles()
	$MatchHUD/MyPanel/VBox/MyNameLabel.text = PlayerData.player_name
	back_button.pressed.connect(_on_back_button_pressed)
	_connect_signals()

	timer_label.text = _format_time(match_duration)
	_show_connecting()
	NetworkManager.connect_to_server()

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
	NetworkManager.match_result_received.connect(_on_match_result)
	NetworkManager.opponent_disconnected_sig.connect(_on_opponent_disconnected)
	NetworkManager.challenge_failed.connect(_on_challenge_failed)
	player.position_changed.connect(_on_player_moved)
	NetworkManager.opponent_ghost_updated.connect(_on_opponent_ghost_updated)

# =====================
# NETWORK CALLBACKS
# =====================

func _on_connected() -> void:
	if PlayerData.player_name.is_empty():
		PlayerData.player_name = "Player" + str(randi() % 1000)
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

func _on_match_started(seed_val: int, opp_name: String, opp_elo: int, opp_pid: String) -> void:
	match_seed = seed_val
	opponent_name = opp_name
	opponent_elo = opp_elo
	opponent_player_id = opp_pid
	opp_name_label.text = opp_name + " · " + str(opp_elo)
	_start_countdown()

func _on_opponent_score(best_score: int) -> void:
	if best_score <= opponent_best_score:
		return
	opponent_best_score = best_score
	opponent_score_label.text = str(opponent_best_score)

	# Flash the ghost bright orange when opponent scores
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		var ghost_flash := create_tween()
		ghost_flash.tween_property(_ghost_sprite, "modulate", Color(1.0, 0.6, 0.1, 0.9), 0.07)
		ghost_flash.tween_property(_ghost_sprite, "modulate", Color(0.45, 0.75, 1.0, 0.38), 0.35)

	# Score label: big pop, bounce back
	var tween := create_tween()
	tween.tween_property(opponent_score_label, "scale", Vector2(1.6, 1.6), 0.07)
	tween.tween_property(opponent_score_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)

func _on_match_result(result: String, my_score: int, opp_score: int,
		elo_change: int, opp_name: String, opp_elo_val: int, opp_pid: String) -> void:
	if elo_change == 0:
		last_elo_change = PlayerData.calculate_elo_change(PlayerData.elo, opp_elo_val, result)
	else:
		last_elo_change = elo_change

	opponent_name = opp_name
	opponent_elo = opp_elo_val
	opponent_player_id = opp_pid
	my_best_score = my_score
	opponent_best_score = opp_score
	PlayerData.apply_match_result(result, my_score, opp_score, opp_name, opp_elo_val, elo_change)
	_show_results()

func _on_opponent_disconnected(elo_change: int, my_score: int, opp_score: int,
		opp_name: String, opp_elo_val: int, opp_pid: String) -> void:
	if current_state == State.PLAYING or current_state == State.COUNTDOWN:
		# Calculate ELO client-side if server returned 0
		if elo_change == 0:
			last_elo_change = PlayerData.calculate_elo_change(PlayerData.elo, opp_elo_val, "win")
		else:
			last_elo_change = elo_change
		opponent_name = opp_name
		opponent_elo = opp_elo_val
		PlayerData.apply_match_result("win", my_score, opp_score, opp_name, opp_elo_val, elo_change)
		_show_disconnect_win()

func _on_challenge_failed(msg: String) -> void:
	if current_state != State.LOBBY:
		return
	_flash_error(msg)

# =====================
# STYLES
# =====================

func _apply_styles() -> void:
	# ── MY panel (green) ──
	var my_color := Color(0.0, 1.0, 0.5)
	var my_style := StyleBoxFlat.new()
	my_style.bg_color = Color(0.0, 0.6, 0.3, 0.13)
	my_style.set_corner_radius_all(12)
	my_style.set_content_margin_all(10)
	my_style.border_color = Color(0.0, 1.0, 0.5, 0.65)
	my_style.set_border_width_all(2)
	my_panel.add_theme_stylebox_override("panel", my_style)

	$MatchHUD/MyPanel/VBox/MyNameLabel.add_theme_color_override("font_color", my_color.darkened(0.1))
	$MatchHUD/MyPanel/VBox/MyNameLabel.add_theme_font_size_override("font_size", 14)
	$MatchHUD/MyPanel/VBox.add_theme_constant_override("separation", 4)

	var my_ls := LabelSettings.new()
	my_ls.font_size = 72
	my_ls.font_color = my_color
	my_ls.outline_size = 3
	my_ls.outline_color = Color(0.0, 0.25, 0.12)
	my_ls.shadow_color = Color(my_color.r, my_color.g, my_color.b, 0.55)
	my_ls.shadow_size = 10
	my_ls.shadow_offset = Vector2.ZERO
	my_score_label.label_settings = my_ls

	my_king_rect.texture = load(GameSettings.get_player_king_texture())
	my_king_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	my_king_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# ── OPP panel (red-orange) ──
	var opp_color := Color(1.0, 0.38, 0.2)
	var opp_style := StyleBoxFlat.new()
	opp_style.bg_color = Color(0.7, 0.15, 0.0, 0.13)
	opp_style.set_corner_radius_all(12)
	opp_style.set_content_margin_all(10)
	opp_style.border_color = Color(1.0, 0.38, 0.2, 0.65)
	opp_style.set_border_width_all(2)
	opp_panel.add_theme_stylebox_override("panel", opp_style)

	$MatchHUD/OppPanel/VBox/OppNameLabel.add_theme_color_override("font_color", opp_color.darkened(0.1))
	$MatchHUD/OppPanel/VBox/OppNameLabel.add_theme_font_size_override("font_size", 14)
	$MatchHUD/OppPanel/VBox.add_theme_constant_override("separation", 4)

	var opp_ls := LabelSettings.new()
	opp_ls.font_size = 72
	opp_ls.font_color = opp_color
	opp_ls.outline_size = 3
	opp_ls.outline_color = Color(0.3, 0.05, 0.0)
	opp_ls.shadow_color = Color(opp_color.r, opp_color.g, opp_color.b, 0.55)
	opp_ls.shadow_size = 10
	opp_ls.shadow_offset = Vector2.ZERO
	opponent_score_label.label_settings = opp_ls

	var opp_tex_path: String = "res://assets/king1.png" if GameSettings.player_is_white else "res://assets/king.png"
	opp_king_rect.texture = load(opp_tex_path)
	opp_king_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	opp_king_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# ── Back button ──
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	btn_normal.set_corner_radius_all(12)
	btn_normal.border_color = Color(0.3, 0.3, 0.4, 0.9)
	btn_normal.set_border_width_all(2)
	back_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	btn_hover.set_corner_radius_all(12)
	btn_hover.border_color = Color(0.45, 0.45, 0.55, 1.0)
	btn_hover.set_border_width_all(2)
	back_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	btn_pressed.set_corner_radius_all(12)
	back_button.add_theme_stylebox_override("pressed", btn_pressed)
	back_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# =====================
# LOBBY SCREENS
# =====================

func _clear_lobby() -> void:
	for child in lobby_content.get_children():
		lobby_content.remove_child(child)
		child.queue_free()

func _set_match_hud(show: bool) -> void:
	timer_label.visible = show
	my_panel.visible = show
	opp_panel.visible = show

func _show_connecting() -> void:
	current_state = State.CONNECTING
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud(false)
	countdown_label.visible = false

	_clear_lobby()
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
	current_state = State.CONNECTING
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud(false)
	countdown_label.visible = false

	_clear_lobby()
	_add_title()
	_add_spacer(lobby_content, 25)

	var err_lbl = Label.new()
	err_lbl.text = msg
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_size_override("font_size", 20)
	err_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	lobby_content.add_child(err_lbl)

	_add_spacer(lobby_content, 25)
	_add_hint(lobby_content, "SPACE to retry  •  ESC to go back")

func _show_lobby(players_list: Array, total_online: int) -> void:
	current_state = State.LOBBY
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud(false)
	countdown_label.visible = false

	_clear_lobby()
	_add_title()
	_add_spacer(lobby_content, 6)

	# My identity line (no title, just name + ELO)
	var my_info = Label.new()
	my_info.text = PlayerData.player_name + "  •  " + str(PlayerData.elo) + " ELO"
	my_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	my_info.add_theme_font_size_override("font_size", 15)
	my_info.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55))
	lobby_content.add_child(my_info)

	_add_spacer(lobby_content, 4)

	var count_lbl = Label.new()
	count_lbl.text = str(total_online) + " player" + ("s" if total_online != 1 else "") + " online"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	lobby_content.add_child(count_lbl)

	_add_spacer(lobby_content, 16)

	# Filter out self using session_id (server-side ID)
	var others: Array = []
	for p in players_list:
		if p.get("id", -1) != NetworkManager.session_id:
			others.append(p)

	if others.is_empty():
		var wait_lbl = Label.new()
		wait_lbl.text = "Waiting for an opponent..."
		wait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wait_lbl.add_theme_font_size_override("font_size", 22)
		wait_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		lobby_content.add_child(wait_lbl)
		_pulse(wait_lbl, 0.8)
	else:
		var hint = Label.new()
		hint.text = "Click a player to challenge:"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		lobby_content.add_child(hint)
		_add_spacer(lobby_content, 10)

		for p in others:
			var btn = _create_player_button(p.get("name", "???"), p.get("elo", 1000), p.get("id", -1))
			lobby_content.add_child(btn)
			_add_spacer(lobby_content, 6)

	_add_spacer(lobby_content, 20)
	_add_hint(lobby_content, "ESC to go back")

func _create_player_button(pname: String, pelo: int, pid: int) -> Button:
	var btn = Button.new()
	btn.text = "  " + pname + "  (" + str(pelo) + ")  "
	btn.custom_minimum_size = Vector2(280, 44)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.16)
	normal.set_corner_radius_all(6)
	normal.border_color = Color(0.25, 0.25, 0.35)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.14, 0.22)
	hover.set_corner_radius_all(6)
	hover.border_color = Color(0.85, 0.55, 0.1)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.22, 0.18, 0.1)
	pressed.set_corner_radius_all(6)
	pressed.border_color = Color(0.85, 0.55, 0.1)
	pressed.set_border_width_all(2)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover.duplicate())

	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.7, 0.3))

	btn.pressed.connect(_on_player_button_pressed.bind(pid))
	return btn

func _on_player_button_pressed(pid: int) -> void:
	if current_state != State.LOBBY:
		return
	NetworkManager.challenge_player(pid)

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
	_set_match_hud(true)

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
	_create_ghost()

# =====================
# GAME LOOP
# =====================

func _process(delta: float) -> void:
	if current_state != State.PLAYING:
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
	_is_spectating = true
	spectate_label.visible = true

	# Count down second by second — board + ghost stay active so player can watch
	var seconds_left := int(RESPAWN_TIMEOUT)
	while seconds_left > 0:
		spectate_label.text = "Respawning in " + str(seconds_left) + "s..."
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or current_state != State.PLAYING:
			spectate_label.visible = false
			_is_spectating = false
			return
		seconds_left -= 1

	spectate_label.visible = false
	_is_spectating = false

	# Respawn — score is NOT reset (10 s wait is the punishment)
	player.reset()
	game_board.reset()
	hazard_spawner.reset()

	player.modulate.a = 0.0
	var flash := create_tween()
	flash.tween_property(player, "modulate:a", 1.0, 0.4)

# =====================
# MATCH END
# =====================

func _end_match() -> void:
	current_state = State.RESULTS
	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()
		_ghost_sprite = null
	NetworkManager.send_match_end(my_best_score)
	# Results will be shown when _on_match_result is called by the server

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

	_add_spacer(vbox, 16)

	var score_lbl = Label.new()
	score_lbl.text = str(my_best_score) + "  —  " + str(opponent_best_score)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 40)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_lbl)

	_add_spacer(vbox, 4)

	var names_lbl = Label.new()
	names_lbl.text = "YOU              " + opponent_name
	names_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names_lbl.add_theme_font_size_override("font_size", 15)
	names_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(names_lbl)

	_add_spacer(vbox, 18)

	var elo_lbl = Label.new()
	var elo_sign = "+" if last_elo_change >= 0 else ""
	elo_lbl.text = elo_sign + str(last_elo_change) + " ELO  (" + str(PlayerData.elo) + ")"
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", 24)
	if last_elo_change > 0:
		elo_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	elif last_elo_change < 0:
		elo_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		elo_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
	vbox.add_child(elo_lbl)

	_add_spacer(vbox, 18)

	var seed_lbl = Label.new()
	seed_lbl.text = "seed: " + str(match_seed)
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.add_theme_font_size_override("font_size", 12)
	seed_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	vbox.add_child(seed_lbl)

	_add_spacer(vbox, 25)
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

	_add_spacer(vbox, 8)

	var sub = Label.new()
	sub.text = "You win by default!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(sub)

	_add_spacer(vbox, 12)

	var elo_lbl = Label.new()
	elo_lbl.text = "+" + str(last_elo_change) + " ELO  (" + str(PlayerData.elo) + ")"
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", 24)
	elo_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(elo_lbl)

	_add_spacer(vbox, 30)
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
		SoundManager.play("click")
		NetworkManager.disconnect_from_server()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	if current_state == State.CONNECTING and not NetworkManager.is_online():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_show_connecting()
			NetworkManager.connect_to_server()
			return

	if current_state == State.RESULTS:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_back_to_lobby()

func _back_to_lobby() -> void:
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()
		_ghost_sprite = null
	result_container.visible = false

	my_best_score = 0
	opponent_best_score = 0
	last_elo_change = 0
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
		current_state = State.CONNECTING
	else:
		_show_connecting()
		NetworkManager.connect_to_server()

# =====================
# GHOST PLAYER
# =====================

func _create_ghost() -> void:
	if _ghost_sprite and is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()

	# Opponent uses the opposite king texture
	var opp_tex_path: String = "res://assets/king1.png" if GameSettings.player_is_white else "res://assets/king.png"
	var opp_tex: Texture2D = load(opp_tex_path)

	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.texture = opp_tex

	var tex_size := opp_tex.get_size()
	var tile_size: float = game_board.tile_size
	var target_size := tile_size * 0.8
	var scale_factor: float = target_size / max(tex_size.x, tex_size.y)
	_ghost_sprite.scale = Vector2(scale_factor, scale_factor)
	_ghost_sprite.modulate = Color(0.45, 0.75, 1.0, 0.38)  # cyan-blue, semi-transparent

	# Start at board center (will move when first ghost_pos arrives)
	_ghost_sprite.position = game_board.grid_to_world(Vector2i(game_board.grid_size / 2, game_board.grid_size / 2))

	# Insert BEFORE the player node so it renders behind the player at the same z_index
	add_child(_ghost_sprite)
	move_child(_ghost_sprite, player.get_index())

func _on_player_moved(new_pos: Vector2i) -> void:
	if current_state != State.PLAYING:
		return
	print("[GHOST] sending my pos: ", new_pos.x, ", ", new_pos.y)
	NetworkManager.send_ghost_pos(new_pos.x, new_pos.y)

func _on_opponent_ghost_updated(x: int, y: int) -> void:
	print("[GHOST] received opponent pos: ", x, ", ", y)
	if not (_ghost_sprite and is_instance_valid(_ghost_sprite)):
		print("[GHOST] sprite missing, ignoring")
		return
	var target_pos: Vector2 = game_board.grid_to_world(Vector2i(x, y))
	if _ghost_slide_tween and _ghost_slide_tween.is_valid():
		_ghost_slide_tween.kill()
	_ghost_slide_tween = create_tween()
	_ghost_slide_tween.tween_property(_ghost_sprite, "position", target_pos, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", 0.3, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func _on_back_button_pressed() -> void:
	SoundManager.play("click")
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
