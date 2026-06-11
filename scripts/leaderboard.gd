extends Node2D
## Leaderboard — shows top players by ELO.
## Click a player to see their full profile + match history.

var hud: CanvasLayer
var scroll_content: VBoxContainer
var profile_popup: Control
var loading_label: Label
var back_button_layer: CanvasLayer
var _scroll: ScrollContainer = null
var _profile_scroll: ScrollContainer = null

var _all_players: Array = []
var _active_tab: String = "solo"
var _active_elo_mode: String = "bullet"
var _elo_tab_btn: Button
var _solo_tab_btn: Button
var _elo_mode_row: HBoxContainer
var _bullet_btn: Button
var _blitz_btn: Button
var _rapid_btn: Button

func _ready() -> void:
	_setup_ui()
	_setup_back_button()

	# Restore the previously selected tab and ELO sub-mode
	_active_tab = GameSettings.leaderboard_tab
	_active_elo_mode = GameSettings.leaderboard_elo_mode
	_style_tab_button(_elo_tab_btn, _active_tab == "elo")
	_style_tab_button(_solo_tab_btn, _active_tab == "solo")
	_elo_mode_row.visible = (_active_tab == "elo")
	_update_elo_mode_buttons()

	PlayerData.leaderboard_loaded.connect(_on_leaderboard_loaded)
	PlayerData.player_profile_loaded.connect(_on_profile_loaded)
	var sort_field = "elo_" + _active_elo_mode if _active_tab == "elo" else "solo_highscore"
	PlayerData.load_leaderboard(sort_field)

# =====================
# UI SETUP
# =====================

func _setup_ui() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	# Compute safe-area top offset once (pushes all near-top UI below notch/status bar)
	var safe_top := 0
	if GameSettings.is_mobile:
		var r := DisplayServer.get_display_safe_area()
		safe_top = maxi(r.position.y, 72)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08, 0.95)
	hud.add_child(bg)

	# Header background strip + bottom divider
	var header_h := 230 + safe_top if GameSettings.is_mobile else 192
	var header_bg = ColorRect.new()
	header_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_bg.offset_bottom = float(header_h)
	header_bg.color = Color(0.04, 0.05, 0.11, 1.0)
	hud.add_child(header_bg)

	var header_divider = ColorRect.new()
	header_divider.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header_divider.offset_top = float(header_h)
	header_divider.offset_bottom = float(header_h + 1)
	header_divider.color = Color(0.22, 0.22, 0.38, 0.5)
	hud.add_child(header_divider)

	# Title
	var title = Label.new()
	title.text = "LEADERBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-120, 16 + safe_top)
	title.custom_minimum_size = Vector2(240, 0)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	hud.add_child(title)

	# ESC hint (hidden on mobile — no keyboard)
	if not GameSettings.is_mobile:
		var esc = Label.new()
		esc.text = "ESC to go back"
		esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		esc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		esc.position = Vector2(-80, -30)
		esc.custom_minimum_size = Vector2(160, 0)
		esc.add_theme_font_size_override("font_size", 15)
		esc.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		hud.add_child(esc)

	# Tab buttons (Solo first = default)
	# On mobile: larger tap targets; on PC: compact chip buttons
	var tab_row = HBoxContainer.new()
	tab_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	if GameSettings.is_mobile:
		tab_row.position = Vector2(-170, 76 + safe_top)
		tab_row.custom_minimum_size = Vector2(340, 64)
	else:
		tab_row.position = Vector2(-136, 72)
		tab_row.custom_minimum_size = Vector2(272, 48)
	tab_row.add_theme_constant_override("separation", 8)

	_solo_tab_btn = _create_tab_button("SOLO SCORES", true)
	_solo_tab_btn.pressed.connect(_on_tab_solo)
	tab_row.add_child(_solo_tab_btn)

	_elo_tab_btn = _create_tab_button("ELO RANKING", false)
	_elo_tab_btn.pressed.connect(_on_tab_elo)
	tab_row.add_child(_elo_tab_btn)

	# ELO sub-mode row (Bullet / Blitz / Rapid chips)
	_elo_mode_row = HBoxContainer.new()
	_elo_mode_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	if GameSettings.is_mobile:
		_elo_mode_row.position = Vector2(-170, 152 + safe_top)
		_elo_mode_row.custom_minimum_size = Vector2(340, 64)
	else:
		_elo_mode_row.position = Vector2(-160, 132)
		_elo_mode_row.custom_minimum_size = Vector2(320, 40)
	_elo_mode_row.add_theme_constant_override("separation", 8)
	_elo_mode_row.visible = false

	var mode_lbl = Label.new()
	mode_lbl.text = "MODE :"
	mode_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 12 if not GameSettings.is_mobile else 16)
	mode_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	_elo_mode_row.add_child(mode_lbl)

	_bullet_btn = _create_elo_mode_button("🔫 BULLET")
	_bullet_btn.pressed.connect(_on_elo_mode.bind("bullet"))
	_elo_mode_row.add_child(_bullet_btn)

	_blitz_btn = _create_elo_mode_button("⚡ BLITZ")
	_blitz_btn.pressed.connect(_on_elo_mode.bind("blitz"))
	_elo_mode_row.add_child(_blitz_btn)

	_rapid_btn = _create_elo_mode_button("⏱ RAPID")
	_rapid_btn.pressed.connect(_on_elo_mode.bind("rapid"))
	_elo_mode_row.add_child(_rapid_btn)

	# Scroll container for the list
	var scroll_wrap = MarginContainer.new()
	scroll_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Extra top margin on mobile to clear the bigger tab+elo rows, plus safe area
	scroll_wrap.add_theme_constant_override("margin_top",    234 + safe_top if GameSettings.is_mobile else 196)
	scroll_wrap.add_theme_constant_override("margin_bottom", 70  if GameSettings.is_mobile else 50)
	# Desktop: center content in ~720px column; mobile: small fixed padding
	var vp_x := int(get_viewport().get_visible_rect().size.x)
	var side_margin := 24 if GameSettings.is_mobile else maxi(40, (vp_x - 720) / 2)
	scroll_wrap.add_theme_constant_override("margin_left",  side_margin)
	scroll_wrap.add_theme_constant_override("margin_right", side_margin)
	hud.add_child(scroll_wrap)

	# Add rows last so they sit on top for input
	hud.add_child(tab_row)
	hud.add_child(_elo_mode_row)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.add_child(scroll)
	_scroll = scroll

	scroll_content = VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 6)
	scroll.add_child(scroll_content)

	# Loading label
	loading_label = Label.new()
	loading_label.text = "Loading..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 22)
	loading_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	scroll_content.add_child(loading_label)

	# Profile popup (hidden initially)
	_setup_profile_popup()

