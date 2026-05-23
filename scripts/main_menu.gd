extends Control

## Main Menu — Polished professional design for 1920×1080
## Full-height side panels, refined buttons with depth, intentional spacing

# =====================
# REFERENCES
# =====================

var settings_panel: Control
var shop_panel: Control
var profile_popup: Control

# Settings
var color_toggle_button: Button
var color_label: Label
var sfx_slider: HSlider
var sfx_value_label: Label
var master_slider: HSlider
var master_value_label: Label

# Profile
var profile_name_label: Label
var elo_label: Label
var high_score_label: Label
var points_label: Label
var record_label: Label
var winrate_label: Label
var player_preview_instance: Node2D  # Player scene instance for preview

# Leaderboard
var lb_content: VBoxContainer
var _lb_players: Array = []
var _lb_elo_btn: Button
var _lb_solo_btn: Button

# Shop
var shop_content: VBoxContainer
var shop_points_label: Label

# Background
var bg_pieces: Array = []
var piece_textures: Array = []

func _ready() -> void:
	_load_piece_textures()
	_build_layout()
	_setup_settings_panel()
	_setup_shop_panel()
	settings_panel.visible = false
	shop_panel.visible = false
	_setup_profile_popup()
	_update_profile_sidebar()
	_load_mini_leaderboard()
	PlayerData.hat_changed.connect(func(_h): _update_player_model())

func _load_piece_textures() -> void:
	var paths = [
		"res://assets/king.png", "res://assets/rook.png",
		"res://assets/bishop.png", "res://assets/knight.png",
		"res://assets/king1.png", "res://assets/rook1.png",
		"res://assets/bishop1.png", "res://assets/knight1.png"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			piece_textures.append(load(p))

func _process(delta: float) -> void:
	for piece in bg_pieces:
		var spr = piece["sprite"] as TextureRect
		if not is_instance_valid(spr):
			continue
		spr.position += piece["vel"] * delta
		spr.rotation += piece["rot_speed"] * delta
		var container = piece["container"] as Control
		if not is_instance_valid(container):
			continue
		var sz = container.size
		if sz.x < 1: sz = Vector2(1920, 1080)
		if spr.position.x > sz.x + 80: spr.position.x = -80
		elif spr.position.x < -80: spr.position.x = sz.x + 80
		if spr.position.y > sz.y + 80: spr.position.y = -80
		elif spr.position.y < -80: spr.position.y = sz.y + 80

# =====================
# MAIN LAYOUT
# =====================

func _build_layout() -> void:
	# Base background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.032, 0.035, 0.065)
	add_child(bg)

	_setup_floating_bg(self)

	# Main horizontal layout
	var main_container = HBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("separation", 0)
	add_child(main_container)

	# LEFT PANEL
	var left_panel = _build_left_panel()
	main_container.add_child(left_panel)

	# CENTER AREA
	var center_area = _build_center_area()
	center_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(center_area)

	# RIGHT PANEL
	var right_panel = _build_right_panel()
	main_container.add_child(right_panel)

# =====================
# LEFT PANEL - Leaderboard
# =====================

func _build_left_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.08)
	style.border_color = Color(0.08, 0.09, 0.14)
	style.border_width_right = 2
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# Title with accent
	var title_container = VBoxContainer.new()
	title_container.add_theme_constant_override("separation", 8)
	vbox.add_child(title_container)

	var lb_title = Label.new()
	lb_title.text = "LEADERBOARD"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 40)
	lb_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.25))
	title_container.add_child(lb_title)

	# Accent line under title
	var accent_line = ColorRect.new()
	accent_line.custom_minimum_size = Vector2(60, 3)
	accent_line.color = Color(0.95, 0.8, 0.25, 0.6)
	accent_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_container.add_child(accent_line)

	# Mini tab chips
	var mini_tab_row = HBoxContainer.new()
	mini_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mini_tab_row.add_theme_constant_override("separation", 6)
	title_container.add_child(mini_tab_row)

	_lb_elo_btn = _create_mini_tab("ELO", GameSettings.leaderboard_tab == "elo")
	_lb_elo_btn.pressed.connect(func():
		GameSettings.set_leaderboard_tab("elo")
		_style_mini_tab(_lb_elo_btn, true)
		_style_mini_tab(_lb_solo_btn, false)
		_render_mini_leaderboard()
	)
	mini_tab_row.add_child(_lb_elo_btn)

	_lb_solo_btn = _create_mini_tab("SOLO", GameSettings.leaderboard_tab == "solo")
	_lb_solo_btn.pressed.connect(func():
		GameSettings.set_leaderboard_tab("solo")
		_style_mini_tab(_lb_elo_btn, false)
		_style_mini_tab(_lb_solo_btn, true)
		_render_mini_leaderboard()
	)
	mini_tab_row.add_child(_lb_solo_btn)

	_add_spacer(vbox, 24)

	# Leaderboard content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	lb_content = VBoxContainer.new()
	lb_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_content.add_theme_constant_override("separation", 8)
	scroll.add_child(lb_content)

	var loading = Label.new()
	loading.text = "Loading..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.add_theme_font_size_override("font_size", 14)
	loading.add_theme_color_override("font_color", Color(0.4, 0.42, 0.5))
	lb_content.add_child(loading)

	_add_spacer(vbox, 24)

	# Buttons
	var view_btn = _create_panel_button("VIEW ALL", Color(0.8, 0.65, 0.12), Color(0.65, 0.5, 0.08))
	view_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
	)
	vbox.add_child(view_btn)

	return panel

