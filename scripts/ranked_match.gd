extends Node2D

# === MATCH SETTINGS ===
@export var countdown_duration: int = 3

const MODE_DURATIONS := {"bullet": 90.0, "blitz": 180.0, "rapid": 300.0}
const MODE_LABELS    := {"bullet": "BULLET · 1:30", "blitz": "BLITZ · 3:00", "rapid": "RAPID · 5:00"}

# === STATE ===
enum State { CONNECTING, LOBBY, COUNTDOWN, PLAYING, RESULTS }
var current_state: State = State.CONNECTING
var _time_mode: String = "bullet"
var match_duration: float = 90.0
var _connect_retries: int = 0
var _match_server_time: float = 0.0
var _opponent_hat: String = ""

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

# === QUEUE ANIMATION ===
var _queue_start_time: int = 0
var _finding_label: Label = null
var _elo_range_label: Label = null
var _queue_timer_label: Label = null
var _dot_labels: Array = []

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

	_time_mode = GameSettings.ranked_time_mode
	match_duration = MODE_DURATIONS.get(_time_mode, 90.0)

	player.died.connect(_on_player_died_ranked)
	game_board.score_changed.connect(_on_my_score_changed)

	hazard_spawner.is_active = false
	hazard_spawner.spawn_timer.stop()
	player.is_dead = true

	_apply_styles()
	$ScoreUI.visible = false   # Solo HUD — not needed in ranked (panels show scores)
	$MatchHUD/MyPanel/VBox/MyNameLabel.text = PlayerData.player_name
	back_button.pressed.connect(_on_back_button_pressed)
	_connect_signals()

	# Screen shake
	game_board.player_hit.connect(func(): $Camera2D.shake(5.0, 0.20))
	game_board.score_changed.connect(func(_s): $Camera2D.shake(1.8, 0.10))

	# Adaptive layout (portrait ↔ landscape)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

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
	NetworkManager.match_started.connect(_on_match_started)
	NetworkManager.opponent_score_updated.connect(_on_opponent_score)
	NetworkManager.match_result_received.connect(_on_match_result)
	NetworkManager.opponent_disconnected_sig.connect(_on_opponent_disconnected)
	player.position_changed.connect(_on_player_moved)
	NetworkManager.opponent_ghost_updated.connect(_on_opponent_ghost_updated)

# =====================
# NETWORK CALLBACKS
# =====================

func _on_connected() -> void:
	if PlayerData.player_name.is_empty():
		PlayerData.player_name = "Player" + str(randi() % 1000)
	NetworkManager.queue_for_match(_time_mode)
	_show_finding_opponent()

func _on_connection_failed() -> void:
	if _connect_retries < 2:
		_connect_retries += 1
		_show_error("Connecting to server... (attempt " + str(_connect_retries + 1) + " of 3)")
		await get_tree().create_timer(4.0).timeout
		if current_state == State.CONNECTING:
			NetworkManager.connect_to_server()
	else:
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

func _on_match_started(seed_val: int, opp_name: String, opp_elo: int, opp_pid: String, time_mode: String, opp_hat: String, server_time: float) -> void:
	_time_mode = time_mode
	match_duration = MODE_DURATIONS.get(time_mode, 90.0)
	match_time_remaining = match_duration
	match_seed = seed_val
	opponent_name = opp_name
	opponent_elo = opp_elo
	opponent_player_id = opp_pid
	_match_server_time = server_time
	_opponent_hat = opp_hat
	_finding_label = null
	_elo_range_label = null
	_queue_timer_label = null
	_dot_labels.clear()
	opp_name_label.text = opp_name + " · " + str(opp_elo)
	_add_hat_overlay(my_king_rect, PlayerData.equipped_hat)
	_add_hat_overlay(opp_king_rect, opp_hat)
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
		last_elo_change = PlayerData.calculate_elo_change(PlayerData.get_elo_for_mode(_time_mode), opp_elo_val, result)
	else:
		last_elo_change = elo_change

	opponent_name = opp_name
	opponent_elo = opp_elo_val
	opponent_player_id = opp_pid
	my_best_score = my_score
	opponent_best_score = opp_score
	PlayerData.apply_match_result(result, my_score, opp_score, opp_name, opp_elo_val, elo_change, _time_mode)
	_show_results()

