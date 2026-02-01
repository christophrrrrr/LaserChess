extends Node2D

signal died

@export var move_duration: float = 0.08

var grid_pos: Vector2i = Vector2i(2, 2)
var is_moving: bool = false
var grid_size: int = 6
var is_dead: bool = false

var game_board: Node2D

var sprite: Sprite2D
var glow: Sprite2D
var king_texture: Texture2D
var hat_node: Node2D = null

# Track keys pressed this frame for clean "just pressed" on raw keycodes
var _keys_this_frame: Array = []

func _ready() -> void:
	game_board = get_parent().get_node("GameBoard")
	grid_size = game_board.grid_size

	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)

	_setup_visuals()
	_create_hat()
	PlayerData.hat_changed.connect(_on_hat_changed)

func _setup_visuals() -> void:
	king_texture = load(GameSettings.get_player_king_texture())

	var tex_size = king_texture.get_size()
	var target_size = game_board.tile_size * 0.75
	var scale_factor = target_size / max(tex_size.x, tex_size.y)

	glow = Sprite2D.new()
	glow.texture = king_texture
	glow.scale = Vector2(scale_factor * 1.25, scale_factor * 1.25)
	glow.modulate = Color(1.0, 0.8, 0.0, 0.5)
	glow.z_index = -1
	add_child(glow)

	sprite = Sprite2D.new()
	sprite.texture = king_texture
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	add_child(sprite)

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", 0.7, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 0.3, 0.4).set_trans(Tween.TRANS_SINE)

# =====================
# HAT SYSTEM
# =====================

func _on_hat_changed(_hat_id: String) -> void:
	_create_hat()

func _create_hat() -> void:
	if hat_node:
		hat_node.queue_free()
		hat_node = null

	var hat_id = PlayerData.equipped_hat
	if hat_id.is_empty():
		return

	hat_node = Node2D.new()
	hat_node.z_index = 2
	add_child(hat_node)

	match hat_id:
		"party_hat":
			_build_party_hat()
		"crown":
			_build_crown()
		"devil_horns":
			_build_devil_horns()
		"top_hat":
			_build_top_hat()
		"wizard_hat":
			_build_wizard_hat()
		"halo":
			_build_halo()

func _build_party_hat() -> void:
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-10, -22), Vector2(0, -42), Vector2(10, -22)
	])
	poly.color = Color(1.0, 0.2, 0.3)
	hat_node.add_child(poly)
	# Stripe
	var stripe = Polygon2D.new()
	stripe.polygon = PackedVector2Array([
		Vector2(-6, -28), Vector2(0, -38), Vector2(6, -28)
	])
	stripe.color = Color(1.0, 0.85, 0.1)
	hat_node.add_child(stripe)
	# Tip ball
	var ball = Polygon2D.new()
	ball.polygon = _circle_points(Vector2(0, -42), 3, 8)
	ball.color = Color(0.2, 0.8, 1.0)
	hat_node.add_child(ball)

func _build_crown() -> void:
	var poly = Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(-14, -30), Vector2(-8, -26),
		Vector2(-4, -36), Vector2(0, -28), Vector2(4, -36),
		Vector2(8, -26), Vector2(14, -30), Vector2(14, -22)
	])
	poly.color = Color(1.0, 0.8, 0.1)
	hat_node.add_child(poly)
	# Gems
	for xp in [-4, 0, 4]:
		var gem = Polygon2D.new()
		gem.polygon = _circle_points(Vector2(xp, -25), 2, 6)
		gem.color = Color(0.9, 0.1, 0.2) if xp != 0 else Color(0.1, 0.5, 1.0)
		hat_node.add_child(gem)

func _build_devil_horns() -> void:
	# Left horn
	var left = Polygon2D.new()
	left.polygon = PackedVector2Array([
		Vector2(-12, -22), Vector2(-16, -40), Vector2(-6, -26)
	])
	left.color = Color(0.85, 0.1, 0.1)
	hat_node.add_child(left)
	# Right horn
	var right = Polygon2D.new()
	right.polygon = PackedVector2Array([
		Vector2(12, -22), Vector2(16, -40), Vector2(6, -26)
	])
	right.color = Color(0.85, 0.1, 0.1)
	hat_node.add_child(right)

func _build_top_hat() -> void:
	# Brim
	var brim = Polygon2D.new()
	brim.polygon = PackedVector2Array([
		Vector2(-16, -22), Vector2(16, -22), Vector2(16, -24), Vector2(-16, -24)
	])
	brim.color = Color(0.12, 0.12, 0.18)
	hat_node.add_child(brim)
	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-10, -24), Vector2(10, -24), Vector2(10, -44), Vector2(-10, -44)
	])
	body.color = Color(0.12, 0.12, 0.18)
	hat_node.add_child(body)
	# Band
	var band = Polygon2D.new()
	band.polygon = PackedVector2Array([
		Vector2(-10, -26), Vector2(10, -26), Vector2(10, -29), Vector2(-10, -29)
	])
	band.color = Color(0.6, 0.15, 0.15)
	hat_node.add_child(band)

func _build_wizard_hat() -> void:
	# Main cone
	var cone = Polygon2D.new()
	cone.polygon = PackedVector2Array([
		Vector2(-14, -22), Vector2(0, -50), Vector2(14, -22)
	])
	cone.color = Color(0.35, 0.15, 0.65)
	hat_node.add_child(cone)
	# Brim
	var brim = Polygon2D.new()
	brim.polygon = PackedVector2Array([
		Vector2(-18, -22), Vector2(18, -22), Vector2(16, -20), Vector2(-16, -20)
	])
	brim.color = Color(0.3, 0.12, 0.55)
	hat_node.add_child(brim)
	# Stars
	var star1 = Polygon2D.new()
	star1.polygon = _star_points(Vector2(-3, -32), 3.0)
	star1.color = Color(1.0, 0.9, 0.3)
	hat_node.add_child(star1)
	var star2 = Polygon2D.new()
	star2.polygon = _star_points(Vector2(4, -38), 2.5)
	star2.color = Color(1.0, 0.9, 0.3)
	hat_node.add_child(star2)

