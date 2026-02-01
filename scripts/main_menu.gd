extends Control

# Main menu elements
var title_label: Label
var play_button: Button
var settings_button: Button
var profile_button: Button
var ranked_button: Button

# Settings panel (overlay container, not PanelContainer)
var settings_panel: Control
var color_toggle_button: Button
var color_label: Label
var settings_back_button: Button

# Profile panel (overlay container, not PanelContainer)
var profile_panel: Control
var elo_label: Label
var title_display_label: Label
var high_score_label: Label
var profile_back_button: Button

func _ready() -> void:
	_setup_main_menu()
	_setup_settings_panel()
	_setup_profile_panel()
	
	settings_panel.visible = false
	profile_panel.visible = false

# =====================
# MAIN MENU
# =====================

func _setup_main_menu() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12)
	add_child(bg)
	
	# Use CenterContainer for the entire menu so it's always centered
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_wrap)
	
	var center = VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	center_wrap.add_child(center)
	
	# Title
	title_label = Label.new()
	title_label.text = "LASER CHESS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(title_label)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Survive the Board"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center.add_child(subtitle)
	
	_add_spacer(center, 60)
	
	# Play button
	play_button = _create_menu_button("PLAY", Color(0.0, 0.8, 0.4))
	play_button.pressed.connect(_on_play_pressed)
	center.add_child(play_button)
	
	_add_spacer(center, 15)
	
	# Ranked button
	ranked_button = _create_menu_button("RANKED", Color(0.85, 0.55, 0.1))
	ranked_button.pressed.connect(_on_ranked_pressed)
	center.add_child(ranked_button)
	
	_add_spacer(center, 15)
	
	# Settings button
	settings_button = _create_menu_button("SETTINGS", Color(0.3, 0.5, 0.8))
	settings_button.pressed.connect(_on_settings_pressed)
	center.add_child(settings_button)
	
	_add_spacer(center, 15)
	
	# Profile button
	profile_button = _create_menu_button("PROFILE", Color(0.6, 0.4, 0.8))
	profile_button.pressed.connect(_on_profile_pressed)
	center.add_child(profile_button)

# =====================
# SETTINGS PANEL
# =====================

func _setup_settings_panel() -> void:
	# Full-screen darkened overlay so settings sits on top of menu
	var overlay_container = Control.new()
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_container)
	
	# Semi-transparent backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	overlay_container.add_child(backdrop)
	
	# CenterContainer for the panel
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.add_child(center_wrap)
	
	# Panel itself
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 320)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14)
	style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	center_wrap.add_child(panel)
	
	# Content inside panel
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	# Panel title
	var panel_title = Label.new()
	panel_title.text = "SETTINGS"
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", 36)
	panel_title.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
	vbox.add_child(panel_title)
	
	_add_spacer(vbox, 30)
	
	# Color setting row
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
	
	# Switch Colors button
	color_toggle_button = _create_panel_button("SWITCH COLORS", Color(0.35, 0.45, 0.65))
	color_toggle_button.pressed.connect(_on_color_toggle_pressed)
	vbox.add_child(color_toggle_button)
	
	_add_spacer(vbox, 30)
	
	# Separator line
	var separator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", _create_separator_style())
	vbox.add_child(separator)
	
	_add_spacer(vbox, 20)
	
	# Back button
	settings_back_button = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	vbox.add_child(settings_back_button)
	
	# Store the overlay as our toggle target
	settings_panel = overlay_container

# =====================
# PROFILE PANEL
# =====================

func _setup_profile_panel() -> void:
	# Full-screen darkened overlay
	var overlay_container = Control.new()
	overlay_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_container)
	
	# Semi-transparent backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	overlay_container.add_child(backdrop)
	
	# CenterContainer for the panel
	var center_wrap = CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_container.add_child(center_wrap)
	
	# Panel itself
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14)
	style.border_color = Color(0.6, 0.4, 0.8, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", style)
	center_wrap.add_child(panel)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	
	# Panel title
	var panel_title = Label.new()
	panel_title.text = "PROFILE"
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.add_theme_font_size_override("font_size", 36)
	panel_title.add_theme_color_override("font_color", Color(0.6, 0.4, 0.8))
	vbox.add_child(panel_title)
	
	_add_spacer(vbox, 25)
	
	# Title display (chess rank)
	title_display_label = Label.new()
	title_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_display_label.add_theme_font_size_override("font_size", 28)
	title_display_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title_display_label)
	
	_add_spacer(vbox, 12)
	
	# ELO
	elo_label = Label.new()
	elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_label.add_theme_font_size_override("font_size", 22)
	elo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(elo_label)
	
	_add_spacer(vbox, 8)
	
	# High score
	high_score_label = Label.new()
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_label.add_theme_font_size_override("font_size", 22)
	high_score_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(high_score_label)
	
	_add_spacer(vbox, 30)
	
	# Separator
	var separator = HSeparator.new()
	separator.add_theme_stylebox_override("separator", _create_separator_style())
	vbox.add_child(separator)
	
	_add_spacer(vbox, 20)
	
	# Back button
	profile_back_button = _create_panel_button("BACK", Color(0.3, 0.3, 0.4))
	profile_back_button.pressed.connect(_on_profile_back_pressed)
	vbox.add_child(profile_back_button)
	
	# Store the overlay as our toggle target
	profile_panel = overlay_container

# =====================
# BUTTON FACTORY
# =====================

func _create_menu_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 55)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(8)
	style_normal.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.set_corner_radius_all(8)
	style_hover.set_content_margin_all(0)
	button.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.2)
	style_pressed.set_corner_radius_all(8)
	style_pressed.set_content_margin_all(0)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	var style_focus = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", style_focus)
	
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
	
	return button

func _create_panel_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(8)
	style_normal.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.set_corner_radius_all(8)
	style_hover.set_content_margin_all(0)
	button.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.2)
	style_pressed.set_corner_radius_all(8)
	style_pressed.set_content_margin_all(0)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	var style_focus = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", style_focus)
	
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	
	return button

func _create_separator_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.25, 0.35, 0.6)
	style.set_content_margin_all(0)
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)

func _update_color_label() -> void:
	if GameSettings.player_is_white:
		color_label.text = "WHITE"
	else:
		color_label.text = "BLACK"

func _update_profile_display() -> void:
	title_display_label.text = GameSettings.get_title()
	elo_label.text = "ELO: " + str(GameSettings.get_elo())
	high_score_label.text = "High Score: " + str(GameSettings.high_score)

# =====================
# CALLBACKS
# =====================

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_ranked_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ranked_match.tscn")

func _on_settings_pressed() -> void:
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false

func _on_color_toggle_pressed() -> void:
	GameSettings.toggle_colors()
	_update_color_label()

func _on_profile_pressed() -> void:
	_update_profile_display()
	profile_panel.visible = true

func _on_profile_back_pressed() -> void:
	profile_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if settings_panel.visible:
				settings_panel.visible = false
			elif profile_panel.visible:
				profile_panel.visible = false
