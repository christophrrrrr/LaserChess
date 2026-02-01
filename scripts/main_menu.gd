extends Control

# === MENU ELEMENTS ===
var title_label: Label
var play_button: Button
var settings_button: Button
var profile_button: Button
var ranked_button: Button
var leaderboard_button: Button
var shop_button: Button
var points_display: Label

# === PANELS ===
var settings_panel: Control
var profile_panel: Control
var shop_panel: Control

# === SETTINGS ===
var color_toggle_button: Button
var color_label: Label

# === PROFILE ===
var profile_name_label: Label
var profile_name_edit: LineEdit
var name_edit_button: Button
var elo_label: Label
var high_score_label: Label
var points_label: Label
var record_label: Label
var winrate_label: Label

# === SHOP ===
var shop_content: VBoxContainer
var shop_points_label: Label

# === FLOATING BACKGROUND ===
var bg_pieces: Array = []
var piece_textures: Array = []

func _ready() -> void:
	_load_piece_textures()
	_setup_main_menu()
	_setup_settings_panel()
	_setup_profile_panel()
	_setup_shop_panel()
	settings_panel.visible = false
	profile_panel.visible = false
	shop_panel.visible = false
	_update_points_display()

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
		if sz.x < 1: sz = Vector2(800, 600)
		if spr.position.x > sz.x + 60: spr.position.x = -60
		elif spr.position.x < -60: spr.position.x = sz.x + 60
		if spr.position.y > sz.y + 60: spr.position.y = -60
		elif spr.position.y < -60: spr.position.y = sz.y + 60

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

	for i in 30:
		var tex = piece_textures[randi() % piece_textures.size()]
		var spr = TextureRect.new()
		spr.texture = tex
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var scale_mult = randf_range(0.6, 1.4)
		spr.custom_minimum_size = Vector2(48 * scale_mult, 48 * scale_mult)
		spr.size = spr.custom_minimum_size
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.modulate = Color(1.0, 1.0, 1.0, randf_range(0.04, 0.10))
		spr.position = Vector2(randf_range(0, 800), randf_range(0, 600))
		spr.pivot_offset = spr.size / 2.0
		spr.rotation = randf_range(0, TAU)
		bg_container.add_child(spr)
		bg_pieces.append({
			"sprite": spr,
			"vel": Vector2(randf_range(-15, 15), randf_range(-12, 12)),
			"rot_speed": randf_range(-0.3, 0.3),
			"container": bg_container
		})

# =====================
# MAIN MENU
# =====================

func _setup_main_menu() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12)
	add_child(bg)

	_setup_floating_bg(self)

	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_wrap)

	var center = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	center_wrap.add_child(center)

	title_label = Label.new()
	title_label.text = "LASER CHESS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(title_label)

	var subtitle = Label.new()
	subtitle.text = "Survive the Board"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center.add_child(subtitle)

	_add_spacer(center, 8)

	points_display = Label.new()
	points_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_display.add_theme_font_size_override("font_size", 16)
	points_display.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	center.add_child(points_display)

	_add_spacer(center, 30)

	play_button = _create_menu_button("PLAY", Color(0.0, 0.8, 0.4))
	play_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	center.add_child(play_button)
	_add_spacer(center, 12)

	ranked_button = _create_menu_button("RANKED", Color(0.85, 0.55, 0.1))
	ranked_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ranked_match.tscn"))
	center.add_child(ranked_button)
	_add_spacer(center, 12)

	leaderboard_button = _create_menu_button("LEADERBOARD", Color(0.8, 0.65, 0.1))
	leaderboard_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/leaderboard.tscn"))
	center.add_child(leaderboard_button)
	_add_spacer(center, 12)

	shop_button = _create_menu_button("SHOP", Color(0.3, 0.7, 0.85))
	shop_button.pressed.connect(_on_shop_pressed)
	center.add_child(shop_button)
	_add_spacer(center, 12)

	settings_button = _create_menu_button("SETTINGS", Color(0.3, 0.5, 0.8))
	settings_button.pressed.connect(func(): settings_panel.visible = true)
	center.add_child(settings_button)
	_add_spacer(center, 12)

	profile_button = _create_menu_button("PROFILE", Color(0.6, 0.4, 0.8))
	profile_button.pressed.connect(_on_profile_pressed)
	center.add_child(profile_button)