# =====================
# CENTER AREA - Title & Buttons
# =====================

func _build_center_area() -> Control:
	var center = Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)

	# Main title
	var title = Label.new()
	title.text = "LASER CHESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.22))
	title.add_theme_color_override("font_shadow_color", Color(0.5, 0.35, 0.0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	vbox.add_child(title)

	_add_spacer(vbox, 8)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Survive the Board"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.5, 0.58))
	vbox.add_child(subtitle)

	_add_spacer(vbox, 80)

	# PLAY button
	var play_btn = _create_main_button("PLAY", Color(0.15, 0.65, 0.35), Color(0.1, 0.5, 0.25))
	play_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	vbox.add_child(play_btn)

	_add_spacer(vbox, 20)

	# RANKED button
	var ranked_btn = _create_main_button("RANKED", Color(0.85, 0.5, 0.1), Color(0.68, 0.38, 0.05))
	ranked_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/mode_select.tscn")
	)
	vbox.add_child(ranked_btn)
	
	_add_spacer(vbox, 20)
	
	var settings_btn = _create_main_button("SETTINGS", Color(0.28, 0.42, 0.65), Color(0.2, 0.32, 0.52))
	settings_btn.pressed.connect(func():
		SoundManager.play("click")
		_update_settings_values()
		settings_panel.visible = true
	)
	vbox.add_child(settings_btn)

	return center

# =====================
# RIGHT PANEL - Profile
# =====================

func _build_right_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.05, 0.08)
	style.border_color = Color(0.08, 0.09, 0.14)
	style.border_width_left = 2
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	# Character preview
	var preview_area = CenterContainer.new()
	preview_area.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(preview_area)

	# Container for the Node2D player
	var model_holder = Control.new()
	model_holder.custom_minimum_size = Vector2(100, 100)
	model_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_area.add_child(model_holder)

	# Use actual Player scene for identical hat positioning as in-game
	var player_scene = load("res://scenes/player.tscn")
	player_preview_instance = player_scene.instantiate()
	player_preview_instance.setup_for_menu_preview(80.0)  # 80px tile size for menu
	# Center the Node2D in the holder
	player_preview_instance.position = Vector2(50, 50)
	model_holder.add_child(player_preview_instance)

	_add_spacer(vbox, 16)

	# Player name
	profile_name_label = Label.new()
	profile_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_label.add_theme_font_size_override("font_size", 48)
	profile_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(profile_name_label)

	_add_spacer(vbox, 28)

	# Divider
	var divider = ColorRect.new()
	divider.custom_minimum_size = Vector2(120, 1)
	divider.color = Color(0.2, 0.22, 0.3, 0.5)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(divider)

	_add_spacer(vbox, 28)

	# Stats
	elo_label = _create_stat_display(vbox, "ELO", Color(1.0, 0.85, 0.22), 40)
	_add_spacer(vbox, 16)
	high_score_label = _create_stat_display(vbox, "BEST SCORE", Color(0.65, 0.67, 0.75), 32)
	_add_spacer(vbox, 12)
	points_label = _create_stat_display(vbox, "POINTS", Color(0.4, 0.82, 1.0), 32)
	_add_spacer(vbox, 12)
	record_label = _create_stat_display(vbox, "RECORD", Color(0.55, 0.57, 0.65), 28)
	_add_spacer(vbox, 8)
	winrate_label = _create_stat_display(vbox, "WIN RATE", Color(0.55, 0.57, 0.65), 28)

	_add_spacer(vbox, 20)

	# MY PROFILE button
	var profile_btn = Button.new()
	profile_btn.text = "MY PROFILE"
	profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_btn.custom_minimum_size = Vector2(0, 48)
	profile_btn.add_theme_font_size_override("font_size", 18)
	var pb_s = StyleBoxFlat.new()
	pb_s.bg_color = Color(0.1, 0.13, 0.22)
	pb_s.set_corner_radius_all(10)
	pb_s.border_color = Color(0.35, 0.55, 1.0, 0.75)
	pb_s.set_border_width_all(2)
	pb_s.set_content_margin_all(6)
	profile_btn.add_theme_stylebox_override("normal", pb_s)
	var pb_h = pb_s.duplicate() as StyleBoxFlat
	pb_h.bg_color = Color(0.15, 0.2, 0.35)
	pb_h.border_color = Color(0.5, 0.7, 1.0)
	profile_btn.add_theme_stylebox_override("hover", pb_h)
	profile_btn.add_theme_stylebox_override("pressed", pb_h)
	profile_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	profile_btn.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
	profile_btn.pressed.connect(func():
		SoundManager.play("click")
		_show_own_profile_popup()
	)
	vbox.add_child(profile_btn)

	# Flexible spacer
	var flex = Control.new()
	flex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(flex)

	# Shop button
	var shop_btn = _create_panel_button("SHOP", Color(0.25, 0.58, 0.72), Color(0.18, 0.45, 0.58))
	shop_btn.pressed.connect(_on_shop_pressed)
	vbox.add_child(shop_btn)

	return panel