func _on_opponent_disconnected(elo_change: int, my_score: int, opp_score: int,
		opp_name: String, opp_elo_val: int, opp_pid: String) -> void:
	if current_state == State.PLAYING or current_state == State.COUNTDOWN:
		if elo_change == 0:
			last_elo_change = PlayerData.calculate_elo_change(PlayerData.get_elo_for_mode(_time_mode), opp_elo_val, "win")
		else:
			last_elo_change = elo_change
		opponent_name = opp_name
		opponent_elo = opp_elo_val
		PlayerData.apply_match_result("win", my_score, opp_score, opp_name, opp_elo_val, elo_change, _time_mode)
		_show_disconnect_win()

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
	$MatchHUD/MyPanel/VBox/MyNameLabel.add_theme_font_size_override("font_size", 18)
	$MatchHUD/MyPanel/VBox.add_theme_constant_override("separation", 8)

	var my_ls := LabelSettings.new()
	my_ls.font_size = 56
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
	my_king_rect.custom_minimum_size = Vector2(56, 56)
	my_king_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	my_king_rect.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	my_king_rect.clip_contents = false

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
	$MatchHUD/OppPanel/VBox/OppNameLabel.add_theme_font_size_override("font_size", 18)
	$MatchHUD/OppPanel/VBox.add_theme_constant_override("separation", 8)

	var opp_ls := LabelSettings.new()
	opp_ls.font_size = 56
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
	opp_king_rect.custom_minimum_size = Vector2(56, 56)
	opp_king_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	opp_king_rect.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	opp_king_rect.clip_contents = false

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
# ADAPTIVE LAYOUT
# =====================

