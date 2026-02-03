extends Control

## Main Menu — 3-column layout optimized for 1280×720
## LEFT:   compact leaderboard + Settings button
## CENTER: title + PLAY / RANKED buttons (visual focus)
## RIGHT:  player preview with hat + stats + Shop button

# =====================
# REFERENCES
# =====================

# --- Panels (overlays) ---
var settings_panel: Control
var shop_panel: Control

# --- Settings controls ---
var color_toggle_button: Button
var color_label: Label
var sfx_slider: HSlider
var sfx_value_label: Label
var master_slider: HSlider
var master_value_label: Label

# --- Right column (profile) ---
var profile_name_label: Label
var profile_name_edit: LineEdit
var name_edit_button: Button
var elo_label: Label
var high_score_label: Label
var points_label: Label
var record_label: Label
var winrate_label: Label
var player_preview_instance: Node2D  # Player scene instance for preview

# --- Left column (leaderboard) ---
var lb_content: VBoxContainer

# --- Shop ---
var shop_content: VBoxContainer
var shop_points_label: Label

# --- Floating bg ---
var bg_pieces: Array = []
var piece_textures: Array = []

func _ready() -> void:
	_load_piece_textures()
	_build_layout()
	_setup_settings_panel()
	_setup_shop_panel()
	settings_panel.visible = false
	shop_panel.visible = false
	_update_profile_sidebar()
	_load_mini_leaderboard()
	# Player scene handles hat_changed signal internally

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
		if sz.x < 1: sz = Vector2(1280, 720)
		if spr.position.x > sz.x + 60: spr.position.x = -60
		elif spr.position.x < -60: spr.position.x = sz.x + 60
		if spr.position.y > sz.y + 60: spr.position.y = -60
		elif spr.position.y < -60: spr.position.y = sz.y + 60

# =====================
# LAYOUT
# =====================

func _build_layout() -> void:
	# --- Background ---
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12)
	add_child(bg)

	_setup_floating_bg(self)

	# === MAIN CONTAINER ===
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 40)
	root_margin.add_theme_constant_override("margin_right", 40)
	root_margin.add_theme_constant_override("margin_top", 30)
	root_margin.add_theme_constant_override("margin_bottom", 30)
	add_child(root_margin)

	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 40)
	root_margin.add_child(columns)

	# --- LEFT COLUMN (slim) ---
	var left_col = _build_left_column()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 0.65
	columns.add_child(left_col)

	# --- CENTER COLUMN (dominant) ---
	var center_col = _build_center_column()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.size_flags_stretch_ratio = 1.7
	columns.add_child(center_col)

	# --- RIGHT COLUMN (slim) ---
	var right_col = _build_right_column()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.65
	columns.add_child(right_col)

# =====================
# LEFT COLUMN — leaderboard + settings
# =====================

func _build_left_column() -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER  # Center content vertically

	# Leaderboard panel (no longer SIZE_EXPAND_FILL to avoid stretching)
	var lb_panel = PanelContainer.new()
	lb_panel.custom_minimum_size = Vector2(0, 340)  # Fixed height for the panel
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.12, 0.9)
	ps.set_corner_radius_all(10)
	ps.border_color = Color(0.8, 0.65, 0.1, 0.4)
	ps.set_border_width_all(1)
	ps.set_content_margin_all(12)
	lb_panel.add_theme_stylebox_override("panel", ps)
	col.add_child(lb_panel)

	var lb_vbox = VBoxContainer.new()
	lb_vbox.add_theme_constant_override("separation", 0)
	lb_panel.add_child(lb_vbox)

	# Title
	var lb_title = Label.new()
	lb_title.text = "LEADERBOARD"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.add_theme_font_size_override("font_size", 30)
	lb_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lb_vbox.add_child(lb_title)

	_add_spacer(lb_vbox, 10)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lb_vbox.add_child(scroll)

	lb_content = VBoxContainer.new()
	lb_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb_content.add_theme_constant_override("separation", 2)
	scroll.add_child(lb_content)

	var loading_lbl = Label.new()
	loading_lbl.text = "Loading..."
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.add_theme_font_size_override("font_size", 20)
	loading_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lb_content.add_child(loading_lbl)

	_add_spacer(lb_vbox, 10)

	# View Full button
	var view_btn = _create_compact_button("VIEW ALL", Color(0.7, 0.55, 0.1))
	view_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/leaderboard.tscn")
	)
	lb_vbox.add_child(view_btn)

	_add_spacer(col, 10)

	# Settings button
	var settings_btn = _create_compact_button("SETTINGS", Color(0.3, 0.45, 0.7))
	settings_btn.pressed.connect(func():
		SoundManager.play("click")
		_update_settings_values()
		settings_panel.visible = true
	)
	col.add_child(settings_btn)

	return col