func _create_stat_display(parent: VBoxContainer, label: String, color: Color, value_size: int) -> Label:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	parent.add_child(container)

	var lbl = Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.42, 0.5))
	container.add_child(lbl)

	var value = Label.new()
	value.text = "—"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", value_size)
	value.add_theme_color_override("font_color", color)
	container.add_child(value)

	return value

# =====================
# BUTTON FACTORIES
# =====================

func _create_main_button(text: String, color: Color, dark_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 85)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color.WHITE)

	# Normal state with depth
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	# Top highlight border
	normal.border_color = color.lightened(0.2)
	normal.border_width_top = 2
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 0
	# Shadow
	normal.shadow_color = Color(0, 0, 0, 0.4)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("normal", normal)

	# Hover - brighter with stronger glow
	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.1)
	hover.set_corner_radius_all(10)
	hover.border_color = color.lightened(0.35)
	hover.border_width_top = 2
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_bottom = 0
	hover.shadow_color = Color(0, 0, 0, 0.5)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 5)
	btn.add_theme_stylebox_override("hover", hover)

	# Pressed - darker, less shadow (pushed in)
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = dark_color
	pressed.set_corner_radius_all(10)
	pressed.border_color = dark_color.lightened(0.1)
	pressed.border_width_top = 1
	pressed.border_width_left = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 0
	pressed.shadow_color = Color(0, 0, 0, 0.3)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _create_panel_button(text: String, color: Color, dark_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 60)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	normal.border_color = color.lightened(0.15)
	normal.border_width_top = 2
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.08)
	hover.set_corner_radius_all(10)
	hover.border_color = color.lightened(0.25)
	hover.border_width_top = 2
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.shadow_color = Color(0, 0, 0, 0.4)
	hover.shadow_size = 5
	hover.shadow_offset = Vector2(0, 4)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = dark_color
	pressed.set_corner_radius_all(10)
	pressed.border_color = dark_color.lightened(0.1)
	pressed.border_width_top = 1
	pressed.shadow_size = 2
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _create_text_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55))
	btn.add_theme_color_override("font_hover_color", Color(0.65, 0.68, 0.75))
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return btn

# =====================
# PLAYER MODEL
# =====================

func _update_player_model() -> void:
	var _king_path = GameSettings.get_player_king_texture()

	var _hat_id = PlayerData.equipped_hat


func _update_profile_sidebar() -> void:
	_update_player_model()
	profile_name_label.text = PlayerData.player_name

	elo_label.text = str(PlayerData.elo_bullet)
	high_score_label.text = str(PlayerData.solo_highscore)
	points_label.text = str(PlayerData.total_points)
	record_label.text = str(PlayerData.wins) + "W / " + str(PlayerData.losses) + "L / " + str(PlayerData.draws) + "D"
	winrate_label.text = (("%.0f%%" % PlayerData.get_win_rate()) if PlayerData.total_games > 0 else "—")

# =====================
# LEADERBOARD
# =====================

func _load_mini_leaderboard() -> void:
	PlayerData.leaderboard_loaded.connect(_on_lb_loaded, CONNECT_ONE_SHOT)
	PlayerData.load_leaderboard()

func _on_lb_loaded(players: Array) -> void:
	_lb_players = players
	_render_mini_leaderboard()

func _render_mini_leaderboard() -> void:
	for c in lb_content.get_children():
		lb_content.remove_child(c)
		c.queue_free()

	if _lb_players.is_empty():
		var empty = Label.new()
		empty.text = "No players yet"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.4, 0.42, 0.5))
		lb_content.add_child(empty)
		return

	var sorted := _lb_players.duplicate()
	var tab := GameSettings.leaderboard_tab

	if tab == "solo":
		sorted.sort_custom(func(a, b): return a.get("solo_highscore", 0) > b.get("solo_highscore", 0))
	else:
		sorted.sort_custom(func(a, b): return a.get("elo_bullet", 0) > b.get("elo_bullet", 0))

	var count := mini(sorted.size(), 10)
	for i in count:
		var p: Dictionary = sorted[i]
		var pname := p.get("name", "???") as String
		var val: int = p.get("solo_highscore", 0) if tab == "solo" else p.get("elo_bullet", 0)
		var is_me: bool = p.get("player_id", "") == PlayerData.player_id
		lb_content.add_child(_create_lb_row(i + 1, pname, val, is_me))