func _setup_profile_popup() -> void:
	profile_popup = Control.new()
	profile_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_popup.visible = false
	profile_popup.z_index = 10
	hud.add_child(profile_popup)

	var popup_bg = ColorRect.new()
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_bg.color = Color(0, 0, 0, 0.8)
	popup_bg.name = "PopupBG"
	profile_popup.add_child(popup_bg)

	popup_bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			profile_popup.visible = false
	)

# =====================
# LEADERBOARD DATA
# =====================

func _on_leaderboard_loaded(players: Array) -> void:
	_all_players = players
	_display_players()

func _display_players() -> void:
	for child in scroll_content.get_children():
		child.queue_free()

	if _all_players.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No players yet.\nPlay a ranked match to appear here!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		scroll_content.add_child(empty_lbl)
		return

	var sorted := _all_players.duplicate()
	var elo_field := "elo_" + _active_elo_mode

	if _active_tab == "elo":
		sorted.sort_custom(func(a, b): return a.get(elo_field, 0) > b.get(elo_field, 0))
		var mode_label = _active_elo_mode.to_upper() + " ELO"
		var header = _create_row_hbox("#", "Name", mode_label, "Record", Color(0.45, 0.45, 0.55), 20 if GameSettings.is_mobile else 16, false, "")
		scroll_content.add_child(header)
		scroll_content.add_child(_make_sep())
		for i in sorted.size():
			var p = sorted[i]
			var is_me = (p.get("player_id", "") == PlayerData.player_id)
			scroll_content.add_child(_create_player_row(i + 1, p, is_me, elo_field))
	else:
		sorted.sort_custom(func(a, b): return a.get("solo_highscore", 0) > b.get("solo_highscore", 0))
		var header = _create_solo_row_hbox("#", "Name", "Best Score", Color(0.45, 0.45, 0.55), 20 if GameSettings.is_mobile else 16)
		scroll_content.add_child(header)
		scroll_content.add_child(_make_sep())
		for i in sorted.size():
			var p = sorted[i]
			var is_me = (p.get("player_id", "") == PlayerData.player_id)
			scroll_content.add_child(_create_solo_player_row(i + 1, p, is_me))

