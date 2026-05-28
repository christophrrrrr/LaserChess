extends Control
## Intro / Splash Screen
## Short, clean intro with title reveal and visual flair.
##
## SETUP:
## 1. Create a new scene: Scene > New Scene > Other Node > Control
## 2. Attach this script to the root Control node
## 3. Save as  res://scenes/intro.tscn
## 4. Set as main scene: Project > Settings > Application > Run > Main Scene

# === REFERENCES ===
var title_label: Label
var subtitle_label: Label
var press_label: Label
var flash_rect: ColorRect
var fade_rect: ColorRect

# === STATE ===
var _transitioning := false
var _pulse_tween: Tween = null

# === FLOATING BG ===
var _bg_pieces: Array = []
var _piece_textures: Array = []
var _bg_container: Control

func _ready() -> void:
	# ==========================================
	# CRITICAL: Make root Control fill the entire viewport.
	# Without this the scene renders as a tiny box in the top-left.
	# ==========================================
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	size = get_viewport_rect().size

	# === BACKGROUND ===
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.08)
	add_child(bg)

	# === FLOATING CHESS PIECES (subtle, behind everything) ===
	_load_piece_textures()
	_spawn_bg_pieces()

	# === DECORATIVE GRID (mini chess board silhouette at center) ===
	_create_mini_grid()

	# === CENTER CONTENT ===
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	center.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "LASER CHESS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color(0.5, 0.25, 0.0, 0.6))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.modulate.a = 0.0
	vbox.add_child(title_label)

	_add_spacer(vbox, 16)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.text = "Survive the Board"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	subtitle_label.modulate.a = 0.0
	vbox.add_child(subtitle_label)

	_add_spacer(vbox, 80)

	# Press any key / Tap to continue
	press_label = Label.new()
	press_label.text = "Tap to continue" if GameSettings.is_mobile else "Press any key"
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press_label.add_theme_font_size_override("font_size", 28 if GameSettings.is_mobile else 16)
	press_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	press_label.modulate.a = 0.0
	vbox.add_child(press_label)

	# === RED FLASH OVERLAY ===
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.12, 0.08, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# === FADE OVERLAY (starts fully black) ===
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.z_index = 100
	add_child(fade_rect)

	# === START SEQUENCE ===
	SoundManager.play("intro")
	_play_intro()

# =====================
# INTRO ANIMATION
# =====================