func _create_lb_row(rank: int, pname: String, elo: int, is_me: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.1) if not is_me else Color(0.08, 0.1, 0.15)
	style.set_corner_radius_all(6)
	if is_me:
		style.border_color = Color(0.3, 0.6, 0.8, 0.5)
		style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	# Rank
	var rank_lbl = Label.new()
	rank_lbl.text = str(rank)
	rank_lbl.custom_minimum_size = Vector2(24, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.add_theme_font_size_override("font_size", 20)
	var rank_col = Color(1.0, 0.85, 0.2) if rank == 1 else Color(0.75, 0.75, 0.78) if rank <= 3 else Color(0.5, 0.52, 0.58)
	rank_lbl.add_theme_color_override("font_color", rank_col)
	row.add_child(rank_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = pname
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(0.4, 0.82, 1.0) if is_me else Color(0.7, 0.72, 0.78))
	row.add_child(name_lbl)

	# ELO
	var elo_lbl = Label.new()
	elo_lbl.text = str(elo)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elo_lbl.custom_minimum_size = Vector2(45, 0)
	elo_lbl.add_theme_font_size_override("font_size", 20)
	elo_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if rank == 1 else Color(0.55, 0.57, 0.62))
	row.add_child(elo_lbl)

	return panel

# =====================
# SETTINGS PANEL
# =====================

func _setup_settings_panel() -> void:
	var oc = _create_overlay()
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	oc.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 630)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.095)
	style.border_color = Color(0.15, 0.17, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	_add_modal_title(vbox, "SETTINGS")
	_add_spacer(vbox, 28)

	# Piece color
	var color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation", 12)
	vbox.add_child(color_row)

	var color_text = Label.new()
	color_text.text = "Your Piece:"
	color_text.add_theme_font_size_override("font_size", 32)
	color_text.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78))
	color_row.add_child(color_text)

	color_label = Label.new()
	color_label.add_theme_font_size_override("font_size", 32)
	color_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	color_row.add_child(color_label)
	_update_color_label()

	_add_spacer(vbox, 12)

	color_toggle_button = _create_modal_button("SWITCH COLORS", Color(0.32, 0.38, 0.52), Color(0.25, 0.3, 0.42))
	color_toggle_button.pressed.connect(func():
		SoundManager.play("click")
		GameSettings.toggle_colors()
		_update_color_label()
		_update_player_model()
	)
	vbox.add_child(color_toggle_button)

	_add_spacer(vbox, 24)
	_add_modal_divider(vbox)
	_add_spacer(vbox, 20)

	# Volume sliders
	var sfx_row = _create_volume_row("SFX Volume")
	vbox.add_child(sfx_row["container"])
	sfx_slider = sfx_row["slider"]
	sfx_value_label = sfx_row["value_label"]
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	sfx_value_label.text = str(int(sfx_slider.value)) + "%"
	sfx_slider.value_changed.connect(func(val):
		GameSettings.set_sfx_volume(val / 100.0)
		sfx_value_label.text = str(int(val)) + "%"
	)

	_add_spacer(vbox, 12)

	var master_row = _create_volume_row("Master Volume")
	vbox.add_child(master_row["container"])
	master_slider = master_row["slider"]
	master_value_label = master_row["value_label"]
	master_slider.value = GameSettings.master_volume * 100.0
	master_value_label.text = str(int(master_slider.value)) + "%"
	master_slider.value_changed.connect(func(val):
		GameSettings.set_master_volume(val / 100.0)
		master_value_label.text = str(int(val)) + "%"
	)

	_add_spacer(vbox, 28)

	var back = _create_modal_button("DONE", Color(0.22, 0.25, 0.35), Color(0.18, 0.2, 0.28))
	back.pressed.connect(func():
		SoundManager.play("click")
		settings_panel.visible = false
	)
	vbox.add_child(back)

	settings_panel = oc

func _update_settings_values() -> void:
	if sfx_slider:
		sfx_slider.value = GameSettings.sfx_volume * 100.0
		sfx_value_label.text = str(int(sfx_slider.value)) + "%"
	if master_slider:
		master_slider.value = GameSettings.master_volume * 100.0
		master_value_label.text = str(int(master_slider.value)) + "%"
	_update_color_label()

# =====================
# SHOP PANEL
# =====================