# =====================
# CENTER COLUMN — title + play buttons
# =====================

func _build_center_column() -> VBoxContainer:
	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)

	# Title
	var title = Label.new()
	title.text = "LASER CHESS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 75)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Survive the Board"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	col.add_child(subtitle)

	_add_spacer(col, 60)

	# PLAY button
	var play_btn = _create_main_button("PLAY", Color(0.0, 0.65, 0.32))
	play_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)
	col.add_child(play_btn)

	_add_spacer(col, 14)

	# RANKED button
	var ranked_btn = _create_main_button("RANKED", Color(0.8, 0.45, 0.05))
	ranked_btn.pressed.connect(func():
		SoundManager.play("click")
		get_tree().change_scene_to_file("res://scenes/ranked_match.tscn")
	)
	col.add_child(ranked_btn)

	_add_spacer(col, 50)

	return col

# =====================
# RIGHT COLUMN — player model + stats + shop
# =====================

func _build_right_column() -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER  # Center content vertically

	# Profile panel (no longer SIZE_EXPAND_FILL to avoid stretching)
	var prof_panel = PanelContainer.new()
	prof_panel.custom_minimum_size = Vector2(0, 340)  # Fixed height for the panel
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.12, 0.9)
	ps.set_corner_radius_all(10)
	ps.border_color = Color(0.5, 0.35, 0.7, 0.4)
	ps.set_border_width_all(1)
	ps.set_content_margin_all(12)
	prof_panel.add_theme_stylebox_override("panel", ps)
	col.add_child(prof_panel)

	var prof_vbox = VBoxContainer.new()
	prof_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	prof_vbox.add_theme_constant_override("separation", 0)
	prof_panel.add_child(prof_vbox)

	# --- Character Preview Area ---
	var preview_container = CenterContainer.new()
	preview_container.custom_minimum_size = Vector2(0, 140)
	prof_vbox.add_child(preview_container)

	# Container for the Node2D player
	var player_holder = Control.new()
	player_holder.custom_minimum_size = Vector2(80, 80)
	preview_container.add_child(player_holder)

	# Use actual Player scene for identical hat positioning as in-game
	var player_scene = load("res://scenes/player.tscn")
	player_preview_instance = player_scene.instantiate()
	player_preview_instance.setup_for_menu_preview(80.0)  # 80px tile size for menu
	# Center the Node2D in the holder (Node2D origin is at center of sprite)
	player_preview_instance.position = Vector2(40, 40)
	player_holder.add_child(player_preview_instance)

	# Player name
	profile_name_label = Label.new()
	profile_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_label.add_theme_font_size_override("font_size", 18)
	profile_name_label.add_theme_color_override("font_color", Color.WHITE)
	prof_vbox.add_child(profile_name_label)

	profile_name_edit = LineEdit.new()
	profile_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_edit.max_length = 16
	profile_name_edit.custom_minimum_size = Vector2(140, 26)
	profile_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	profile_name_edit.add_theme_font_size_override("font_size", 14)
	profile_name_edit.visible = false
	profile_name_edit.text_submitted.connect(func(_t): _save_name())
	prof_vbox.add_child(profile_name_edit)

	name_edit_button = _create_tiny_button("Edit", Color(0.2, 0.2, 0.3))
	name_edit_button.pressed.connect(_on_name_edit_pressed)
	prof_vbox.add_child(name_edit_button)

	# Separator before stats
	_add_spacer(prof_vbox, 20)
	_add_thin_separator(prof_vbox)
	_add_spacer(prof_vbox, 20)

	# Stats
	elo_label = _add_stat_label(prof_vbox, 15, Color(1.0, 0.85, 0.2))
	_add_spacer(prof_vbox, 4)
	high_score_label = _add_stat_label(prof_vbox, 13, Color(0.65, 0.65, 0.75))
	_add_spacer(prof_vbox, 4)
	points_label = _add_stat_label(prof_vbox, 13, Color(0.4, 0.8, 1.0))
	_add_spacer(prof_vbox, 4)
	record_label = _add_stat_label(prof_vbox, 12, Color(0.5, 0.5, 0.6))
	_add_spacer(prof_vbox, 2)
	winrate_label = _add_stat_label(prof_vbox, 12, Color(0.5, 0.5, 0.6))

	_add_spacer(col, 10)

	# Shop button
	var shop_btn = _create_compact_button("SHOP", Color(0.25, 0.6, 0.75))
	shop_btn.pressed.connect(_on_shop_pressed)
	col.add_child(shop_btn)

	return col