func _play_intro() -> void:
	var seq = create_tween()

	# Phase 1: Fade from black (0.0 – 0.6s)
	seq.tween_property(fade_rect, "color:a", 0.0, 0.6)

	# Phase 2: Title fades in (0.6 – 0.95s)
	seq.tween_property(title_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Phase 3: Red flash — impact! (0.95 – 1.25s)
	seq.tween_property(flash_rect, "color:a", 0.22, 0.06)
	seq.tween_property(flash_rect, "color:a", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Phase 4: Subtitle fades in (1.25 – 1.65s)
	seq.tween_property(subtitle_label, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Phase 5: Brief pause, then "Press any key" (1.65 – 2.55s)
	seq.tween_interval(0.6)
	seq.tween_property(press_label, "modulate:a", 1.0, 0.3)
	seq.tween_callback(_start_press_pulse)

	# Phase 6: Auto-advance after a few seconds
	seq.tween_interval(4.0)
	seq.tween_callback(_transition_to_menu)

func _start_press_pulse() -> void:
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(press_label, "modulate:a", 0.25, 0.7).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(press_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

# =====================
# DECORATIVE MINI GRID
# =====================

func _create_mini_grid() -> void:
	## Faint 6×6 grid at center — echoes the game board
	var grid_node = Control.new()
	grid_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_node)

	# Need a centered container for the grid tiles
	var grid_center = CenterContainer.new()
	grid_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_node.add_child(grid_center)

	# Container to hold the grid tiles with fixed size
	var grid_holder = Control.new()
	var tile = 32.0
	var gap = 3.0
	var cols = 6
	var board_size = cols * (tile + gap) - gap
	grid_holder.custom_minimum_size = Vector2(board_size, board_size)
	grid_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_center.add_child(grid_holder)

	for row in cols:
		for col in cols:
			var rect = ColorRect.new()
			rect.size = Vector2(tile, tile)
			rect.position = Vector2(
				col * (tile + gap),
				row * (tile + gap)
			)
			rect.color = Color(0.12, 0.12, 0.2, 0.15)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid_holder.add_child(rect)

	# Fade grid in and out
	grid_node.modulate.a = 0.0
	var t = create_tween()
	t.tween_interval(0.3)
	t.tween_property(grid_node, "modulate:a", 1.0, 0.5)
	t.tween_interval(1.0)
	t.tween_property(grid_node, "modulate:a", 0.0, 1.0)

# =====================
# INPUT — skip on any key
# =====================

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or \
	   (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed):
		get_viewport().set_input_as_handled()
		_transition_to_menu()

# =====================
# TRANSITION
# =====================

func _transition_to_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	if _pulse_tween:
		_pulse_tween.kill()
	SoundManager.play("click")

	fade_rect.z_index = 200
	var t = create_tween()
	t.tween_property(fade_rect, "color:a", 1.0, 0.3)
	t.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)

# =====================
# FLOATING BACKGROUND
# =====================

func _process(delta: float) -> void:
	var vp_size = get_viewport_rect().size
	if vp_size.x < 1:
		vp_size = Vector2(800, 600)

	for piece in _bg_pieces:
		var spr = piece["sprite"] as TextureRect
		if not is_instance_valid(spr):
			continue
		spr.position += piece["vel"] * delta
		spr.rotation += piece["rot_speed"] * delta
		# Wrap around screen edges
		if spr.position.x > vp_size.x + 60:
			spr.position.x = -60
		elif spr.position.x < -60:
			spr.position.x = vp_size.x + 60
		if spr.position.y > vp_size.y + 60:
			spr.position.y = -60
		elif spr.position.y < -60:
			spr.position.y = vp_size.y + 60

func _load_piece_textures() -> void:
	var paths = [
		"res://assets/king.png", "res://assets/rook.png",
		"res://assets/bishop.png", "res://assets/knight.png",
		"res://assets/king1.png", "res://assets/rook1.png",
		"res://assets/bishop1.png", "res://assets/knight1.png"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			_piece_textures.append(load(p))

func _spawn_bg_pieces() -> void:
	if _piece_textures.is_empty():
		return

	_bg_container = Control.new()
	_bg_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_container.clip_contents = true
	add_child(_bg_container)
	# Keep behind content (index 1 = right after background rect)
	move_child(_bg_container, 1)

	var vp_size = get_viewport_rect().size
	if vp_size.x < 1:
		vp_size = Vector2(800, 600)

	for i in 25:
		var tex = _piece_textures[randi() % _piece_textures.size()]
		var spr = TextureRect.new()
		spr.texture = tex
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var scale_mult = randf_range(0.5, 1.3)
		spr.custom_minimum_size = Vector2(48 * scale_mult, 48 * scale_mult)
		spr.size = spr.custom_minimum_size
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.modulate = Color(1.0, 1.0, 1.0, randf_range(0.03, 0.08))
		spr.position = Vector2(randf_range(0, vp_size.x), randf_range(0, vp_size.y))
		spr.pivot_offset = spr.size / 2.0
		spr.rotation = randf_range(0, TAU)
		_bg_container.add_child(spr)
		_bg_pieces.append({
			"sprite": spr,
			"vel": Vector2(randf_range(-12, 12), randf_range(-10, 10)),
			"rot_speed": randf_range(-0.2, 0.2),
		})

# =====================
# HELPERS
# =====================

func _add_spacer(parent: Control, height: float) -> void:
	var s = Control.new()
	s.custom_minimum_size = Vector2(0, height)
	parent.add_child(s)