func _setup_shop_panel() -> void:
	var oc = _create_overlay()
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	oc.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(750, 840)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.095)
	style.border_color = Color(0.15, 0.17, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(32)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	_add_modal_title(vbox, "SHOP")
	_add_spacer(vbox, 8)

	shop_points_label = Label.new()
	shop_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_points_label.add_theme_font_size_override("font_size", 16)
	shop_points_label.add_theme_color_override("font_color", Color(0.4, 0.82, 1.0))
	vbox.add_child(shop_points_label)

	_add_spacer(vbox, 20)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 320)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	shop_content = VBoxContainer.new()
	shop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content.add_theme_constant_override("separation", 8)
	scroll.add_child(shop_content)

	_add_spacer(vbox, 16)

	var unequip = _create_modal_button("REMOVE HAT", Color(0.5, 0.28, 0.28), Color(0.4, 0.2, 0.2))
	unequip.pressed.connect(func():
		SoundManager.play("click")
		PlayerData.equip_hat("")
		_refresh_shop()
		_update_player_model()
	)
	vbox.add_child(unequip)

	_add_spacer(vbox, 10)

	var back = _create_modal_button("DONE", Color(0.22, 0.25, 0.35), Color(0.18, 0.2, 0.28))
	back.pressed.connect(_on_shop_back_pressed)
	vbox.add_child(back)

	shop_panel = oc

func _refresh_shop() -> void:
	for child in shop_content.get_children():
		shop_content.remove_child(child)
		child.queue_free()

	shop_points_label.text = str(PlayerData.total_points) + " points available"

	var hat_ids := PlayerData.SHOP_HATS.keys()
	hat_ids.sort_custom(func(a, b):
		return int(PlayerData.SHOP_HATS[a]["cost"]) < int(PlayerData.SHOP_HATS[b]["cost"])
	)

	for hat_id in hat_ids:
		var hat = PlayerData.SHOP_HATS[hat_id]
		var owned = hat_id in PlayerData.purchased_hats
		var equipped = hat_id == PlayerData.equipped_hat
		var can_afford = PlayerData.total_points >= hat["cost"]

		var item = PanelContainer.new()
		var bg = Color(0.1, 0.13, 0.1) if equipped else Color(0.065, 0.07, 0.1)
		var bdr = Color(0.35, 0.7, 0.45) if equipped else Color(0.12, 0.14, 0.2)
		var s = StyleBoxFlat.new()
		s.bg_color = bg
		s.set_corner_radius_all(8)
		s.border_color = bdr
		s.set_border_width_all(1)
		s.set_content_margin_all(10)
		item.add_theme_stylebox_override("panel", s)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		item.add_child(hbox)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(52, 52)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path = hat.get("tex", "")
		# Don't use ResourceLoader.exists() - it's unreliable in exports
		# Just try to load and handle null gracefully
		if tex_path != "":
			var tex = load(tex_path)
			if tex:
				icon.texture = tex
		hbox.add_child(icon)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		hbox.add_child(info)

		var n = Label.new()
		n.text = hat["name"]
		n.add_theme_font_size_override("font_size", 15)
		n.add_theme_color_override("font_color", Color.WHITE if owned else Color(0.82, 0.82, 0.88))
		info.add_child(n)

		var d = Label.new()
		d.text = hat["desc"]
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.48, 0.5, 0.58))
		info.add_child(d)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(95, 34)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color.WHITE)

		if equipped:
			btn.text = "EQUIPPED"
			_style_shop_btn(btn, Color(0.22, 0.48, 0.32))
			btn.disabled = true
		elif owned:
			btn.text = "EQUIP"
			_style_shop_btn(btn, Color(0.28, 0.58, 0.38))
			btn.pressed.connect(_equip_hat.bind(hat_id))
		elif can_afford:
			btn.text = str(hat["cost"]) + " pts"
			_style_shop_btn(btn, Color(0.28, 0.52, 0.7))
			btn.pressed.connect(_buy_hat.bind(hat_id))
		else:
			btn.text = str(hat["cost"]) + " pts"
			_style_shop_btn(btn, Color(0.25, 0.27, 0.32))
			btn.disabled = true

		hbox.add_child(btn)
		shop_content.add_child(item)

func _style_shop_btn(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(4)
		match state:
			"normal":
				sb.bg_color = color
				sb.border_color = color.lightened(0.1)
				sb.border_width_top = 1
			"hover":
				sb.bg_color = color.lightened(0.08)
				sb.border_color = color.lightened(0.2)
				sb.border_width_top = 1
			"pressed":
				sb.bg_color = color.darkened(0.1)
			"disabled":
				sb.bg_color = color.darkened(0.15)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _buy_hat(hat_id: String) -> void:
	if PlayerData.purchase_hat(hat_id):
		SoundManager.play("purchase")
		PlayerData.equip_hat(hat_id)
		_refresh_shop()
		_update_profile_sidebar()
	else:
		SoundManager.play("error")

func _equip_hat(hat_id: String) -> void:
	SoundManager.play("equip")
	PlayerData.equip_hat(hat_id)
	_refresh_shop()
	_update_player_model()

# =====================
# MODAL HELPERS
# =====================

func _create_overlay() -> Control:
	var oc = Control.new()
	oc.set_anchors_preset(Control.PRESET_FULL_RECT)
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oc)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65)
	oc.add_child(bg)
	return oc