func _make_sep() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep

func _on_tab_elo() -> void:
	if _active_tab == "elo":
		return
	_active_tab = "elo"
	GameSettings.set_leaderboard_tab("elo")
	_style_tab_button(_elo_tab_btn, true)
	_style_tab_button(_solo_tab_btn, false)
	_elo_mode_row.visible = true
	PlayerData.load_leaderboard("elo_" + _active_elo_mode)

func _on_tab_solo() -> void:
	if _active_tab == "solo":
		return
	_active_tab = "solo"
	GameSettings.set_leaderboard_tab("solo")
	_style_tab_button(_elo_tab_btn, false)
	_style_tab_button(_solo_tab_btn, true)
	_elo_mode_row.visible = false
	PlayerData.load_leaderboard("solo_highscore")

func _on_elo_mode(mode: String) -> void:
	if _active_elo_mode == mode:
		return
	_active_elo_mode = mode
	GameSettings.set_leaderboard_elo_mode(mode)
	_update_elo_mode_buttons()
	PlayerData.load_leaderboard("elo_" + mode)

func _update_elo_mode_buttons() -> void:
	_style_elo_mode_button(_bullet_btn, _active_elo_mode == "bullet")
	_style_elo_mode_button(_blitz_btn,  _active_elo_mode == "blitz")
	_style_elo_mode_button(_rapid_btn,  _active_elo_mode == "rapid")

func _create_elo_mode_button(label: String) -> Button:
	var btn = Button.new()
	btn.text = label
	if GameSettings.is_mobile:
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
	else:
		btn.custom_minimum_size = Vector2(76, 40)
		btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_elo_mode_button(btn, false)
	return btn

