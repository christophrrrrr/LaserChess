extends CanvasLayer

@onready var up_btn:    TouchScreenButton = $Root/UpBtn
@onready var down_btn:  TouchScreenButton = $Root/DownBtn
@onready var left_btn:  TouchScreenButton = $Root/LeftBtn
@onready var right_btn: TouchScreenButton = $Root/RightBtn

# Created in code
var _collect_btn:  TouchScreenButton
var _visual_layer: Control   # draws the d-pad background / arrows

func _ready() -> void:
	# --- Directional actions ---
	up_btn.action    = "move_up"
	down_btn.action  = "move_down"
	left_btn.action  = "move_left"
	right_btn.action = "move_right"

	for btn: TouchScreenButton in [up_btn, down_btn, left_btn, right_btn]:
		btn.passby_press = true

	# --- Collect button (board area tap) ---
	_collect_btn = TouchScreenButton.new()
	_collect_btn.action       = "press_button"
	_collect_btn.passby_press = false
	$Root.add_child(_collect_btn)

	# --- Visual layer (drawn below buttons so they still receive input) ---
	_visual_layer = Control.new()
	_visual_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_visual_layer)
	$Root.move_child(_visual_layer, 0)   # draw behind buttons

	_layout()
	get_viewport().size_changed.connect(_layout)
	_apply_visibility()


func _layout() -> void:
	var vp          := get_viewport().get_visible_rect().size
	var is_portrait := vp.y > vp.x

	if is_portrait:
		# ── Portrait: D-pad below the board ──
		# Board is a 1080×1080 square scaled to screen width, centred vertically.
		var canvas_bottom := (vp.y + vp.x) / 2.0
		var dpad_top      := canvas_bottom
		var dpad_h        := vp.y - dpad_top
		if dpad_h < 180.0:      # very little band — fall back to fixed fraction
			dpad_top = vp.y * 0.72
			dpad_h   = vp.y - dpad_top

		var col    := vp.x / 3.0
		var half_h := dpad_h / 2.0

		_place(left_btn,     Vector2(col / 2.0,         dpad_top + dpad_h / 2.0),  Vector2(col, dpad_h))
		_place(right_btn,    Vector2(vp.x - col / 2.0,  dpad_top + dpad_h / 2.0),  Vector2(col, dpad_h))
		_place(up_btn,       Vector2(vp.x / 2.0,         dpad_top + half_h / 2.0),  Vector2(col, half_h))
		_place(down_btn,     Vector2(vp.x / 2.0,         dpad_top + half_h * 1.5),  Vector2(col, half_h))
		_place(_collect_btn, Vector2(vp.x / 2.0,         dpad_top / 2.0),           Vector2(vp.x, dpad_top))

		_draw_visuals(vp, dpad_top, dpad_h, col, half_h)

	else:
		# ── Landscape: split L+D to left band, U+R to right band ──
		# Board fills the screen height (square). Black bands left and right.
		var canvas_w := vp.y
		var band_w   := (vp.x - canvas_w) / 2.0
		var right_x  := (vp.x + canvas_w) / 2.0

		# Left band:  top half = Left, bottom half = Down
		_place(left_btn,  Vector2(band_w / 2.0,            vp.y * 0.25), Vector2(band_w, vp.y * 0.5))
		_place(down_btn,  Vector2(band_w / 2.0,            vp.y * 0.75), Vector2(band_w, vp.y * 0.5))
		# Right band: top half = Up,   bottom half = Right
		_place(up_btn,    Vector2(right_x + band_w / 2.0,  vp.y * 0.25), Vector2(band_w, vp.y * 0.5))
		_place(right_btn, Vector2(right_x + band_w / 2.0,  vp.y * 0.75), Vector2(band_w, vp.y * 0.5))
		# Collect zone = the board itself
		_place(_collect_btn, Vector2(vp.x / 2.0, vp.y / 2.0), Vector2(canvas_w, vp.y))

		_draw_visuals_landscape(vp, band_w, right_x)


# Positions a TouchScreenButton and gives it a rectangle touch shape.
# shape_centered = true (default) → shape is centred on btn.position.
func _place(btn: TouchScreenButton, centre: Vector2, size: Vector2) -> void:
	btn.position = centre
	var shape := RectangleShape2D.new()
	shape.size = size
	btn.shape = shape


func _draw_visuals(vp: Vector2, dpad_y: float, dpad_h: float, col: float, half_h: float) -> void:
	for child in _visual_layer.get_children():
		child.queue_free()

	# Dark background strip for the d-pad zone
	_rect(_visual_layer, Vector2(0, dpad_y), Vector2(vp.x, dpad_h), Color(0, 0, 0, 0.40))

	# Subtle dividing lines
	_rect(_visual_layer, Vector2(col - 1,       dpad_y),           Vector2(2, dpad_h),  Color(1,1,1,0.12))
	_rect(_visual_layer, Vector2(vp.x-col - 1,  dpad_y),           Vector2(2, dpad_h),  Color(1,1,1,0.12))
	_rect(_visual_layer, Vector2(col,            dpad_y+half_h-1),  Vector2(col, 2),     Color(1,1,1,0.12))

	# Arrow labels centred in each zone
	_arrow(_visual_layer, "◀", Vector2(0,             dpad_y),          Vector2(col,   dpad_h))
	_arrow(_visual_layer, "▶", Vector2(vp.x - col,    dpad_y),          Vector2(col,   dpad_h))
	_arrow(_visual_layer, "▲", Vector2(col,            dpad_y),          Vector2(col,   half_h))
	_arrow(_visual_layer, "▼", Vector2(col,            dpad_y + half_h), Vector2(col,   half_h))


func _draw_visuals_landscape(vp: Vector2, band_w: float, right_x: float) -> void:
	for child in _visual_layer.get_children():
		child.queue_free()

	# Dark background for left and right bands
	_rect(_visual_layer, Vector2(0,       0), Vector2(band_w, vp.y), Color(0, 0, 0, 0.40))
	_rect(_visual_layer, Vector2(right_x, 0), Vector2(band_w, vp.y), Color(0, 0, 0, 0.40))

	# Horizontal dividers at mid-height in each band
	_rect(_visual_layer, Vector2(0,       vp.y * 0.5 - 1), Vector2(band_w, 2), Color(1, 1, 1, 0.12))
	_rect(_visual_layer, Vector2(right_x, vp.y * 0.5 - 1), Vector2(band_w, 2), Color(1, 1, 1, 0.12))

	# Arrow labels: left band top=◀, left band bottom=▼, right band top=▲, right band bottom=▶
	_arrow(_visual_layer, "◀", Vector2(0,       0),            Vector2(band_w, vp.y * 0.5))
	_arrow(_visual_layer, "▼", Vector2(0,       vp.y * 0.5),   Vector2(band_w, vp.y * 0.5))
	_arrow(_visual_layer, "▲", Vector2(right_x, 0),            Vector2(band_w, vp.y * 0.5))
	_arrow(_visual_layer, "▶", Vector2(right_x, vp.y * 0.5),   Vector2(band_w, vp.y * 0.5))


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size     = size
	r.color    = color
	parent.add_child(r)


func _arrow(parent: Control, glyph: String, pos: Vector2, size: Vector2) -> void:
	var lbl := Label.new()
	lbl.text     = glyph
	lbl.position = pos
	lbl.size     = size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.50))
	parent.add_child(lbl)


func _apply_visibility() -> void:
	visible = GameSettings.is_mobile and (GameSettings.control_scheme == "d_pad")