func _add_modal_title(vbox: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	vbox.add_child(lbl)

func _add_modal_divider(vbox: VBoxContainer) -> void:
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = Color(0.18, 0.2, 0.28, 0.6)
	vbox.add_child(div)

func _create_modal_button(text: String, color: Color, dark_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(8)
	normal.border_color = color.lightened(0.12)
	normal.border_width_top = 1
	normal.shadow_color = Color(0, 0, 0, 0.25)
	normal.shadow_size = 2
	normal.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.08)
	hover.set_corner_radius_all(8)
	hover.border_color = color.lightened(0.2)
	hover.border_width_top = 1
	hover.shadow_color = Color(0, 0, 0, 0.3)
	hover.shadow_size = 3
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = dark_color
	pressed.set_corner_radius_all(8)
	pressed.shadow_size = 1
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _create_volume_row(label_text: String) -> Dictionary:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 12)
	row.add_child(header)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.7, 0.78))
	header.add_child(lbl)

	var val_lbl = Label.new()
	val_lbl.text = "100%"
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.22))
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(val_lbl)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(280, 22)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var track = StyleBoxFlat.new()
	track.bg_color = Color(0.15, 0.16, 0.22)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)

	var grabber = StyleBoxFlat.new()
	grabber.bg_color = Color(0.32, 0.52, 0.75)
	grabber.set_corner_radius_all(4)
	grabber.content_margin_top = 4
	grabber.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area", grabber)

	var grabber_hl = StyleBoxFlat.new()
	grabber_hl.bg_color = Color(0.42, 0.62, 0.85)
	grabber_hl.set_corner_radius_all(4)
	grabber_hl.content_margin_top = 4
	grabber_hl.content_margin_bottom = 4
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_hl)

	row.add_child(slider)
	return {"container": row, "slider": slider, "value_label": val_lbl}

# =====================
# FLOATING BACKGROUND
# =====================

func _setup_floating_bg(parent: Control) -> void:
	if piece_textures.is_empty():
		return
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = true
	parent.add_child(container)

	for i in 50:
		var tex = piece_textures[randi() % piece_textures.size()]
		var spr = TextureRect.new()
		spr.texture = tex
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var scale_mult = randf_range(0.4, 1.1)
		spr.custom_minimum_size = Vector2(55 * scale_mult, 55 * scale_mult)
		spr.size = spr.custom_minimum_size
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.modulate = Color(1.0, 1.0, 1.0, randf_range(0.02, 0.055))
		spr.position = Vector2(randf_range(0, 1920), randf_range(0, 1080))
		spr.pivot_offset = spr.size / 2.0
		spr.rotation = randf_range(0, TAU)
		container.add_child(spr)
		bg_pieces.append({
			"sprite": spr,
			"vel": Vector2(randf_range(-8, 8), randf_range(-6, 6)),
			"rot_speed": randf_range(-0.15, 0.15),
			"container": container
		})

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _create_mini_tab(label: String, is_active: bool) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(68, 22)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_mini_tab(btn, is_active)
	return btn

func _style_mini_tab(btn: Button, is_active: bool) -> void:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(4)
	s.set_content_margin_all(3)
	if is_active:
		s.bg_color = Color(0.12, 0.24, 0.14, 0.7)
		s.border_color = Color(0.45, 0.8, 0.5, 0.9)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	else:
		s.bg_color = Color(0.07, 0.07, 0.11, 0.5)
		s.border_color = Color(0.22, 0.22, 0.3, 0.5)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.32, 0.33, 0.42))
	btn.add_theme_stylebox_override("normal", s)
	var hover := s.duplicate() as StyleBoxFlat
	hover.bg_color = s.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)

func _update_color_label() -> void:
	color_label.text = "WHITE" if GameSettings.player_is_white else "BLACK"

func _on_shop_pressed() -> void:
	SoundManager.play("click")
	_refresh_shop()
	shop_panel.visible = true

func _on_shop_back_pressed() -> void:
	SoundManager.play("click")
	shop_panel.visible = false
	_update_profile_sidebar()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if profile_popup and profile_popup.visible:
				SoundManager.play("click")
				profile_popup.visible = false
			elif shop_panel.visible:
				_on_shop_back_pressed()
			elif settings_panel.visible:
				SoundManager.play("click")
				settings_panel.visible = false

# =====================
# PROFILE POPUP
# =====================

func _setup_profile_popup() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	profile_popup = Control.new()
	profile_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_popup.visible = false
	layer.add_child(profile_popup)

	var popup_bg = ColorRect.new()
	popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_bg.color = Color(0, 0, 0, 0.82)
	popup_bg.name = "PopupBG"
	profile_popup.add_child(popup_bg)
	popup_bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			profile_popup.visible = false
	)