func _style_elo_mode_button(btn: Button, is_active: bool) -> void:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(5)
	s.set_content_margin_all(3)
	if is_active:
		s.bg_color = Color(0.12, 0.18, 0.32)
		s.border_color = Color(0.3, 0.55, 1.0)
		s.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	else:
		s.bg_color = Color(0.08, 0.08, 0.12)
		s.border_color = Color(0.22, 0.22, 0.3)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.38, 0.38, 0.48))
	btn.add_theme_stylebox_override("normal", s)
	var hover = s.duplicate() as StyleBoxFlat
	hover.bg_color = s.bg_color.lightened(0.07)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _create_tab_button(label: String, is_active: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	if GameSettings.is_mobile:
		btn.custom_minimum_size = Vector2(0, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
	else:
		btn.custom_minimum_size = Vector2(128, 48)
		btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_tab_button(btn, is_active)
	return btn

func _style_tab_button(btn: Button, is_active: bool) -> void:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.set_content_margin_all(4)
	if is_active:
		s.bg_color = Color(0.12, 0.28, 0.14)
		s.border_color = Color(0.45, 0.9, 0.55)
		s.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	else:
		s.bg_color = Color(0.1, 0.1, 0.15)
		s.border_color = Color(0.28, 0.28, 0.38)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	btn.add_theme_stylebox_override("normal", s)
	var hover = s.duplicate() as StyleBoxFlat
	hover.bg_color = s.bg_color.lightened(0.08)
	hover.border_color = s.border_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _create_row_hbox(rank_text: String, name_text: String, elo_text: String,
		record_text: String, text_color: Color, font_size: int,
		clickable: bool, pid: String) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Rank column (50px)
	var rank_lbl = Label.new()
	rank_lbl.text = rank_text
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", font_size)
	rank_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(rank_lbl)

	# Name column (expanding)
	var name_lbl = Label.new()
	name_lbl.text = name_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", font_size)
	name_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(name_lbl)

	# ELO column (80px)
	var elo_lbl = Label.new()
	elo_lbl.text = elo_text
	elo_lbl.custom_minimum_size = Vector2(80, 0)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", font_size)
	elo_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(elo_lbl)

	# Record column (120px)
	var record_lbl = Label.new()
	record_lbl.text = record_text
	record_lbl.custom_minimum_size = Vector2(120, 0)
	record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_lbl.add_theme_font_size_override("font_size", font_size)
	record_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(record_lbl)

	return hbox

func _create_player_row(rank: int, data: Dictionary, is_me: bool, elo_field: String = "elo_bullet") -> Button:
	var name_str = data.get("name", "???")
	var elo_val = data.get(elo_field, data.get("elo_bullet", data.get("elo", 1000)))
	var mode_key = elo_field.replace("elo_", "")
	var w     = int(data.get("wins_"   + mode_key, data.get("wins", 0)))
	var l     = int(data.get("losses_" + mode_key, data.get("losses", 0)))
	var d_val = int(data.get("draws_"  + mode_key, data.get("draws", 0)))
	var pid = data.get("player_id", "")
	var record_str = str(w) + "W " + str(l) + "L " + str(d_val) + "D"

	var row_h := 64 if GameSettings.is_mobile else 44
	var row_font := 22 if GameSettings.is_mobile else 18

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, row_h)

	# Style
	var base_color = Color(0.1, 0.15, 0.1) if is_me else Color(0.08, 0.08, 0.12)
	var text_color = Color(0.5, 1.0, 0.6) if is_me else Color(0.85, 0.85, 0.9)

	var accent = Color(0.25, 0.25, 0.35)
	if rank == 1:
		accent = Color(0.85, 0.65, 0.1)
		text_color = Color(1.0, 0.9, 0.5) if not is_me else text_color
	elif rank == 2:
		accent = Color(0.6, 0.6, 0.7)
	elif rank == 3:
		accent = Color(0.7, 0.45, 0.2)

	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(4)
	normal.border_color = accent
	normal.border_width_left = 3 if rank <= 3 else 0
	normal.set_content_margin_all(0)
	normal.content_margin_left = 0
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = base_color.lightened(0.1)
	hover.border_color = Color(0.85, 0.55, 0.1)
	hover.set_border_width_all(1)
	hover.border_width_left = 3
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Hide the button's own text — we'll use an HBox overlay
	btn.text = ""

	# Content HBox inside the button
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	# Rank
	var rank_lbl = Label.new()
	rank_lbl.text = "#" + str(rank)
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", row_font)
	rank_lbl.add_theme_color_override("font_color", text_color)
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rank_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = name_str
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", row_font)
	name_lbl.add_theme_color_override("font_color", text_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# ELO
	var elo_lbl = Label.new()
	elo_lbl.text = str(elo_val)
	elo_lbl.custom_minimum_size = Vector2(80, 0)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", row_font)
	elo_lbl.add_theme_color_override("font_color", text_color)
	elo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(elo_lbl)

	# Record (hidden on mobile — not enough screen real-estate)
	if not GameSettings.is_mobile:
		var record_lbl = Label.new()
		record_lbl.text = record_str
		record_lbl.custom_minimum_size = Vector2(120, 0)
		record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		record_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		record_lbl.add_theme_font_size_override("font_size", 14)
		record_lbl.add_theme_color_override("font_color", text_color.darkened(0.15))
		record_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(record_lbl)

	btn.pressed.connect(_on_leaderboard_player_clicked.bind(pid, name_str))
	return btn

func _create_solo_row_hbox(rank_text: String, name_text: String, score_text: String,
		text_color: Color, font_size: int) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rank_lbl = Label.new()
	rank_lbl.text = rank_text
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", font_size)
	rank_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(rank_lbl)

	var name_lbl = Label.new()
	name_lbl.text = name_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", font_size)
	name_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(name_lbl)

	var score_lbl = Label.new()
	score_lbl.text = score_text
	score_lbl.custom_minimum_size = Vector2(120, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", font_size)
	score_lbl.add_theme_color_override("font_color", text_color)
	hbox.add_child(score_lbl)

	return hbox

func _create_solo_player_row(rank: int, data: Dictionary, is_me: bool) -> Button:
	var name_str := data.get("name", "???") as String
	var score_val := data.get("solo_highscore", 0) as int
	var pid := data.get("player_id", "") as String

	var row_h    := 64 if GameSettings.is_mobile else 44
	var row_font := 22 if GameSettings.is_mobile else 18

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, row_h)

	var base_color := Color(0.1, 0.15, 0.1) if is_me else Color(0.08, 0.08, 0.12)
	var text_color := Color(0.5, 1.0, 0.6) if is_me else Color(0.85, 0.85, 0.9)

	var accent := Color(0.25, 0.25, 0.35)
	if rank == 1:
		accent = Color(0.85, 0.65, 0.1)
		if not is_me:
			text_color = Color(1.0, 0.9, 0.5)
	elif rank == 2:
		accent = Color(0.6, 0.6, 0.7)
	elif rank == 3:
		accent = Color(0.7, 0.45, 0.2)

	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.set_corner_radius_all(4)
	normal.border_color = accent
	normal.border_width_left = 3 if rank <= 3 else 0
	normal.set_content_margin_all(0)
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate() as StyleBoxFlat
	hover.bg_color = base_color.lightened(0.1)
	hover.border_color = Color(0.85, 0.55, 0.1)
	hover.set_border_width_all(1)
	hover.border_width_left = 3
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.text = ""

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hbox)

	var rank_lbl = Label.new()
	rank_lbl.text = "#" + str(rank)
	rank_lbl.custom_minimum_size = Vector2(50, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", row_font)
	rank_lbl.add_theme_color_override("font_color", text_color)
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rank_lbl)

	var name_lbl = Label.new()
	name_lbl.text = name_str
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", row_font)
	name_lbl.add_theme_color_override("font_color", text_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var score_lbl = Label.new()
	score_lbl.text = str(score_val) if score_val > 0 else "—"
	score_lbl.custom_minimum_size = Vector2(120, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", row_font)
	score_lbl.add_theme_color_override("font_color", text_color)
	score_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(score_lbl)

	btn.pressed.connect(_on_leaderboard_player_clicked.bind(pid, name_str))
	return btn

# =====================
# PROFILE POPUP
# =====================

func _build_own_profile_data() -> Dictionary:
	return {
		"name": PlayerData.player_name,
		"elo_bullet": PlayerData.elo_bullet,
		"elo_blitz":  PlayerData.elo_blitz,
		"elo_rapid":  PlayerData.elo_rapid,
		"solo_highscore": PlayerData.solo_highscore,
		"total_games": PlayerData.total_games,
		"wins": PlayerData.wins,
		"losses": PlayerData.losses,
		"draws": PlayerData.draws,
		"wins_bullet": PlayerData.wins_bullet, "losses_bullet": PlayerData.losses_bullet, "draws_bullet": PlayerData.draws_bullet,
		"wins_blitz":  PlayerData.wins_blitz,  "losses_blitz":  PlayerData.losses_blitz,  "draws_blitz":  PlayerData.draws_blitz,
		"wins_rapid":  PlayerData.wins_rapid,  "losses_rapid":  PlayerData.losses_rapid,  "draws_rapid":  PlayerData.draws_rapid,
		"matches": PlayerData.matches,
		"player_id": PlayerData.player_id
	}

func _show_own_profile() -> void:
	var start = _active_elo_mode if _active_tab == "elo" else "bullet"
	_show_profile(_build_own_profile_data(), true, start)

func _on_leaderboard_player_clicked(pid: String, _pname: String) -> void:
	if pid == PlayerData.player_id:
		_show_own_profile()
		return
	_show_profile_loading(_pname)
	PlayerData.load_player_profile(pid)

func _show_profile_loading(pname: String) -> void:
	_clear_profile_popup()
	profile_popup.visible = true

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.name = "Content"
	profile_popup.add_child(center)

	var lbl = Label.new()
	lbl.text = "Loading " + pname + "..."
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	center.add_child(lbl)

func _on_profile_loaded(data: Dictionary) -> void:
	if data.is_empty():
		profile_popup.visible = false
		return
	var start = _active_elo_mode if _active_tab == "elo" else "bullet"
	_show_profile(data, false, start)

func _show_profile(data: Dictionary, is_own: bool = false, start_mode: String = "bullet") -> void:
	_clear_profile_popup()
	profile_popup.visible = true

	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.07, 0.12)
	card_style.set_corner_radius_all(14)
	card_style.border_color = Color(0.25, 0.28, 0.42)
	card_style.set_border_width_all(2)
	card_style.set_content_margin_all(20 if GameSettings.is_mobile else 24)
	card.add_theme_stylebox_override("panel", card_style)

	if GameSettings.is_mobile:
		var r_lb := DisplayServer.get_display_safe_area()
		var stp_lb: int = maxi(r_lb.position.y, 40)
		var pm_lb := MarginContainer.new()
		pm_lb.name = "Content"
		pm_lb.set_anchors_preset(Control.PRESET_FULL_RECT)
		pm_lb.add_theme_constant_override("margin_left",   20)
		pm_lb.add_theme_constant_override("margin_right",  20)
		pm_lb.add_theme_constant_override("margin_top",    stp_lb + 16)
		pm_lb.add_theme_constant_override("margin_bottom", 20)
		profile_popup.add_child(pm_lb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		pm_lb.add_child(card)
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.name = "Content"
		profile_popup.add_child(center)
		card.custom_minimum_size = Vector2(460, 0)
		center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10 if GameSettings.is_mobile else 4)
	if GameSettings.is_mobile:
		var scroll_lb := ScrollContainer.new()
		scroll_lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_lb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		scroll_lb.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		card.add_child(scroll_lb)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_lb.add_child(vbox)
		_profile_scroll = scroll_lb
	else:
		card.add_child(vbox)

	# ── Name ──
	var name_lbl = Label.new()
	name_lbl.text = data.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 44 if GameSettings.is_mobile else 30)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# ── Solo score shown under name for quick preview ──
	var hs_lb: int = int(data.get("solo_highscore", 0))
	var score_sub_lb := Label.new()
	score_sub_lb.text = "Best Score: " + (str(hs_lb) if hs_lb > 0 else "—")
	score_sub_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_sub_lb.add_theme_font_size_override("font_size", 24 if GameSettings.is_mobile else 16)
	score_sub_lb.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
	vbox.add_child(score_sub_lb)

	# ── Name-change row (own profile only) ──
	if is_own:
		_add_spacer(vbox, 6)
		var name_row = HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 8)
		vbox.add_child(name_row)

		var name_edit = LineEdit.new()
		name_edit.text = data.get("name", "")
		name_edit.placeholder_text = "New name..."
		name_edit.max_length = 16
		if GameSettings.is_mobile:
			name_edit.custom_minimum_size = Vector2(220, 56)
			name_edit.add_theme_font_size_override("font_size", 24)
		else:
			name_edit.custom_minimum_size = Vector2(180, 30)
			name_edit.add_theme_font_size_override("font_size", 15)
		name_row.add_child(name_edit)

		var confirm_btn = Button.new()
		confirm_btn.text = "CONFIRM"
		if GameSettings.is_mobile:
			confirm_btn.custom_minimum_size = Vector2(120, 56)
			confirm_btn.add_theme_font_size_override("font_size", 22)
		else:
			confirm_btn.custom_minimum_size = Vector2(90, 30)
			confirm_btn.add_theme_font_size_override("font_size", 13)
		var cb_style = StyleBoxFlat.new()
		cb_style.bg_color = Color(0.1, 0.3, 0.15)
		cb_style.set_corner_radius_all(6)
		cb_style.border_color = Color(0.3, 0.75, 0.4, 0.9)
		cb_style.set_border_width_all(1)
		cb_style.set_content_margin_all(4)
		confirm_btn.add_theme_stylebox_override("normal", cb_style)
		var cb_hover = cb_style.duplicate() as StyleBoxFlat
		cb_hover.bg_color = Color(0.15, 0.4, 0.2)
		confirm_btn.add_theme_stylebox_override("hover", cb_hover)
		confirm_btn.add_theme_stylebox_override("pressed", cb_hover)
		confirm_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		confirm_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
		confirm_btn.pressed.connect(func():
			var new_name = name_edit.text.strip_edges()
			if new_name.is_empty():
				return
			PlayerData.set_player_name(new_name)
			name_lbl.text = new_name
		)
		name_row.add_child(confirm_btn)

	_add_spacer(vbox, 10)

	# ── Mode tab row ──
	var mode_tab_row = HBoxContainer.new()
	mode_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_tab_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mode_tab_row)

	var _profile_mode = start_mode
	var mode_tab_buttons: Dictionary = {}

	# Stats section — rebuilt when mode tab changes
	_add_spacer(vbox, 8)
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(stats_vbox)

	# Solo section (always shown)
	_add_spacer(vbox, 12)
	var sep_lbl = Label.new()
	sep_lbl.text = "─── SOLO SCORES ───"
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.add_theme_font_size_override("font_size", 18 if GameSettings.is_mobile else 12)
	sep_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.5))
	vbox.add_child(sep_lbl)
	_add_spacer(vbox, 4)
	var hs = int(data.get("solo_highscore", 0))
	var total_g = int(data.get("total_games", 0))
	_add_stat_line(vbox, "Best Score",   str(hs),      Color(0.85, 0.75, 0.3))
	_add_stat_line(vbox, "Total Games",  str(total_g), Color(0.65, 0.65, 0.75))

	# Match history section — rebuilt when mode tab changes
	_add_spacer(vbox, 12)
	var hist_header_lbl = Label.new()
	hist_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hist_header_lbl.add_theme_font_size_override("font_size", 20 if GameSettings.is_mobile else 13)
	hist_header_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(hist_header_lbl)
	_add_spacer(vbox, 4)
	var hist_vbox = VBoxContainer.new()
	hist_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(hist_vbox)

	_add_spacer(vbox, 14)
	if GameSettings.is_mobile:
		var close_btn := Button.new()
		close_btn.text = "CLOSE"
		close_btn.custom_minimum_size = Vector2(0, 72)
		close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_btn.add_theme_font_size_override("font_size", 28)
		close_btn.add_theme_color_override("font_color", Color.WHITE)
		var cbs := StyleBoxFlat.new()
		cbs.bg_color = Color(0.12, 0.12, 0.18)
		cbs.set_corner_radius_all(10)
		cbs.border_color = Color(0.35, 0.35, 0.50, 0.9)
		cbs.set_border_width_all(2)
		cbs.set_content_margin_all(8)
		close_btn.add_theme_stylebox_override("normal", cbs)
		var cbsh := cbs.duplicate() as StyleBoxFlat
		cbsh.bg_color = Color(0.18, 0.18, 0.28)
		close_btn.add_theme_stylebox_override("hover", cbsh)
		close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		close_btn.pressed.connect(func(): profile_popup.visible = false)
		vbox.add_child(close_btn)
	else:
		var close_hint := Label.new()
		close_hint.text = "ESC or click outside to close"
		close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close_hint.add_theme_font_size_override("font_size", 12)
		close_hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		vbox.add_child(close_hint)

	# Helper: refresh the mode-specific sections
	var refresh_mode_fn = func(mode: String) -> void:
		_profile_mode = mode
		# Style tabs
		for m in mode_tab_buttons:
			_style_elo_mode_button(mode_tab_buttons[m], m == mode)
		# Rebuild stats
		for c in stats_vbox.get_children():
			c.queue_free()
		_refresh_profile_stats(mode, data, stats_vbox)
		# Rebuild history header + entries
		var mode_icons = {"bullet": "🔫", "blitz": "⚡", "rapid": "⏱"}
		hist_header_lbl.text = "── RECENT MATCHES  " + mode_icons.get(mode, "") + " " + mode.to_upper() + " ──"
		for c in hist_vbox.get_children():
			c.queue_free()
		_build_match_history(mode, data, hist_vbox)

	# Build the 3 mode tab buttons
	for tab_mode in ["bullet", "blitz", "rapid"]:
		var icons = {"bullet": "🔫", "blitz": "⚡", "rapid": "⏱"}
		var tab_btn = _create_elo_mode_button(icons[tab_mode] + " " + tab_mode.to_upper())
		var captured_mode = tab_mode
		tab_btn.pressed.connect(func():
			SoundManager.play("click")
			refresh_mode_fn.call(captured_mode)
		)
		mode_tab_row.add_child(tab_btn)
		mode_tab_buttons[tab_mode] = tab_btn

	# Initial render for start_mode
	refresh_mode_fn.call(start_mode)