# =====================
# PLAYER MODEL DISPLAY
# =====================

func _update_player_model() -> void:
	# Player scene instance handles hat display internally
	pass

func _update_profile_sidebar() -> void:
	_update_player_model()

	profile_name_label.text = PlayerData.player_name
	profile_name_label.visible = true
	profile_name_edit.visible = false
	name_edit_button.text = "Edit"

	elo_label.text = "ELO: " + str(PlayerData.elo)
	high_score_label.text = "Best: " + str(PlayerData.solo_highscore)
	points_label.text = str(PlayerData.total_points) + " pts"
	record_label.text = str(PlayerData.wins) + "W " + str(PlayerData.losses) + "L " + str(PlayerData.draws) + "D"
	winrate_label.text = "WR: " + (("%.0f" % PlayerData.get_win_rate()) + "%" if PlayerData.total_games > 0 else "—")

# =====================
# MINI LEADERBOARD
# =====================

func _load_mini_leaderboard() -> void:
	PlayerData.leaderboard_loaded.connect(_on_lb_loaded, CONNECT_ONE_SHOT)
	PlayerData.load_leaderboard()

func _on_lb_loaded(players: Array) -> void:
	for c in lb_content.get_children():
		lb_content.remove_child(c)
		c.queue_free()

	if players.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No players"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		lb_content.add_child(empty_lbl)
		return

	var count = mini(players.size(), 8)
	for i in count:
		var p = players[i]
		var pname = p.get("name", "???")
		var elo = p.get("elo", 0)
		var is_me = p.get("player_id", "") == PlayerData.player_id

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		lb_content.add_child(row)

		var rank_lbl = Label.new()
		rank_lbl.text = str(i + 1) + "."
		rank_lbl.custom_minimum_size = Vector2(20, 0)
		rank_lbl.add_theme_font_size_override("font_size", 11)
		var rank_col = Color(1.0, 0.85, 0.2) if i == 0 else Color(0.7, 0.7, 0.8) if i <= 2 else Color(0.5, 0.5, 0.6)
		rank_lbl.add_theme_color_override("font_color", rank_col)
		row.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.text = pname
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if is_me else Color(0.65, 0.65, 0.75))
		row.add_child(name_lbl)

		var elo_lbl = Label.new()
		elo_lbl.text = str(elo)
		elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		elo_lbl.custom_minimum_size = Vector2(36, 0)
		elo_lbl.add_theme_font_size_override("font_size", 11)
		elo_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if i == 0 else Color(0.55, 0.55, 0.65))
		row.add_child(elo_lbl)