func _show_own_profile_popup() -> void:
	var data = {
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
	_show_profile_popup(data, true, "bullet")

func _show_profile_popup(data: Dictionary, is_own: bool = false, start_mode: String = "bullet") -> void:
	for child in profile_popup.get_children():
		if child.name != "PopupBG":
			child.queue_free()
	profile_popup.visible = true

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	profile_popup.add_child(center)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(540, 0)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.06, 0.07, 0.12)
	cs.set_corner_radius_all(18)
	cs.border_color = Color(0.28, 0.32, 0.52)
	cs.set_border_width_all(2)
	cs.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# ── Name ──
	var name_lbl = Label.new()
	name_lbl.text = data.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 42)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# ── Name-change (own profile only) ──
	if is_own:
		var name_row = HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 10)
		vbox.add_child(name_row)

		var name_edit = LineEdit.new()
		name_edit.text = data.get("name", "")
		name_edit.placeholder_text = "Type new name..."
		name_edit.max_length = 16
		name_edit.virtual_keyboard_enabled = true
		name_edit.editable = true
		name_edit.caret_blink = true
		name_edit.custom_minimum_size = Vector2(240, 46)
		name_edit.add_theme_font_size_override("font_size", 20)
		var ne_s = StyleBoxFlat.new()
		ne_s.bg_color = Color(0.1, 0.1, 0.18)
		ne_s.set_corner_radius_all(10)
		ne_s.set_border_width_all(2)
		ne_s.border_color = Color(0.35, 0.45, 0.75)
		ne_s.set_content_margin_all(10)
		name_edit.add_theme_stylebox_override("normal", ne_s)
		name_edit.add_theme_stylebox_override("focus",  ne_s)
		name_row.add_child(name_edit)

		var confirm_btn = Button.new()
		confirm_btn.text = "✓ SAVE"
		confirm_btn.custom_minimum_size = Vector2(110, 46)
		confirm_btn.add_theme_font_size_override("font_size", 18)
		var cb_s = StyleBoxFlat.new()
		cb_s.bg_color = Color(0.08, 0.28, 0.14)
		cb_s.set_corner_radius_all(10)
		cb_s.border_color = Color(0.25, 0.75, 0.4)
		cb_s.set_border_width_all(2)
		cb_s.set_content_margin_all(8)
		confirm_btn.add_theme_stylebox_override("normal", cb_s)
		var cb_h = cb_s.duplicate() as StyleBoxFlat
		cb_h.bg_color = Color(0.12, 0.38, 0.2)
		confirm_btn.add_theme_stylebox_override("hover",   cb_h)
		confirm_btn.add_theme_stylebox_override("pressed", cb_h)
		confirm_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		confirm_btn.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
		confirm_btn.pressed.connect(func():
			var new_name = name_edit.text.strip_edges()
			if new_name.is_empty():
				return
			PlayerData.set_player_name(new_name)
			name_lbl.text = new_name
			_update_profile_sidebar()
		)
		name_edit.text_submitted.connect(func(_t): confirm_btn.emit_signal("pressed"))
		name_row.add_child(confirm_btn)

	_add_spacer(vbox, 4)

	# ── Thin divider ──
	var div = ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	div.color = Color(0.22, 0.25, 0.4, 0.7)
	vbox.add_child(div)

	_add_spacer(vbox, 4)

	# ── Mode tabs ──
	var mode_tab_row = HBoxContainer.new()
	mode_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_tab_row.add_theme_constant_override("separation", 10)
	vbox.add_child(mode_tab_row)

	var mode_tab_btns: Dictionary = {}

	_add_spacer(vbox, 4)

	# Stats container (rebuilt per tab)
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(stats_vbox)

	_add_spacer(vbox, 8)

	# ── Solo section (always visible) ──
	var sep_lbl = Label.new()
	sep_lbl.text = "── SOLO SCORES ──"
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep_lbl.add_theme_font_size_override("font_size", 15)
	sep_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(sep_lbl)

	var solo_vbox = VBoxContainer.new()
	solo_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(solo_vbox)
	_add_profile_stat(solo_vbox, "Best Score",  str(int(data.get("solo_highscore", 0))), Color(0.9, 0.8, 0.35))
	_add_profile_stat(solo_vbox, "Total Games", str(int(data.get("total_games", 0))),     Color(0.6, 0.6, 0.75))

	_add_spacer(vbox, 8)

	# ── Match history header + list (rebuilt per tab) ──
	var hist_hdr = Label.new()
	hist_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hist_hdr.add_theme_font_size_override("font_size", 15)
	hist_hdr.add_theme_color_override("font_color", Color(0.4, 0.4, 0.55))
	vbox.add_child(hist_hdr)

	var hist_vbox = VBoxContainer.new()
	hist_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hist_vbox)

	_add_spacer(vbox, 10)
	var close_hint = Label.new()
	close_hint.text = "ESC or click outside to close"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 14)
	close_hint.add_theme_color_override("font_color", Color(0.3, 0.3, 0.42))
	vbox.add_child(close_hint)

	# Refresh function
	var refresh_fn = func(mode: String) -> void:
		for m in mode_tab_btns:
			_style_profile_tab_btn(mode_tab_btns[m], m == mode)
		for c in stats_vbox.get_children(): c.queue_free()
		_build_profile_stats(mode, data, stats_vbox)
		var icons = {"bullet": "🔫", "blitz": "⚡", "rapid": "⏱"}
		hist_hdr.text = "── " + icons.get(mode, "") + "  " + mode.to_upper() + " MATCHES ──"
		for c in hist_vbox.get_children(): c.queue_free()
		_build_profile_history(mode, data, hist_vbox)

	for tab_mode in ["bullet", "blitz", "rapid"]:
		var icons = {"bullet": "🔫 BULLET", "blitz": "⚡ BLITZ", "rapid": "⏱ RAPID"}
		var tab_btn = _create_profile_tab_btn(icons[tab_mode])
		var cm = tab_mode
		tab_btn.pressed.connect(func():
			SoundManager.play("click")
			refresh_fn.call(cm)
		)
		mode_tab_row.add_child(tab_btn)
		mode_tab_btns[tab_mode] = tab_btn

	refresh_fn.call(start_mode)