func _refresh_profile_stats(mode: String, data: Dictionary, stats_vbox: VBoxContainer) -> void:
	var legacy_elo = int(data.get("elo", 1000))
	var elo = int(data.get("elo_" + mode, legacy_elo if mode == "bullet" else 1000))
	var w   = int(data.get("wins_"   + mode, data.get("wins", 0)))
	var l   = int(data.get("losses_" + mode, data.get("losses", 0)))
	var d   = int(data.get("draws_"  + mode, data.get("draws", 0)))
	var total = w + l + d
	var wr_str = ("%.1f" % (float(w) / float(total) * 100.0)) + "%" if total > 0 else "—"

	var accent = Color(0.95, 0.78, 0.1) if mode == "bullet" else \
				 (Color(0.2, 0.65, 1.0) if mode == "blitz" else Color(0.2, 0.9, 0.45))
	_add_stat_line(stats_vbox, "ELO",      str(elo),   accent)
	_add_stat_line(stats_vbox, "Wins",     str(w),     Color(0.4, 0.9, 0.5))
	_add_stat_line(stats_vbox, "Losses",   str(l),     Color(0.9, 0.4, 0.4))
	_add_stat_line(stats_vbox, "Draws",    str(d),     Color(0.8, 0.8, 0.45))
	_add_stat_line(stats_vbox, "Win Rate", wr_str,     Color(0.65, 0.65, 0.75))