# =====================
# SETTINGS PANEL
# =====================

func _setup_settings_panel() -> void:
	var oc = _create_overlay()
	var panel = _create_panel_box(oc, Vector2(380, 380), Color(0.3, 0.5, 0.8, 0.8))
	var vbox = _get_panel_vbox(panel)

	_add_panel_title(vbox, "SETTINGS", Color(0.3, 0.5, 0.8))
	_add_spacer(vbox, 18)

	# Piece Color
	var color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation", 8)
	vbox.add_child(color_row)

	var color_text = Label.new()
	color_text.text = "Your Piece:"
	color_text.add_theme_font_size_override("font_size", 18)
	color_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	color_row.add_child(color_text)

	color_label = Label.new()
	color_label.add_theme_font_size_override("font_size", 18)
	color_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	color_row.add_child(color_label)
	_update_color_label()

	_add_spacer(vbox, 10)

	color_toggle_button = _create_panel_button("SWITCH", Color(0.35, 0.45, 0.65))
	color_toggle_button.pressed.connect(func():
		SoundManager.play("click")
		GameSettings.toggle_colors()
		_update_color_label()
		_update_player_model()
	)
	vbox.add_child(color_toggle_button)

	_add_spacer(vbox, 16)
	_add_separator(vbox)
	_add_spacer(vbox, 12)

	# SFX Volume
	var sfx_row = _create_volume_row("SFX")
	vbox.add_child(sfx_row["container"])
	sfx_slider = sfx_row["slider"]
	sfx_value_label = sfx_row["value_label"]
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	sfx_value_label.text = str(int(sfx_slider.value)) + "%"
	sfx_slider.value_changed.connect(func(val: float):
		GameSettings.set_sfx_volume(val / 100.0)
		sfx_value_label.text = str(int(val)) + "%"
	)

	_add_spacer(vbox, 8)

	# Master Volume
	var master_row = _create_volume_row("Master")
	vbox.add_child(master_row["container"])
	master_slider = master_row["slider"]
	master_value_label = master_row["value_label"]
	master_slider.value = GameSettings.master_volume * 100.0
	master_value_label.text = str(int(master_slider.value)) + "%"
	master_slider.value_changed.connect(func(val: float):
		GameSettings.set_master_volume(val / 100.0)
		master_value_label.text = str(int(val)) + "%"
	)

	_add_spacer(vbox, 16)
	_add_separator(vbox)
	_add_spacer(vbox, 12)

	var back = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
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
	var panel = _create_panel_box(oc, Vector2(420, 480), Color(0.3, 0.7, 0.85, 0.8))
	var vbox = _get_panel_vbox(panel)

	_add_panel_title(vbox, "SHOP", Color(0.3, 0.7, 0.85))
	_add_spacer(vbox, 6)

	shop_points_label = Label.new()
	shop_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_points_label.add_theme_font_size_override("font_size", 16)
	shop_points_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(shop_points_label)

	_add_spacer(vbox, 12)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	shop_content = VBoxContainer.new()
	shop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content.add_theme_constant_override("separation", 4)
	scroll.add_child(shop_content)

	_add_spacer(vbox, 10)

	var unequip = _create_panel_button("REMOVE HAT", Color(0.4, 0.25, 0.25))
	unequip.pressed.connect(func():
		SoundManager.play("click")
		PlayerData.equip_hat("")
		_refresh_shop()
		_update_player_model()
	)
	vbox.add_child(unequip)

	_add_spacer(vbox, 6)

	var back = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	back.pressed.connect(_on_shop_back_pressed)
	vbox.add_child(back)

	shop_panel = oc