func _build_profile_stats(mode: String, data: Dictionary, sv: VBoxContainer) -> void:
	var legacy = int(data.get("elo", 1000))
	var elo = int(data.get("elo_" + mode, legacy if mode == "bullet" else 1000))
	var w   = int(data.get("wins_"   + mode, data.get("wins", 0)))
	var l   = int(data.get("losses_" + mode, data.get("losses", 0)))
	var d   = int(data.get("draws_"  + mode, data.get("draws", 0)))
	var total = w + l + d
	var wr = ("%.1f" % (float(w) / float(total) * 100.0)) + "%" if total > 0 else "—"
	var accent = Color(0.95, 0.78, 0.1) if mode == "bullet" else \
				 (Color(0.2, 0.65, 1.0) if mode == "blitz" else Color(0.2, 0.9, 0.45))
	_add_profile_stat(sv, "ELO",      str(elo), accent)
	_add_profile_stat(sv, "Wins",     str(w),   Color(0.35, 0.92, 0.5))
	_add_profile_stat(sv, "Losses",   str(l),   Color(0.92, 0.35, 0.35))
	_add_profile_stat(sv, "Draws",    str(d),   Color(0.85, 0.85, 0.45))
	_add_profile_stat(sv, "Win Rate", wr,       Color(0.6, 0.6, 0.75))

func _build_profile_history(mode: String, data: Dictionary, hv: VBoxContainer) -> void:
	var match_list = data.get("matches", [])
	if match_list == null or not match_list is Array:
		match_list = []
	var filtered: Array = []
	for m in match_list:
		if m is Dictionary and m.get("time_mode", "bullet") == mode:
			filtered.append(m)
	filtered.reverse()
	var count = mini(filtered.size(), 6)
	if count == 0:
		var lbl = Label.new()
		lbl.text = "No matches yet in this mode."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.38, 0.38, 0.5))
		hv.add_child(lbl)
		return
	for i in count:
		var m = filtered[i]
		var res = m.get("result", "?")
		var ec = m.get("elo_change", 0)
		var ec_str = ("+" if ec >= 0 else "") + str(ec)
		var col = Color(0.35, 0.9, 0.5) if res == "win" else \
				  (Color(0.9, 0.32, 0.32) if res == "lose" else Color(0.8, 0.8, 0.42))
		var row = PanelContainer.new()
		var rs = StyleBoxFlat.new()
		rs.bg_color = Color(col.r, col.g, col.b, 0.06)
		rs.set_corner_radius_all(8)
		rs.border_color = Color(col.r, col.g, col.b, 0.3)
		rs.set_border_width_all(1)
		rs.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", rs)
		var lbl = Label.new()
		lbl.text = res.to_upper() + "   " + str(m.get("my_score", 0)) + " – " + \
				   str(m.get("opp_score", 0)) + "   vs " + m.get("opponent", "???") + \
				   "   (" + ec_str + " ELO)"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", col)
		row.add_child(lbl)
		hv.add_child(row)

func _add_profile_stat(parent: VBoxContainer, label: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	hbox.custom_minimum_size = Vector2(0, 32)
	parent.add_child(hbox)
	var key = Label.new()
	key.text = label + ":"
	key.add_theme_font_size_override("font_size", 19)
	key.add_theme_color_override("font_color", Color(0.48, 0.48, 0.62))
	key.custom_minimum_size = Vector2(150, 0)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(key)
	var val = Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", color)
	val.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(val)

func _create_profile_tab_btn(label: String) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(130, 48)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_profile_tab_btn(btn, false)
	return btn

func _style_profile_tab_btn(btn: Button, is_active: bool) -> void:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(10)
	s.set_content_margin_all(6)
	if is_active:
		s.bg_color = Color(0.12, 0.2, 0.38)
		s.border_color = Color(0.35, 0.62, 1.0)
		s.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		s.bg_color = Color(0.09, 0.09, 0.14)
		s.border_color = Color(0.22, 0.22, 0.32)
		s.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.52))
	btn.add_theme_stylebox_override("normal", s)
	var h = s.duplicate() as StyleBoxFlat
	h.bg_color = s.bg_color.lightened(0.09)
	h.border_color = s.border_color.lightened(0.12)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", h)
