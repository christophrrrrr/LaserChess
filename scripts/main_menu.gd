extends Control

var title_label: Label
var play_button: Button
var settings_button: Button
var profile_button: Button

var settings_panel: PanelContainer
var color_toggle_button: Button
var color_label: Label
var back_button: Button

var profile_panel: PanelContainer
var elo_label: Label
var title_display_label: Label
var high_score_label: Label
var profile_back_button: Button

func _ready() -> void:
	_setup_main_menu()
	_setup_settings_panel()
	_setup_profile_panel()
	
	# Hide panels initially
	settings_panel.visible = false
	profile_panel.visible = false

func _setup_main_menu() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12)
	add_child(bg)
	
	# Center container
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-150, -200)
	center.custom_minimum_size = Vector2(300, 400)
	add_child(center)
	
	# Title
	title_label = Label.new()
	title_label.text = "LASER CHESS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	center.add_child(title_label)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Survive the Board"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	center.add_child(subtitle)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	center.add_child(spacer)
	
	# Play button
	play_button = _create_button("PLAY", Color(0.0, 0.8, 0.4))
	play_button.pressed.connect(_on_play_pressed)
	center.add_child(play_button)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	center.add_child(spacer2)
	
	# Settings button
	settings_button = _create_button("SETTINGS", Color(0.3, 0.5, 0.8))
	settings_button.pressed.connect(_on_settings_pressed)
	center.add_child(settings_button)
	
	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 15)
	center.add_child(spacer3)
	
	# Profile button
	profile_button = _create_button("PROFILE", Color(0.6, 0.4, 0.8))
	profile_button.pressed.connect(_on_profile_pressed)
	center.add_child(profile_button)

func _setup_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-175, -120)
	settings_panel.custom_minimum_size = Vector2(350, 240)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	settings_panel.add_child(vbox)
	
	# Title
	var settings_title = Label.new()
	settings_title.text = "SETTINGS"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(settings_title)
	
	# Color setting row
	var color_row = HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(color_row)
	
	var color_text = Label.new()
	color_text.text = "Your Color: "
	color_text.add_theme_font_size_override("font_size", 20)
	color_row.add_child(color_text)
	
	color_label = Label.new()
	color_label.add_theme_font_size_override("font_size", 20)
	color_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	color_row.add_child(color_label)
	_update_color_label()
	
	# Toggle button
	color_toggle_button = _create_button("SWITCH COLORS", Color(0.5, 0.5, 0.6))
	color_toggle_button.pressed.connect(_on_color_toggle_pressed)
	vbox.add_child(color_toggle_button)
	
	# Back button
	back_button = _create_button("BACK", Color(0.4, 0.4, 0.5))
	back_button.pressed.connect(_on_settings_back_pressed)
	vbox.add_child(back_button)

func _setup_profile_panel() -> void:
	profile_panel = PanelContainer.new()
	profile_panel.set_anchors_preset(Control.PRESET_CENTER)
	profile_panel.position = Vector2(-175, -140)
	profile_panel.custom_minimum_size = Vector2(350, 280)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.5, 0.3, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	profile_panel.add_theme_stylebox_override("panel", style)
	add_child(profile_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	profile_panel.add_child(vbox)
	
	# Title
	var profile_title = Label.new()
	profile_title.text = "PROFILE"
	profile_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profile_title.add_theme_font_size_override("font_size", 32)
	profile_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(profile_title)
	
	# Title display
	title_display_label = Label.new()
	title_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_display_label.add_theme_font_size_override("font_size", 24)
	title_display_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title_display_label)
	
	# ELO
	elo_label = Label.new()
	elo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elo_label.add_theme_font_size_override("font_size", 20)
	elo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(elo_label)
	
	# High score
	high_score_label = Label.new()
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_label.add_theme_font_size_override("font_size", 18)
	high_score_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	vbox.add_child(high_score_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	# Back button
	profile_back_button = _create_button("BACK", Color(0.4, 0.4, 0.5))
	profile_back_button.pressed.connect(_on_profile_back_pressed)
	vbox.add_child(profile_back_button)

func _create_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 50)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style_normal)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color.lightened(0.2)
	style_hover.set_corner_radius_all(6)
	button.add_theme_stylebox_override("hover", style_hover)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = color.darkened(0.2)
	style_pressed.set_corner_radius_all(6)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	
	return button

func _update_color_label() -> void:
	if GameSettings.player_is_white:
		color_label.text = "WHITE (King)"
	else:
		color_label.text = "BLACK (King)"

func _update_profile_display() -> void:
	title_display_label.text = GameSettings.get_title()
	elo_label.text = "ELO: " + str(GameSettings.get_elo())
	high_score_label.text = "High Score: " + str(GameSettings.high_score)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

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