func _refresh_shop() -> void:
	for child in shop_content.get_children():
		shop_content.remove_child(child)
		child.queue_free()

	shop_points_label.text = str(PlayerData.total_points) + " points"

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
		var bg_col = Color(0.12, 0.15, 0.12) if equipped else Color(0.1, 0.1, 0.14)
		var bdr = Color(0.3, 0.75, 0.4) if equipped else Color(0.2, 0.2, 0.28)
		var s = StyleBoxFlat.new()
		s.bg_color = bg_col
		s.set_corner_radius_all(6)
		s.border_color = bdr
		s.set_border_width_all(1)
		s.set_content_margin_all(5)
		item.add_theme_stylebox_override("panel", s)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		item.add_child(hbox)

		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var tex_path = hat.get("tex", "")
		if tex_path != "" and ResourceLoader.exists(tex_path):
			icon.texture = load(tex_path)
		hbox.add_child(icon)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 1)
		hbox.add_child(info)

		var n = Label.new()
		n.text = hat["name"]
		n.add_theme_font_size_override("font_size", 13)
		n.add_theme_color_override("font_color", Color.WHITE if owned else Color(0.8, 0.8, 0.88))
		info.add_child(n)

		var d = Label.new()
		d.text = hat["desc"]
		d.add_theme_font_size_override("font_size", 10)
		d.add_theme_color_override("font_color", Color(0.5, 0.5, 0.58))
		info.add_child(d)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 26)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color.WHITE)

		if equipped:
			btn.text = "EQUIPPED"
			_style_action_btn(btn, Color(0.2, 0.45, 0.28))
			btn.disabled = true
		elif owned:
			btn.text = "EQUIP"
			_style_action_btn(btn, Color(0.28, 0.58, 0.38))
			btn.pressed.connect(_equip_hat.bind(hat_id))
		elif can_afford:
			btn.text = str(hat["cost"]) + " pts"
			_style_action_btn(btn, Color(0.28, 0.55, 0.72))
			btn.pressed.connect(_buy_hat.bind(hat_id))
		else:
			btn.text = str(hat["cost"]) + " pts"
			_style_action_btn(btn, Color(0.28, 0.28, 0.32))
			btn.disabled = true

		hbox.add_child(btn)
		shop_content.add_child(item)

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

func _style_action_btn(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(3)
		match state:
			"normal": sb.bg_color = color
			"hover": sb.bg_color = color.lightened(0.12)
			"pressed": sb.bg_color = color.darkened(0.12)
			"disabled": sb.bg_color = color.darkened(0.25)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# =====================
# FLOATING BG
# =====================

func _setup_floating_bg(parent: Control) -> void:
	if piece_textures.is_empty():
		return
	var bg_container = Control.new()
	bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_container.clip_contents = true
	parent.add_child(bg_container)

	for i in 35:
		var tex = piece_textures[randi() % piece_textures.size()]
		var spr = TextureRect.new()
		spr.texture = tex
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var scale_mult = randf_range(0.5, 1.2)
		spr.custom_minimum_size = Vector2(44 * scale_mult, 44 * scale_mult)
		spr.size = spr.custom_minimum_size
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.modulate = Color(1.0, 1.0, 1.0, randf_range(0.03, 0.08))
		spr.position = Vector2(randf_range(0, 1280), randf_range(0, 720))
		spr.pivot_offset = spr.size / 2.0
		spr.rotation = randf_range(0, TAU)
		bg_container.add_child(spr)
		bg_pieces.append({
			"sprite": spr,
			"vel": Vector2(randf_range(-12, 12), randf_range(-10, 10)),
			"rot_speed": randf_range(-0.25, 0.25),
			"container": bg_container
		})

# =====================
# PANEL FACTORIES
# =====================

func _create_overlay() -> Control:
	var oc = Control.new()
	oc.set_anchors_preset(Control.PRESET_FULL_RECT)
	oc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(oc)
	var bd = ColorRect.new()
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	bd.color = Color(0, 0, 0, 0.55)
	oc.add_child(bd)
	return oc

func _create_panel_box(overlay: Control, min_size: Vector2, border_col: Color) -> PanelContainer:
	var cw = CenterContainer.new()
	cw.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cw)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = min_size
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.07, 0.12)
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", s)
	cw.add_child(panel)
	return panel