func _apply_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var is_portrait := vp_size.y > vp_size.x

	var safe_top := 0
	if GameSettings.is_mobile:
		var r := DisplayServer.get_display_safe_area()
		safe_top = maxi(r.position.y, 0)

	# Push lobby card below the phone camera notch
	var lobby_center := $MatchHUD/LobbyContainer/LobbyCenter as Control
	if is_instance_valid(lobby_center):
		lobby_center.offset_top = float(safe_top)

	if is_portrait:
		# Compact top-corner strips — panels sit in the space above/below the board
		my_panel.set_anchor(SIDE_LEFT,   0.0, false, false)
		my_panel.set_anchor(SIDE_TOP,    0.0, false, false)
		my_panel.set_anchor(SIDE_RIGHT,  0.0, false, false)
		my_panel.set_anchor(SIDE_BOTTOM, 0.0, false, false)
		my_panel.offset_left   = 8.0
		my_panel.offset_top    = 8.0 + safe_top
		my_panel.offset_right  = 160.0
		my_panel.offset_bottom = 98.0 + safe_top
		my_panel.custom_minimum_size = Vector2(0.0, 0.0)

		opp_panel.set_anchor(SIDE_LEFT,   1.0, false, false)
		opp_panel.set_anchor(SIDE_TOP,    0.0, false, false)
		opp_panel.set_anchor(SIDE_RIGHT,  1.0, false, false)
		opp_panel.set_anchor(SIDE_BOTTOM, 0.0, false, false)
		opp_panel.offset_left   = -160.0
		opp_panel.offset_top    = 8.0 + safe_top
		opp_panel.offset_right  = -8.0
		opp_panel.offset_bottom = 98.0 + safe_top
		opp_panel.custom_minimum_size = Vector2(0.0, 0.0)

		timer_label.offset_top    = 12.0 + safe_top
		timer_label.offset_bottom = 52.0 + safe_top

		spectate_label.offset_top    = 55.0 + safe_top
		spectate_label.offset_bottom = 88.0 + safe_top

		# Shrink score font to fit the compact strip
		if my_score_label.label_settings:
			my_score_label.label_settings.font_size = 32
		if opponent_score_label.label_settings:
			opponent_score_label.label_settings.font_size = 32
		# King icon is too tall for the compact portrait panel — hide it
		my_king_rect.visible  = false
		opp_king_rect.visible = false

		# Back button: top-left, same as landscape
		back_button.anchor_top    = 0.0
		back_button.anchor_bottom = 0.0
		back_button.anchor_left   = 0.0
		back_button.anchor_right  = 0.0
		back_button.offset_left   = 20.0
		back_button.offset_right  = 140.0
		back_button.offset_top    = 20.0 + safe_top
		back_button.offset_bottom = 80.0 + safe_top
	else:
		# Landscape: panels span full height starting below the back button
		my_panel.set_anchor(SIDE_LEFT,   0.0, false, false)
		my_panel.set_anchor(SIDE_TOP,    0.0, false, false)
		my_panel.set_anchor(SIDE_RIGHT,  0.0, false, false)
		my_panel.set_anchor(SIDE_BOTTOM, 1.0, false, false)
		my_panel.offset_left   = 8.0
		my_panel.offset_top    = 92.0 + safe_top
		my_panel.offset_right  = 158.0
		my_panel.offset_bottom = -20.0
		my_panel.custom_minimum_size = Vector2(0.0, 0.0)

		opp_panel.set_anchor(SIDE_LEFT,   1.0, false, false)
		opp_panel.set_anchor(SIDE_TOP,    0.0, false, false)
		opp_panel.set_anchor(SIDE_RIGHT,  1.0, false, false)
		opp_panel.set_anchor(SIDE_BOTTOM, 1.0, false, false)
		opp_panel.offset_left   = -158.0
		opp_panel.offset_top    = 92.0 + safe_top
		opp_panel.offset_right  = -8.0
		opp_panel.offset_bottom = -20.0
		opp_panel.custom_minimum_size = Vector2(0.0, 0.0)

		timer_label.offset_top    = 12.0 + safe_top
		timer_label.offset_bottom = 52.0 + safe_top

		spectate_label.offset_top    = 55.0 + safe_top
		spectate_label.offset_bottom = 88.0 + safe_top

		# Restore landscape score font
		if my_score_label.label_settings:
			my_score_label.label_settings.font_size = 56
		if opponent_score_label.label_settings:
			opponent_score_label.label_settings.font_size = 56
		# Restore king icon visibility in landscape
		my_king_rect.visible  = true
		opp_king_rect.visible = true

		# Back button: top-left with safe area offset
		back_button.anchor_top    = 0.0
		back_button.anchor_bottom = 0.0
		back_button.anchor_left   = 0.0
		back_button.anchor_right  = 0.0
		back_button.offset_left   = 20.0
		back_button.offset_right  = 140.0
		back_button.offset_top    = 20.0 + safe_top
		back_button.offset_bottom = 80.0 + safe_top

# =====================
# LOBBY SCREENS
# =====================

func _clear_lobby() -> void:
	for child in lobby_content.get_children():
		child.queue_free()  # queue_free removes from parent automatically; don't call remove_child first or looping tweens will log "!is_inside_tree"

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
	_dot_labels.clear()

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.07, 0.13)
	cs.set_corner_radius_all(18)
	cs.border_color = Color(0.28, 0.32, 0.50, 0.6)
	cs.set_border_width_all(2)
	cs.set_content_margin_all(42)
	card.add_theme_stylebox_override("panel", cs)
	lobby_content.add_child(card)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	card.add_child(inner)

	var title = Label.new()
	title.text = "RANKED MATCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	inner.add_child(title)

	_add_spacer(inner, 28)
	_add_divider(inner, Color(0.85, 0.55, 0.1), 0.22)
	_add_spacer(inner, 28)

	var lbl = Label.new()
	lbl.text = "Connecting to server..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.62, 0.78))
	inner.add_child(lbl)
	_pulse(lbl)

	_add_spacer(inner, 28)
	_add_hint(inner, "ESC  ·  go back")

