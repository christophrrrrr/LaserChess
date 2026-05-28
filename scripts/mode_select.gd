extends Control
## Mode selection screen — shown before entering ranked matchmaking.
## Player picks Bullet / Blitz / Rapid and sees their ELO for each mode.

const MODES = [
	{"key": "bullet", "name": "BULLET", "time": "1:30", "icon": "🔫",
		"desc": "Fast & intense",
		"accent": Color(0.95, 0.78, 0.1),
		"bg":     Color(0.12, 0.10, 0.03)},
	{"key": "blitz",  "name": "BLITZ",  "time": "3:00", "icon": "⚡",
		"desc": "Balanced play",
		"accent": Color(0.2,  0.65, 1.0),
		"bg":     Color(0.03, 0.09, 0.14)},
	{"key": "rapid",  "name": "RAPID",  "time": "5:00", "icon": "⏱",
		"desc": "Tactical depth",
		"accent": Color(0.2,  0.9,  0.45),
		"bg":     Color(0.03, 0.12, 0.06)},
]

var _hud: CanvasLayer

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_build_ui()

# =====================
# BUILD UI
# =====================

func _build_ui() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08)
	_hud.add_child(bg)

	# Title
	var title = Label.new()
	title.text = "RANKED MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-160, 30)
	title.custom_minimum_size = Vector2(320, 0)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.1))
	_hud.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Choose your time control"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-160, 82)
	subtitle.custom_minimum_size = Vector2(320, 0)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	_hud.add_child(subtitle)

	# Card layout — portrait: vertical stack; landscape: horizontal row
	var vp := get_viewport().get_visible_rect().size
	var is_portrait := GameSettings.is_mobile and (vp.y > vp.x)

	if is_portrait:
		# Full-rect margin container so cards fill the width with side padding
		var card_margin = MarginContainer.new()
		card_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_margin.add_theme_constant_override("margin_left",   24)
		card_margin.add_theme_constant_override("margin_right",  24)
		card_margin.add_theme_constant_override("margin_top",    130)  # below title area
		card_margin.add_theme_constant_override("margin_bottom", 20)
		_hud.add_child(card_margin)

		var card_col = VBoxContainer.new()
		card_col.add_theme_constant_override("separation", 20)
		card_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_margin.add_child(card_col)

		for mode in MODES:
			var card := _build_card(mode)
			card.custom_minimum_size = Vector2(0, 0)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			card_col.add_child(card)
	else:
		# Landscape: original centred horizontal row
		var card_wrap = CenterContainer.new()
		card_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_wrap.add_theme_constant_override("margin_top", 0)
		_hud.add_child(card_wrap)

		var card_row = HBoxContainer.new()
		card_row.add_theme_constant_override("separation", 32)
		card_row.alignment = BoxContainer.ALIGNMENT_CENTER
		card_wrap.add_child(card_row)

		for mode in MODES:
			card_row.add_child(_build_card(mode))

	# Back button
	var back_layer = CanvasLayer.new()
	back_layer.layer = 100
	add_child(back_layer)

	var back_root = Control.new()
	back_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_layer.add_child(back_root)

	var safe_top_ms := 0
	if GameSettings.is_mobile:
		var r_ms := DisplayServer.get_display_safe_area()
		safe_top_ms = maxi(r_ms.position.y, 72)

	var back_btn = Button.new()
	back_btn.text = "< BACK"
	back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_btn.position = Vector2(20, 20 + safe_top_ms)
	back_btn.custom_minimum_size = Vector2(120, 50) if not GameSettings.is_mobile else Vector2(160, 80)
	back_btn.add_theme_font_size_override("font_size", 20 if not GameSettings.is_mobile else 28)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	_style_back_button(back_btn)
	back_btn.pressed.connect(_on_back_pressed)
	back_root.add_child(back_btn)

	# ESC hint (PC only)
	if not GameSettings.is_mobile:
		var hint = Label.new()
		hint.text = "ESC to go back"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		hint.position = Vector2(-80, -28)
		hint.custom_minimum_size = Vector2(160, 0)
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.45))
		_hud.add_child(hint)

func _build_card(mode: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 340)

	var accent: Color = mode["accent"]
	var bg_col: Color = mode["bg"]

	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(18)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	# Icon
	var icon_lbl = Label.new()
	icon_lbl.text = mode["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_lbl)

	# Mode name
	var name_lbl = Label.new()
	name_lbl.text = mode["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", accent)
	vbox.add_child(name_lbl)

	# Time
	var time_lbl = Label.new()
	time_lbl.text = mode["time"]
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.add_theme_font_size_override("font_size", 26)
	time_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(time_lbl)

	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = mode["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	vbox.add_child(desc_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# ELO display
	var elo_val = PlayerData.get_elo_for_mode(mode["key"])
	var elo_lbl = Label.new()
	elo_lbl.text = "ELO  " + str(elo_val)
	elo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_lbl.add_theme_font_size_override("font_size", 20)
	elo_lbl.add_theme_color_override("font_color", accent.lightened(0.2))
	vbox.add_child(elo_lbl)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Play button
	var play_btn = Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(160, 52)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_btn.add_theme_font_size_override("font_size", 22)
	play_btn.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	_style_play_button(play_btn, accent)
	play_btn.pressed.connect(_on_play_pressed.bind(mode["key"]))
	vbox.add_child(play_btn)

	# Hover effect — brighten border on mouse enter/exit
	card.mouse_entered.connect(func():
		var s = StyleBoxFlat.new()
		s.bg_color = bg_col.lightened(0.06)
		s.set_corner_radius_all(18)
		s.border_color = accent
		s.set_border_width_all(3)
		s.set_content_margin_all(28)
		card.add_theme_stylebox_override("panel", s)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", style)
	)

	return card

func _style_play_button(btn: Button, accent: Color) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = accent
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = accent.lightened(0.15)
	hover.set_corner_radius_all(10)
	hover.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = accent.darkened(0.15)
	pressed.set_corner_radius_all(10)
	pressed.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_back_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	normal.set_corner_radius_all(10)
	normal.border_color = Color(0.3, 0.3, 0.4, 0.9)
	normal.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	hover.set_corner_radius_all(10)
	hover.border_color = Color(0.45, 0.45, 0.55, 1.0)
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_s = StyleBoxFlat.new()
	pressed_s.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	pressed_s.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			SoundManager.play("click")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# =====================
# CALLBACKS
# =====================

func _on_play_pressed(mode_key: String) -> void:
	SoundManager.play("click")
	GameSettings.ranked_time_mode = mode_key
	get_tree().change_scene_to_file("res://scenes/ranked_match.tscn")

func _on_back_pressed() -> void:
	SoundManager.play("click")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