func _build_match_history(mode: String, data: Dictionary, hist_vbox: VBoxContainer) -> void:
	var match_list = data.get("matches", [])
	if match_list == null or not match_list is Array:
		match_list = []
	# Filter by mode (entries without time_mode treated as "bullet")
	var filtered: Array = []
	for m in match_list:
		if m is Dictionary and m.get("time_mode", "bullet") == mode:
			filtered.append(m)
	filtered.reverse()
	var count = mini(filtered.size(), 8)
	var hist_font := 20 if GameSettings.is_mobile else 13
	if count == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No matches yet in this mode."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", hist_font)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		hist_vbox.add_child(empty_lbl)
		return
	for i in count:
		var m = filtered[i]
		var result_str = m.get("result", "?")
		var ms  = m.get("my_score", 0)
		var os  = m.get("opp_score", 0)
		var oname = m.get("opponent", "???")
		var ec  = m.get("elo_change", 0)
		var ec_str = ("+" if ec >= 0 else "") + str(ec)
		var color = Color(0.4, 0.85, 0.5) if result_str == "win" else \
					(Color(0.85, 0.35, 0.35) if result_str == "lose" else Color(0.75, 0.75, 0.45))
		var text = result_str.to_upper() + "  " + str(ms) + "-" + str(os) + \
				   "  vs " + oname + "  (" + ec_str + " ELO)"
		var lbl = Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", hist_font)
		lbl.add_theme_color_override("font_color", color)
		hist_vbox.add_child(lbl)