func _show_error(msg: String) -> void:
	current_state = State.CONNECTING
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud(false)
	countdown_label.visible = false
	_clear_lobby()
	_dot_labels.clear()

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 0)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.09, 0.05, 0.05)
	cs.set_corner_radius_all(18)
	cs.border_color = Color(0.85, 0.3, 0.3, 0.65)
	cs.set_border_width_all(2)
	cs.set_content_margin_all(42)
	card.add_theme_stylebox_override("panel", cs)
	lobby_content.add_child(card)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	card.add_child(inner)

	var icon_lbl = Label.new()
	icon_lbl.text = "⚠"
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 44)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35))
	inner.add_child(icon_lbl)

	_add_spacer(inner, 16)

	var err_lbl = Label.new()
	err_lbl.text = msg
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.custom_minimum_size = Vector2(360, 0)
	err_lbl.add_theme_font_size_override("font_size", 18)
	err_lbl.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
	inner.add_child(err_lbl)

	_add_spacer(inner, 28)
	_add_hint(inner, "SPACE  ·  retry          ESC  ·  go back")

func _show_finding_opponent() -> void:
	current_state = State.LOBBY
	lobby_container.visible = true
	result_container.visible = false
	_set_match_hud(false)
	countdown_label.visible = false
	_clear_lobby()
	_dot_labels.clear()
	_queue_start_time = Time.get_ticks_msec()

	# ── Mode-specific theming ──
	const MODE_ICONS := {"bullet": "⚡", "blitz": "🔥", "rapid": "♟"}
	const MODE_TIMES := {"bullet": "1 : 30  PER SIDE", "blitz": "3 : 00  PER SIDE", "rapid": "5 : 00  PER SIDE"}
	var mode_color: Color
	match _time_mode:
		"blitz": mode_color = Color(0.30, 0.62, 1.00)
		"rapid": mode_color = Color(0.22, 0.88, 0.48)
		_:       mode_color = Color(1.00, 0.78, 0.12)
	var mode_icon: String = MODE_ICONS.get(_time_mode, "⚡")
	var mode_time: String = MODE_TIMES.get(_time_mode, "1 : 30  PER SIDE")

	# ── Card ──
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 0)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.07, 0.13)
	cs.set_corner_radius_all(20)
	cs.border_color = Color(mode_color.r, mode_color.g, mode_color.b, 0.65)
	cs.set_border_width_all(2)
	cs.set_content_margin_all(44)
	card.add_theme_stylebox_override("panel", cs)
	lobby_content.add_child(card)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	card.add_child(inner)

	# ── Mode icon (pulsing) ──
	var icon_lbl = Label.new()
	icon_lbl.text = mode_icon
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 62)
	inner.add_child(icon_lbl)
	_pulse(icon_lbl, 1.4)

	_add_spacer(inner, 8)

	# ── Mode name ──
	var name_lbl = Label.new()
	name_lbl.text = _time_mode.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 52)
	name_lbl.add_theme_color_override("font_color", mode_color)
	inner.add_child(name_lbl)

	# ── Time control ──
	var time_lbl = Label.new()
	time_lbl.text = mode_time
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 16)
	time_lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.55))
	inner.add_child(time_lbl)

	_add_spacer(inner, 26)
	_add_divider(inner, mode_color, 0.22)
	_add_spacer(inner, 22)

	# ── Your ELO ──
	var elo_row = HBoxContainer.new()
	elo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	elo_row.add_theme_constant_override("separation", 14)
	inner.add_child(elo_row)

	var elo_key = Label.new()
	elo_key.text = "YOUR ELO"
	elo_key.add_theme_font_size_override("font_size", 16)
	elo_key.add_theme_color_override("font_color", Color(0.40, 0.40, 0.55))
	elo_row.add_child(elo_key)

	var elo_val = Label.new()
	elo_val.text = str(PlayerData.get_elo_for_mode(_time_mode))
	elo_val.add_theme_font_size_override("font_size", 30)
	elo_val.add_theme_color_override("font_color", mode_color)
	elo_row.add_child(elo_val)

	_add_spacer(inner, 26)
	_add_divider(inner, mode_color, 0.15)
	_add_spacer(inner, 26)

	# ── "SEARCHING FOR OPPONENT" ──
	var search_lbl = Label.new()
	search_lbl.text = "SEARCHING FOR OPPONENT"
	search_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	search_lbl.add_theme_font_size_override("font_size", 19)
	search_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.88))
	inner.add_child(search_lbl)

	_add_spacer(inner, 16)

	# ── 3 animated pulsing dots (sine-animated in _process) ──
	var dot_row = HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.add_theme_constant_override("separation", 20)
	inner.add_child(dot_row)

	for _i in 3:
		var dot = Label.new()
		dot.text = "●"
		dot.add_theme_font_size_override("font_size", 30)
		dot.add_theme_color_override("font_color", mode_color)
		dot_row.add_child(dot)
		_dot_labels.append(dot)

	_add_spacer(inner, 22)

	# ── ELO search range (updates in _process) ──
	_elo_range_label = Label.new()
	_elo_range_label.text = "±100 ELO  search range"
	_elo_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elo_range_label.add_theme_font_size_override("font_size", 15)
	_elo_range_label.add_theme_color_override("font_color", Color(0.40, 0.40, 0.52))
	inner.add_child(_elo_range_label)

	_add_spacer(inner, 6)

	# ── Queue timer (updates in _process) ──
	_queue_timer_label = Label.new()
	_queue_timer_label.text = "0:00"
	_queue_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_queue_timer_label.add_theme_font_size_override("font_size", 14)
	_queue_timer_label.add_theme_color_override("font_color", Color(0.30, 0.30, 0.42))
	inner.add_child(_queue_timer_label)

	_add_spacer(inner, 26)
	_add_divider(inner, mode_color, 0.14)
	_add_spacer(inner, 18)

	_add_hint(inner, "ESC  ·  cancel and go back")

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

