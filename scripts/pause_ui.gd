extends CanvasLayer

## Mobile Pause Button & Menu
## Add this as a child of your main game scene or autoload it
## 
## Usage: 
##   1. Add pause_ui.tscn to your game scene
##   OR
##   2. var pause_ui = preload("res://scenes/pause_ui.tscn").instantiate()
##      add_child(pause_ui)

signal resumed
signal quit_to_menu

var is_paused: bool = false
var pause_panel: Control
var pause_button: Button

func _ready() -> void:
	layer = 100  # Above everything
	_build_ui()

func _build_ui() -> void:
	# Main container for everything
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	
	# Pause button in top-right
	pause_button = Button.new()
	pause_button.text = "❚❚"  # Pause icon
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-80, 20)
	pause_button.custom_minimum_size = Vector2(60, 60)
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.add_theme_color_override("font_color", Color.WHITE)
	_style_pause_button(pause_button)
	pause_button.pressed.connect(_on_pause_pressed)
	root.add_child(pause_button)
	
	# Pause panel (hidden by default)
	pause_panel = _create_pause_panel()
	pause_panel.visible = false
	root.add_child(pause_panel)

func _style_pause_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	normal.set_corner_radius_all(12)
	normal.border_color = Color(0.3, 0.3, 0.4, 0.8)
	normal.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.15, 0.2, 0.85)
	hover.set_corner_radius_all(12)
	hover.border_color = Color(0.4, 0.4, 0.5, 0.9)
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	pressed.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _create_pause_panel() -> Control:
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Dark backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	overlay.add_child(backdrop)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 350)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.065, 0.1)
	style.border_color = Color(0.18, 0.2, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(40)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.25))
	vbox.add_child(title)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Resume button
	var resume_btn = _create_menu_button("RESUME", Color(0.2, 0.6, 0.35))
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	# Quit button
	var quit_btn = _create_menu_button("QUIT TO MENU", Color(0.6, 0.25, 0.25))
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)
	
	return overlay

func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(560, 120)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(10)
	normal.border_color = color.lightened(0.15)
	normal.border_width_top = 2
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.1)
	hover.set_corner_radius_all(10)
	hover.border_color = color.lightened(0.25)
	hover.border_width_top = 2
	hover.shadow_color = Color(0, 0, 0, 0.4)
	hover.shadow_size = 5
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.15)
	pressed.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn

func _on_pause_pressed() -> void:
	if is_paused:
		return
	_pause_game()

func _on_resume_pressed() -> void:
	_resume_game()

func _on_quit_pressed() -> void:
	_resume_game()
	quit_to_menu.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _pause_game() -> void:
	is_paused = true
	get_tree().paused = true
	pause_panel.visible = true
	pause_button.visible = false

func _resume_game() -> void:
	is_paused = false
	get_tree().paused = false
	pause_panel.visible = false
	pause_button.visible = true
	resumed.emit()

func _unhandled_input(event: InputEvent) -> void:
	# ESC key also toggles pause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_paused:
				_resume_game()
			else:
				_pause_game()
			get_viewport().set_input_as_handled()

# Make sure this node processes even when game is paused
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