# =====================
# SETTINGS PANEL
# =====================

func _setup_settings_panel() -> void:
	var oc = _create_overlay()
	var panel = _create_panel_box(oc, Vector2(420, 320), Color(0.3, 0.5, 0.8, 0.8))
	var vbox = _get_panel_vbox(panel)

	_add_panel_title(vbox, "SETTINGS", Color(0.3, 0.5, 0.8))
	_add_spacer(vbox, 30)

	var color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation", 8)
	vbox.add_child(color_row)

	var color_text = Label.new()
	color_text.text = "Your Piece:"
	color_text.add_theme_font_size_override("font_size", 22)
	color_text.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	color_row.add_child(color_text)

	color_label = Label.new()
	color_label.add_theme_font_size_override("font_size", 22)
	color_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	color_row.add_child(color_label)
	_update_color_label()

	_add_spacer(vbox, 20)

	color_toggle_button = _create_panel_button("SWITCH COLORS", Color(0.35, 0.45, 0.65))
	color_toggle_button.pressed.connect(func():
		GameSettings.toggle_colors()
		_update_color_label()
	)
	vbox.add_child(color_toggle_button)

	_add_spacer(vbox, 30)
	_add_separator(vbox)
	_add_spacer(vbox, 20)

	var back = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	back.pressed.connect(func(): settings_panel.visible = false)
	vbox.add_child(back)

	settings_panel = oc

# =====================
# PROFILE PANEL
# =====================

func _setup_profile_panel() -> void:
	var oc = _create_overlay()
	var panel = _create_panel_box(oc, Vector2(440, 460), Color(0.6, 0.4, 0.8, 0.8))
	var vbox = _get_panel_vbox(panel)

	_add_panel_title(vbox, "PROFILE", Color(0.6, 0.4, 0.8))
	_add_spacer(vbox, 20)

	profile_name_label = Label.new()
	profile_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_label.add_theme_font_size_override("font_size", 28)
	profile_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(profile_name_label)

	profile_name_edit = LineEdit.new()
	profile_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_name_edit.max_length = 16
	profile_name_edit.custom_minimum_size = Vector2(200, 36)
	profile_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	profile_name_edit.add_theme_font_size_override("font_size", 22)
	profile_name_edit.visible = false
	profile_name_edit.text_submitted.connect(func(_t): _save_name())
	vbox.add_child(profile_name_edit)

	_add_spacer(vbox, 4)

	name_edit_button = _create_small_button("✎ Change Name", Color(0.25, 0.25, 0.35))
	name_edit_button.pressed.connect(_on_name_edit_pressed)
	vbox.add_child(name_edit_button)

	_add_spacer(vbox, 14)

	elo_label = _add_stat_label(vbox, 22, Color(0.7, 0.7, 0.8))
	_add_spacer(vbox, 6)
	high_score_label = _add_stat_label(vbox, 20, Color(0.6, 0.6, 0.7))
	_add_spacer(vbox, 6)
	points_label = _add_stat_label(vbox, 20, Color(0.4, 0.85, 1.0))
	_add_spacer(vbox, 6)
	record_label = _add_stat_label(vbox, 18, Color(0.55, 0.55, 0.65))
	_add_spacer(vbox, 4)
	winrate_label = _add_stat_label(vbox, 18, Color(0.55, 0.55, 0.65))

	_add_spacer(vbox, 20)
	_add_separator(vbox)
	_add_spacer(vbox, 16)

	var back = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	back.pressed.connect(_on_profile_back_pressed)
	vbox.add_child(back)

	profile_panel = oc