func _add_hat_overlay(king_rect: TextureRect, hat_id: String) -> void:
	# Remove any previous hat overlay
	for c in king_rect.get_children():
		c.queue_free()
	if hat_id.is_empty() or not PlayerData.SHOP_HATS.has(hat_id):
		return

	# Mirror player.gd proportions:
	#   hat_base_pos_tiles  = Vector2(0, -45)  (hat center above king center)
	#   hat_base_scale      = 0.40             (hat = 40% of tile)
	#   menu preview tile   = 80px
	# We scale to king_rect.custom_minimum_size.y (56px).
	var king_size: float  = king_rect.custom_minimum_size.y
	var scale_factor: float = king_size / 80.0   # 56/80 = 0.70
	var tweaks: Dictionary  = PlayerData.HAT_TWEAKS.get(hat_id, {}) as Dictionary
	var scale_mul: float    = float(tweaks.get("scale", 1.0))
	var hat_size: float     = king_size * 0.40 * scale_mul
	var y_offset: float     = -45.0 * scale_factor                              # above king center
	var pos_tweak: Vector2  = (tweaks.get("pos", Vector2.ZERO) as Vector2) * scale_factor
	var x_offset: float     = pos_tweak.x

	var hat_spr := TextureRect.new()
	hat_spr.texture      = load(PlayerData.SHOP_HATS[hat_id]["tex"])
	hat_spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hat_spr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	hat_spr.custom_minimum_size = Vector2(hat_size, hat_size)
	# Anchor at center of king_rect; offset upward by y_offset
	hat_spr.set_anchors_preset(Control.PRESET_CENTER)
	hat_spr.offset_left   = -hat_size * 0.5 + x_offset
	hat_spr.offset_right  =  hat_size * 0.5 + x_offset
	hat_spr.offset_top    = y_offset - hat_size * 0.5
	hat_spr.offset_bottom = y_offset + hat_size * 0.5
	hat_spr.rotation_degrees = float(tweaks.get("rot_deg", 0.0))
	hat_spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hat_spr.z_index = 2
	king_rect.add_child(hat_spr)