func _add_stat_line(parent: VBoxContainer, label: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var key_font := 24 if GameSettings.is_mobile else 16
	var val_font := 26 if GameSettings.is_mobile else 16
	var row_h    := 40 if GameSettings.is_mobile else 0

	var key = Label.new()
	key.text = label + ":"
	key.add_theme_font_size_override("font_size", key_font)
	key.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	key.custom_minimum_size = Vector2(130, row_h)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(key)

	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", val_font)
	val.add_theme_color_override("font_color", color)
	val.custom_minimum_size = Vector2(180, row_h)
	hbox.add_child(val)

func _clear_profile_popup() -> void:
	for child in profile_popup.get_children():
		if child.name == "PopupBG":
			continue
		child.queue_free()

# =====================
# INPUT
# =====================

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if profile_popup != null and profile_popup.visible and _profile_scroll != null:
			_profile_scroll.scroll_vertical -= int(event.relative.y)
			get_viewport().set_input_as_handled()
		elif _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			SoundManager.play("click")
			if profile_popup.visible:
				profile_popup.visible = false
			else:
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

# =====================
# BACK BUTTON (Mobile)
# =====================

func _setup_back_button() -> void:
	back_button_layer = CanvasLayer.new()
	back_button_layer.layer = 100
	add_child(back_button_layer)
	
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_button_layer.add_child(root)
	
	var safe_top_back := 0
	if GameSettings.is_mobile:
		var r2 := DisplayServer.get_display_safe_area()
		safe_top_back = maxi(r2.position.y, 72)

	# Pill chip inside the header strip, vertically aligned with the title
	var btn = Button.new()
	btn.text = "< BACK"  # ASCII compatible
	btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if GameSettings.is_mobile:
		btn.position = Vector2(20, safe_top_back + 8)
		btn.custom_minimum_size = Vector2(140, 64)
		btn.add_theme_font_size_override("font_size", 24)
	else:
		btn.position = Vector2(20, 16)
		btn.custom_minimum_size = Vector2(110, 48)
		btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.85, 0.87, 0.95))
	_style_back_button(btn)
	btn.pressed.connect(_on_back_button_pressed)
	root.add_child(btn)

func _style_back_button(btn: Button) -> void:
	# Pill shape: radius = half the button height
	var radius := int(btn.custom_minimum_size.y / 2.0)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.10, 0.16, 0.9)
	normal.set_corner_radius_all(radius)
	normal.border_color = Color(0.32, 0.34, 0.48, 0.55)
	normal.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.15, 0.22, 0.95)
	hover.set_corner_radius_all(radius)
	hover.border_color = Color(0.50, 0.52, 0.66, 0.8)
	hover.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.06, 0.07, 0.11, 0.95)
	pressed.set_corner_radius_all(radius)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_back_button_pressed() -> void:
	SoundManager.play("click")
	if profile_popup.visible:
		profile_popup.visible = false
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