func _add_stat_label(parent: VBoxContainer, font_size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

# =====================
# SHOP PANEL
# =====================

func _setup_shop_panel() -> void:
	var oc = _create_overlay()
	var panel = _create_panel_box(oc, Vector2(460, 520), Color(0.3, 0.7, 0.85, 0.8))
	var vbox = _get_panel_vbox(panel)

	_add_panel_title(vbox, "SHOP", Color(0.3, 0.7, 0.85))
	_add_spacer(vbox, 6)

	shop_points_label = Label.new()
	shop_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_points_label.add_theme_font_size_override("font_size", 18)
	shop_points_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(shop_points_label)

	_add_spacer(vbox, 14)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 280)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	shop_content = VBoxContainer.new()
	shop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content.add_theme_constant_override("separation", 8)
	scroll.add_child(shop_content)

	_add_spacer(vbox, 12)

	var unequip = _create_panel_button("REMOVE HAT", Color(0.4, 0.25, 0.25))
	unequip.pressed.connect(func():
		PlayerData.equip_hat("")
		_refresh_shop()
	)
	vbox.add_child(unequip)

	_add_spacer(vbox, 8)

	var back = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	back.pressed.connect(_on_shop_back_pressed)
	vbox.add_child(back)

	shop_panel = oc

func _refresh_shop() -> void:
	for child in shop_content.get_children():
		shop_content.remove_child(child)
		child.queue_free()

	shop_points_label.text = "Your Points: " + str(PlayerData.total_points)

	for hat_id in PlayerData.SHOP_HATS:
		var hat = PlayerData.SHOP_HATS[hat_id]
		var owned = hat_id in PlayerData.purchased_hats
		var equipped = hat_id == PlayerData.equipped_hat
		var can_afford = PlayerData.total_points >= hat["cost"]

		var item = PanelContainer.new()
		var bg_col = Color(0.12, 0.16, 0.12) if equipped else Color(0.1, 0.1, 0.15)
		var bdr = Color(0.3, 0.8, 0.4) if equipped else Color(0.2, 0.2, 0.3)
		var s = StyleBoxFlat.new()
		s.bg_color = bg_col
		s.set_corner_radius_all(8)
		s.border_color = bdr
		s.set_border_width_all(1)
		s.set_content_margin_all(10)
		item.add_theme_stylebox_override("panel", s)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		item.add_child(hbox)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		hbox.add_child(info)

		var n = Label.new()
		n.text = hat["name"]
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", Color.WHITE if owned else Color(0.8, 0.8, 0.9))
		info.add_child(n)

		var d = Label.new()
		d.text = hat["desc"]
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		info.add_child(d)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 36)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color.WHITE)

		if equipped:
			btn.text = "EQUIPPED"
			_style_action_btn(btn, Color(0.2, 0.5, 0.3))
			btn.disabled = true
		elif owned:
			btn.text = "EQUIP"
			_style_action_btn(btn, Color(0.3, 0.65, 0.4))
			btn.pressed.connect(_equip_hat.bind(hat_id))
		elif can_afford:
			btn.text = str(hat["cost"]) + " pts"
			_style_action_btn(btn, Color(0.3, 0.6, 0.8))
			btn.pressed.connect(_buy_hat.bind(hat_id))
		else:
			btn.text = str(hat["cost"]) + " pts"
			_style_action_btn(btn, Color(0.3, 0.3, 0.35))
			btn.disabled = true

		hbox.add_child(btn)
		shop_content.add_child(item)

func _buy_hat(hat_id: String) -> void:
	if PlayerData.purchase_hat(hat_id):
		PlayerData.equip_hat(hat_id)
		_refresh_shop()
		_update_points_display()

func _equip_hat(hat_id: String) -> void:
	PlayerData.equip_hat(hat_id)
	_refresh_shop()