func _get_panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	return vbox

func _add_panel_title(vbox: VBoxContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	vbox.add_child(lbl)

func _add_separator(vbox: VBoxContainer) -> void:
	var sep = HSeparator.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.25, 0.35, 0.5)
	s.set_content_margin_all(0)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	vbox.add_child(sep)

func _add_thin_separator(vbox: VBoxContainer) -> void:
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = Color(0.3, 0.3, 0.4, 0.4)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

# =====================
# BUTTON FACTORIES
# =====================

func _create_main_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(10)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.15)
			"pressed": s.bg_color = color.darkened(0.15)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b

func _create_compact_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.15)
			"pressed": s.bg_color = color.darkened(0.15)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b

func _create_panel_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(7)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.15)
			"pressed": s.bg_color = color.darkened(0.15)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b

func _create_tiny_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(50, 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	s.set_content_margin_all(2)
	b.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = color.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	return b

func _create_volume_row(label_text: String) -> Dictionary:
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	row.add_child(header)

	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	header.add_child(lbl)

	var val_lbl = Label.new()
	val_lbl.text = "100%"
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(val_lbl)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(220, 20)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.2, 0.2, 0.28)
	track_style.set_corner_radius_all(3)
	track_style.content_margin_top = 3
	track_style.content_margin_bottom = 3
	slider.add_theme_stylebox_override("slider", track_style)

	var grabber_area = StyleBoxFlat.new()
	grabber_area.bg_color = Color(0.3, 0.5, 0.75)
	grabber_area.set_corner_radius_all(3)
	grabber_area.content_margin_top = 3
	grabber_area.content_margin_bottom = 3
	slider.add_theme_stylebox_override("grabber_area", grabber_area)

	var grabber_highlight = StyleBoxFlat.new()
	grabber_highlight.bg_color = Color(0.4, 0.6, 0.85)
	grabber_highlight.set_corner_radius_all(3)
	grabber_highlight.content_margin_top = 3
	grabber_highlight.content_margin_bottom = 3
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_highlight)

	row.add_child(slider)

	return {"container": row, "slider": slider, "value_label": val_lbl}

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _add_stat_label(parent: VBoxContainer, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

func _update_color_label() -> void:
	color_label.text = "WHITE" if GameSettings.player_is_white else "BLACK"

# =====================
# NAME EDITING
# =====================

func _on_name_edit_pressed() -> void:
	SoundManager.play("click")
	if profile_name_edit.visible:
		_save_name()
	else:
		profile_name_label.visible = false
		profile_name_edit.visible = true
		profile_name_edit.text = PlayerData.player_name
		profile_name_edit.grab_focus()
		profile_name_edit.select_all()
		name_edit_button.text = "Save"

func _save_name() -> void:
	var new_name = profile_name_edit.text.strip_edges()
	if not new_name.is_empty():
		PlayerData.set_player_name(new_name)
	profile_name_label.text = PlayerData.player_name
	profile_name_label.visible = true
	profile_name_edit.visible = false
	name_edit_button.text = "Edit"

# =====================
# CALLBACKS
# =====================

func _on_shop_pressed() -> void:
	SoundManager.play("click")
	_refresh_shop()
	shop_panel.visible = true

func _on_shop_back_pressed() -> void:
	SoundManager.play("click")
	shop_panel.visible = false
	_update_profile_sidebar()

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if shop_panel.visible:
				_on_shop_back_pressed()
			elif settings_panel.visible:
				SoundManager.play("click")
				settings_panel.visible = false