func _build_halo() -> void:
	# Golden ring floating above
	var ring_y = -38.0
	var outer_r = 14.0
	var inner_r = 10.0
	var segments = 16

	# Outer ring
	var outer_pts: PackedVector2Array = _circle_points(Vector2(0, ring_y), outer_r, segments)
	var inner_pts: PackedVector2Array = _circle_points(Vector2(0, ring_y), inner_r, segments)

	# Create ring as two overlapping polygons
	var outer = Polygon2D.new()
	outer.polygon = outer_pts
	outer.color = Color(1.0, 0.85, 0.2, 0.85)
	hat_node.add_child(outer)

	var inner = Polygon2D.new()
	inner.polygon = inner_pts
	inner.color = Color(0, 0, 0, 0)  # transparent punch-through
	hat_node.add_child(inner)

	# Use a floating animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(hat_node, "position:y", -3.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(hat_node, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)

func _circle_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in segments:
		var angle = TAU * i / segments
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts

func _star_points(center: Vector2, size: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in 10:
		var angle = TAU * i / 10 - PI / 2
		var r = size if i % 2 == 0 else size * 0.4
		pts.append(center + Vector2(cos(angle), sin(angle)) * r)
	return pts

# =====================
# INPUT
# =====================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_keys_this_frame.append(event.keycode)

func _process(_delta: float) -> void:
	if is_moving or is_dead:
		_keys_this_frame.clear()
		return

	var move_left = Input.is_action_just_pressed("move_left") or KEY_A in _keys_this_frame
	var move_right = Input.is_action_just_pressed("move_right") or KEY_D in _keys_this_frame
	var move_up = Input.is_action_just_pressed("move_up") or KEY_W in _keys_this_frame
	var move_down = Input.is_action_just_pressed("move_down") or KEY_S in _keys_this_frame
	var press = Input.is_action_just_pressed("press_button") or KEY_E in _keys_this_frame or KEY_SPACE in _keys_this_frame

	_keys_this_frame.clear()

	if move_left:
		_try_move(Vector2i.LEFT)
	elif move_right:
		_try_move(Vector2i.RIGHT)
	elif move_up:
		_try_move(Vector2i.UP)
	elif move_down:
		_try_move(Vector2i.DOWN)

	if press:
		_try_press()

# =====================
# MOVEMENT
# =====================

func _try_move(direction: Vector2i) -> void:
	var new_pos = grid_pos + direction

	if new_pos.x < 0 or new_pos.x >= grid_size or new_pos.y < 0 or new_pos.y >= grid_size:
		var hit = game_board.try_wall_press(grid_pos, direction)
		if hit:
			_do_wall_hit_animation(direction)
		else:
			_do_bump_animation(direction)
		return

	grid_pos = new_pos
	_do_move_animation()

func _do_move_animation() -> void:
	is_moving = true
	var target_pos = game_board.grid_to_world(grid_pos)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, move_duration)
	tween.tween_callback(func(): is_moving = false)

	var squash_tween = create_tween()
	squash_tween.tween_property(self, "scale", Vector2(1.2, 0.8), move_duration * 0.4)
	squash_tween.tween_property(self, "scale", Vector2.ONE, move_duration * 0.4).set_trans(Tween.TRANS_BACK)

func _do_bump_animation(direction: Vector2i) -> void:
	is_moving = true
	var bump_offset = Vector2(direction) * 15
	var original_pos = position

	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + bump_offset, 0.04)
	tween.tween_property(self, "position", original_pos, 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_moving = false)

	var shake_tween = create_tween()
	shake_tween.tween_property(self, "scale", Vector2(0.9, 1.1), 0.04)
	shake_tween.tween_property(self, "scale", Vector2.ONE, 0.06)

func _do_wall_hit_animation(direction: Vector2i) -> void:
	is_moving = true
	var bump_offset = Vector2(direction) * 20
	var original_pos = position

	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + bump_offset, 0.05)
	tween.tween_property(self, "position", original_pos, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_moving = false)

	var squash_tween = create_tween()
	squash_tween.tween_property(self, "scale", Vector2(0.8, 1.2), 0.05)
	squash_tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.08)
	squash_tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)

func _try_press() -> void:
	var hit = game_board.try_floor_press(grid_pos)
	if hit:
		_do_press_hit_animation()
	else:
		_do_press_miss_animation()

func _do_press_hit_animation() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.05)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)

func _do_press_miss_animation() -> void:
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.02)
	tween.tween_property(self, "position", original_pos - Vector2(5, 0), 0.04)
	tween.tween_property(self, "position", original_pos, 0.02)

# =====================
# DEATH / RESET
# =====================

func die() -> void:
	if is_dead:
		return
	is_dead = true

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(glow, "modulate", Color(1.0, 0.0, 0.0, 0.8), 0.1)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "rotation", PI * 2, 0.3)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(func(): died.emit())

func reset() -> void:
	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)
	scale = Vector2.ONE
	rotation = 0
	is_moving = false
	is_dead = false
	_keys_this_frame.clear()

	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	glow.modulate = Color(1.0, 0.8, 0.0, 0.5)
	modulate.a = 1.0
	visible = true