func _start_match() -> void:
	current_state = State.PLAYING
	# Sync timer to server clock so both clients show the same time.
	# server_time is set when the server sent match_start to both players.
	if _match_server_time > 0.0:
		var elapsed := Time.get_unix_time_from_system() - _match_server_time
		match_time_remaining = maxf(match_duration - elapsed, 1.0)
	else:
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
	# Animate pulsing dots + update live labels while searching
	if current_state == State.LOBBY:
		var t := float(Time.get_ticks_msec()) / 1000.0
		for i in _dot_labels.size():
			if is_instance_valid(_dot_labels[i]):
				var phase := t * 2.8 + i * 1.05
				_dot_labels[i].modulate.a = 0.15 + 0.85 * (0.5 + 0.5 * sin(phase))
		var secs := int(float(Time.get_ticks_msec() - _queue_start_time) / 1000.0)
		if is_instance_valid(_queue_timer_label):
			var m := secs / 60
			var s := secs % 60
			_queue_timer_label.text = str(m) + ":" + ("0" if s < 10 else "") + str(s)
		if is_instance_valid(_elo_range_label):
			var range_val := int(100 + 50 * (float(secs) / 10.0))
			_elo_range_label.text = "±" + str(range_val) + " ELO  search range"
		return

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

	# Respawn — score and board are NOT reset (10 s wait is the punishment)
	player.reset()
	player.invincible = true
	hazard_spawner.resume()

	player.modulate.a = 0.0
	var flash := create_tween()
	flash.tween_property(player, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(1.5).timeout
	if is_inside_tree() and current_state == State.PLAYING:
		player.invincible = false

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
	elo_lbl.text = elo_sign + str(last_elo_change) + " ELO  (" + _time_mode.to_upper() + " " + str(PlayerData.get_elo_for_mode(_time_mode)) + ")"
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
	elo_lbl.text = "+" + str(last_elo_change) + " ELO  (" + _time_mode.to_upper() + " " + str(PlayerData.get_elo_for_mode(_time_mode)) + ")"
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
		child.queue_free()  # don't call remove_child first — looping tweens on freed nodes cause "!is_inside_tree" errors

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_ESCAPE:
		SoundManager.play("click")
		NetworkManager.leave_queue()
		NetworkManager.disconnect_from_server()
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")
		return

	if current_state == State.CONNECTING and not NetworkManager.is_online():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_show_connecting()
			NetworkManager.connect_to_server()
			return

	if current_state == State.RESULTS:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_back_to_queue()

func _back_to_queue() -> void:
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
		NetworkManager.queue_for_match(_time_mode)
		_show_finding_opponent()
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
	var s: int = maxi(0, int(ceil(seconds)))
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
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.48))
	parent.add_child(lbl)

func _add_divider(parent: Control, color: Color, alpha: float = 0.2) -> void:
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	div.color = Color(color.r, color.g, color.b, alpha)
	parent.add_child(div)

func _pulse(node: Control, duration: float = 0.6) -> void:
	var tween = node.create_tween()
	tween.set_loops()
	tween.tween_property(node, "modulate:a", 0.3, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE)

func _on_back_button_pressed() -> void:
	SoundManager.play("click")
	NetworkManager.leave_queue()
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/mode_select.tscn")
