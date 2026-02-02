extends Node2D
## Leaderboard — shows top players by ELO.
## Click a player to see their full profile + match history.

var hud: CanvasLayer
var scroll_content: VBoxContainer
var profile_popup: Control
var loading_label: Label

func _ready() -> void:
	_setup_ui()
	PlayerData.leaderboard_loaded.connect(_on_leaderboard_loaded)
	PlayerData.player_profile_loaded.connect(_on_profile_loaded)
	PlayerData.load_leaderboard()

# =====================
# UI SETUP
# =====================

func _setup_ui() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08, 0.95)
	hud.add_child(bg)

	# Title
	var title = Label.new()
	title.text = "LEADERBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-120, 20)
	title.custom_minimum_size = Vector2(240, 0)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	hud.add_child(title)

	# ESC hint
	var esc = Label.new()
	esc.text = "ESC to go back"
	esc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	esc.position = Vector2(-80, -30)
	esc.custom_minimum_size = Vector2(160, 0)
	esc.add_theme_font_size_override("font_size", 15)
	esc.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	hud.add_child(esc)

	# Scroll container for the list
	var scroll_wrap = MarginContainer.new()
	scroll_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll_wrap.add_theme_constant_override("margin_top", 75)
	scroll_wrap.add_theme_constant_override("margin_bottom", 50)
	scroll_wrap.add_theme_constant_override("margin_left", 40)
	scroll_wrap.add_theme_constant_override("margin_right", 40)
	hud.add_child(scroll_wrap)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.add_child(scroll)

	scroll_content = VBoxContainer.new()
	scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_content.add_theme_constant_override("separation", 4)
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
	for child in scroll_content.get_children():
		scroll_content.remove_child(child)
		child.queue_free()

	if players.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No players yet.\nPlay a ranked match to appear here!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		scroll_content.add_child(empty_lbl)
		return

	# Header row using HBoxContainer for alignment
	var header = _create_row_hbox("#", "Name", "ELO", "Record", Color(0.45, 0.45, 0.55), 14, false, "")
	scroll_content.add_child(header)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	scroll_content.add_child(sep)

	# Player rows
	for i in players.size():
		var p = players[i]
		var rank = i + 1
		var is_me = (p.get("player_id", "") == PlayerData.player_id)
		var row = _create_player_row(rank, p, is_me)
		scroll_content.add_child(row)

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

func _create_player_row(rank: int, data: Dictionary, is_me: bool) -> Button:
	var name_str = data.get("name", "???")
	var elo_val = data.get("elo", 1000)
	var w = data.get("wins", 0)
	var l = data.get("losses", 0)
	var d_val = data.get("draws", 0)
	var pid = data.get("player_id", "")
	var record_str = str(w) + "W " + str(l) + "L " + str(d_val) + "D"

	var btn = Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)

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
	rank_lbl.add_theme_font_size_override("font_size", 16)
	rank_lbl.add_theme_color_override("font_color", text_color)
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(rank_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = name_str
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", text_color)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# ELO
	var elo_lbl = Label.new()
	elo_lbl.text = str(elo_val)
	elo_lbl.custom_minimum_size = Vector2(80, 0)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", 16)
	elo_lbl.add_theme_color_override("font_color", text_color)
	elo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(elo_lbl)

	# Record
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

# =====================
# PROFILE POPUP
# =====================

func _on_leaderboard_player_clicked(pid: String, pname: String) -> void:
	if pid == PlayerData.player_id:
		_show_profile({
			"name": PlayerData.player_name,
			"elo": PlayerData.elo,
			"solo_highscore": PlayerData.solo_highscore,
			"total_games": PlayerData.total_games,
			"wins": PlayerData.wins,
			"losses": PlayerData.losses,
			"draws": PlayerData.draws,
			"matches": PlayerData.matches,
			"player_id": PlayerData.player_id
		})
		return
	_show_profile_loading(pname)
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
	_show_profile(data)

func _show_profile(data: Dictionary) -> void:
	_clear_profile_popup()
	profile_popup.visible = true

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.name = "Content"
	profile_popup.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.06, 0.1)
	card_style.set_corner_radius_all(12)
	card_style.border_color = Color(0.3, 0.3, 0.4)
	card_style.set_border_width_all(1)
	card_style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = data.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	_add_spacer(vbox, 12)

	# Stats
	var elo_val = data.get("elo", 1000)
	var total = data.get("total_games", 0)
	var w = data.get("wins", 0)
	var l = data.get("losses", 0)
	var d = data.get("draws", 0)
	var hs = data.get("solo_highscore", 0)
	var wr = ("%.0f" % (float(w) / float(total) * 100.0)) + "%" if total > 0 else "—"

	_add_stat_line(vbox, "ELO", str(elo_val), Color(0.9, 0.9, 1.0))
	_add_stat_line(vbox, "Solo Highscore", str(hs), Color(0.7, 0.7, 0.8))
	_add_stat_line(vbox, "Matches", str(total) + "  (" + str(w) + "W / " + str(l) + "L / " + str(d) + "D)", Color(0.7, 0.7, 0.8))
	_add_stat_line(vbox, "Win Rate", wr, Color(0.7, 0.7, 0.8))

	# Match history
	var match_list = data.get("matches", [])
	if match_list != null and match_list is Array and not match_list.is_empty():
		_add_spacer(vbox, 14)

		var hist_title = Label.new()
		hist_title.text = "Recent Matches"
		hist_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hist_title.add_theme_font_size_override("font_size", 16)
		hist_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		vbox.add_child(hist_title)

		_add_spacer(vbox, 4)

		var show_list = match_list.duplicate()
		show_list.reverse()
		var count = mini(show_list.size(), 10)

		for i in count:
			var m = show_list[i]
			if not m is Dictionary:
				continue
			var result_str = m.get("result", "?")
			var ms = m.get("my_score", 0)
			var os = m.get("opp_score", 0)
			var oname = m.get("opponent", "???")
			var ec = m.get("elo_change", 0)
			var ec_str = ("+" if ec >= 0 else "") + str(ec)

			var color = Color(0.5, 0.8, 0.5)
			if result_str == "lose":
				color = Color(0.8, 0.4, 0.4)
			elif result_str == "draw":
				color = Color(0.7, 0.7, 0.5)

			var text = result_str.to_upper() + "  " + str(ms) + "-" + str(os) + "  vs " + oname + "  (" + ec_str + ")"
			var match_lbl = Label.new()
			match_lbl.text = text
			match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			match_lbl.add_theme_font_size_override("font_size", 13)
			match_lbl.add_theme_color_override("font_color", color)
			vbox.add_child(match_lbl)

	_add_spacer(vbox, 16)

	var close_hint = Label.new()
	close_hint.text = "Click esc to close"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	vbox.add_child(close_hint)

func _add_stat_line(parent: VBoxContainer, label: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	parent.add_child(hbox)

	var key = Label.new()
	key.text = label + ":"
	key.add_theme_font_size_override("font_size", 16)
	key.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	key.custom_minimum_size = Vector2(130, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(key)

	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", color)
	val.custom_minimum_size = Vector2(180, 0)
	hbox.add_child(val)

func _clear_profile_popup() -> void:
	for child in profile_popup.get_children():
		if child.name == "PopupBG":
			continue
		profile_popup.remove_child(child)
		child.queue_free()

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
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