func _style_action_btn(btn: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.set_content_margin_all(4)
		match state:
			"normal": sb.bg_color = color
			"hover": sb.bg_color = color.lightened(0.15)
			"pressed": sb.bg_color = color.darkened(0.15)
			"disabled": sb.bg_color = color.darkened(0.3)
		btn.add_theme_stylebox_override(state, sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

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
	bd.color = Color(0, 0, 0, 0.5)
	oc.add_child(bd)
	return oc

func _create_panel_box(overlay: Control, min_size: Vector2, border_col: Color) -> PanelContainer:
	var cw = CenterContainer.new()
	cw.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cw)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = min_size
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.08, 0.14)
	s.border_color = border_col
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(30)
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
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", color)
	vbox.add_child(lbl)

func _add_separator(vbox: VBoxContainer) -> void:
	var sep = HSeparator.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.25, 0.35, 0.6)
	s.set_content_margin_all(0)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	vbox.add_child(sep)

# =====================
# BUTTON FACTORIES
# =====================

func _create_menu_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.2)
			"pressed": s.bg_color = color.darkened(0.2)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b

func _create_panel_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed"]:
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(8)
		s.set_content_margin_all(0)
		match state:
			"normal": s.bg_color = color
			"hover": s.bg_color = color.lightened(0.2)
			"pressed": s.bg_color = color.darkened(0.2)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b

func _create_small_button(text: String, color: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 30)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
	s.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", s)
	var sh = s.duplicate()
	sh.bg_color = color.lightened(0.15)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	return b

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _update_color_label() -> void:
	color_label.text = "WHITE" if GameSettings.player_is_white else "BLACK"

func _update_profile_display() -> void:
	profile_name_label.text = PlayerData.player_name
	profile_name_label.visible = true
	profile_name_edit.visible = false
	name_edit_button.text = "✎ Change Name"
	elo_label.text = "ELO: " + str(PlayerData.elo)
	high_score_label.text = "High Score: " + str(PlayerData.solo_highscore)
	points_label.text = "Points: " + str(PlayerData.total_points)
	record_label.text = str(PlayerData.wins) + "W / " + str(PlayerData.losses) + "L / " + str(PlayerData.draws) + "D  (" + str(PlayerData.total_games) + " games)"
	winrate_label.text = "Win Rate: " + (("%.0f" % PlayerData.get_win_rate()) + "%" if PlayerData.total_games > 0 else "—")

func _update_points_display() -> void:
	points_display.text = ("♦ " + str(PlayerData.total_points) + " points") if PlayerData.total_points > 0 else ""

# =====================
# NAME EDITING
# =====================

func _on_name_edit_pressed() -> void:
	if profile_name_edit.visible:
		_save_name()
	else:
		profile_name_label.visible = false
		profile_name_edit.visible = true
		profile_name_edit.text = PlayerData.player_name
		profile_name_edit.grab_focus()
		profile_name_edit.select_all()
		name_edit_button.text = "✓ Save Name"

func _save_name() -> void:
	var new_name = profile_name_edit.text.strip_edges()
	if not new_name.is_empty():
		PlayerData.set_player_name(new_name)
	profile_name_label.text = PlayerData.player_name
	profile_name_label.visible = true
	profile_name_edit.visible = false
	name_edit_button.text = "✎ Change Name"

# =====================
# CALLBACKS
# =====================

func _on_profile_pressed() -> void:
	_update_profile_display()
	profile_panel.visible = true

func _on_profile_back_pressed() -> void:
	if profile_name_edit.visible:
		_save_name()
	profile_panel.visible = false

func _on_shop_pressed() -> void:
	_refresh_shop()
	shop_panel.visible = true

func _on_shop_back_pressed() -> void:
	shop_panel.visible = false
	_update_points_display()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if shop_panel.visible:
				_on_shop_back_pressed()
			elif settings_panel.visible:
				settings_panel.visible = false
			elif profile_panel.visible:
				_on_profile_back_pressed()
