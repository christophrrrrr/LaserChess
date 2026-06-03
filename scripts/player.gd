extends Node2D

signal died
signal position_changed(new_pos: Vector2i)

@export var move_duration: float = 0.08
@export var hat_offset: Vector2 = Vector2(1, 2)
@export var hat_base_pos_tiles: Vector2 = Vector2(0, -45)
@export var hat_base_scale: float = 0.40           # default hat size (relative to tile)
@export var hat_menu_offset_tiles: Vector2 = Vector2(0, 100)



var hat_sprite: Sprite2D = null
var grid_pos: Vector2i = Vector2i(2, 2)
var is_moving: bool = false
var grid_size: int = 6
var is_dead: bool = false
var invincible: bool = false   # true for 1.5 s after respawn — hazards can't kill

var game_board: Node2D

var sprite: Sprite2D
var glow: Sprite2D
var king_texture: Texture2D
var hat_node: Node2D = null

# Menu preview mode (no game_board)
var _menu_preview_mode: bool = false
var _menu_tile_size: float = 64.0

# Track keys pressed this frame for clean "just pressed" on raw keycodes
var _keys_this_frame: Array = []

# === HOLD-KEY MOVEMENT ===
var _move_cooldown: float = 0.0
const MOVE_INITIAL_DELAY := 0.16   ## Delay before repeat starts (seconds)
const MOVE_REPEAT_RATE := 0.09     ## Time between repeated moves when held

# === TOUCH/SWIPE CONTROLS ===
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
var _touch_index: int = -1  # Track which finger

const SWIPE_THRESHOLD := 40.0      ## Minimum distance to register as swipe (pixels)
const TAP_THRESHOLD := 25.0        ## Maximum movement to count as tap
const TAP_TIME_THRESHOLD := 0.3    ## Maximum time for a tap (seconds)

func _ready() -> void:
	# Skip game_board setup if in menu preview mode
	if _menu_preview_mode:
		return
	
	game_board = get_parent().get_node("GameBoard")
	grid_size = game_board.grid_size

	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)

	_setup_visuals()
	_create_hat()
	PlayerData.hat_changed.connect(_on_hat_changed)

## Call this BEFORE adding to tree to use player for menu preview display
func setup_for_menu_preview(tile_size: float) -> void:
	_menu_preview_mode = true
	_menu_tile_size = tile_size
	is_dead = true  # Disable input
	_setup_visuals()
	_create_hat()
	PlayerData.hat_changed.connect(_on_hat_changed)

func _setup_visuals() -> void:
	king_texture = load(GameSettings.get_player_king_texture())

	var tex_size = king_texture.get_size()
	var tile_size = _menu_tile_size if _menu_preview_mode else game_board.tile_size
	var target_size = tile_size * 0.8
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

	if is_inside_tree():
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
		hat_sprite = null

	var hat_id := PlayerData.equipped_hat
	if hat_id.is_empty():
		return
	if !PlayerData.SHOP_HATS.has(hat_id):
		return

	hat_node = Node2D.new()
	hat_node.z_index = 2
	hat_node.position = hat_offset
	add_child(hat_node)

	var tex_path: String = PlayerData.SHOP_HATS[hat_id].get("tex", "")
	if tex_path.is_empty():
		return

	var tex: Texture2D = load(tex_path)
	if tex == null:
		return

	hat_sprite = Sprite2D.new()
	hat_sprite.texture = tex
	hat_sprite.centered = true

	# Place hat above the king. Adjust this Y to taste.
	# --- Per-hat tweak lookup ---
	var tweak: Dictionary = PlayerData.HAT_TWEAKS.get(hat_id, {})
	var extra_pos: Vector2 = tweak.get("pos", Vector2.ZERO)
	var scale_mul: float = float(tweak.get("scale", 1.0))
	var rot_deg: float = float(tweak.get("rot_deg", 0.0))

# Position
	var pos := hat_base_pos_tiles + extra_pos

	if _menu_preview_mode:
		pos += Vector2(0, 0.175) * _menu_tile_size

	hat_sprite.position = pos

	
	# Rotation
	hat_sprite.rotation = deg_to_rad(rot_deg)

	# Scale (base fit to tile, then per-hat multiplier)
	var tex_size := tex.get_size()
	var tile_size = _menu_tile_size if _menu_preview_mode else game_board.tile_size
	var target_size = tile_size * hat_base_scale
	var scale_factor = target_size / max(tex_size.x, tex_size.y)
	scale_factor *= scale_mul
	hat_sprite.scale = Vector2(scale_factor, scale_factor)


	hat_node.add_child(hat_sprite)

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

func _input(event: InputEvent) -> void:
	# Touch/swipe must use _input (not _unhandled_input) so board tile ColorRects
	# (which default to MOUSE_FILTER_STOP) don't consume the event first.
	if event is InputEventScreenTouch and GameSettings.control_scheme == "swipe":
		if event.pressed:
			# Finger down — start tracking
			if not _is_touching:
				_is_touching = true
				_touch_index = event.index
				_touch_start_pos = event.position
				_touch_start_time = Time.get_ticks_msec() / 1000.0
		else:
			# Finger up — check for swipe or tap
			if _is_touching and event.index == _touch_index:
				_handle_touch_release(event.position)
				_is_touching = false
				_touch_index = -1

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard only — _unhandled_input is correct here so keys typed in
	# text fields (e.g. name-change box) don't also move the player.
	if event is InputEventKey and event.pressed and not event.echo:
		_keys_this_frame.append(event.keycode)

func _handle_touch_release(end_pos: Vector2) -> void:
	if is_moving or is_dead:
		return
	
	var delta = end_pos - _touch_start_pos
	var distance = delta.length()
	var elapsed = (Time.get_ticks_msec() / 1000.0) - _touch_start_time
	
	# Check if it's a tap (small movement, quick release)
	if distance < TAP_THRESHOLD and elapsed < TAP_TIME_THRESHOLD:
		_try_press()
		return
	
	# Check if it's a swipe (enough distance)
	if distance >= SWIPE_THRESHOLD:
		var direction = _get_swipe_direction(delta)
		if direction != Vector2i.ZERO:
			_try_move(direction)
			_move_cooldown = MOVE_INITIAL_DELAY

func _get_swipe_direction(delta: Vector2) -> Vector2i:
	# Determine primary direction based on larger axis
	if abs(delta.x) > abs(delta.y):
		# Horizontal swipe
		if delta.x > 0:
			return Vector2i.RIGHT
		else:
			return Vector2i.LEFT
	else:
		# Vertical swipe
		if delta.y > 0:
			return Vector2i.DOWN
		else:
			return Vector2i.UP

func _process(delta: float) -> void:
	if is_moving or is_dead:
		_keys_this_frame.clear()
		return

	_move_cooldown -= delta

	# --- Detect "just pressed" (first frame) ---
	var just_left  = Input.is_action_just_pressed("move_left")  or KEY_A in _keys_this_frame
	var just_right = Input.is_action_just_pressed("move_right") or KEY_D in _keys_this_frame
	var just_up    = Input.is_action_just_pressed("move_up")    or KEY_W in _keys_this_frame
	var just_down  = Input.is_action_just_pressed("move_down")  or KEY_S in _keys_this_frame

	# --- Detect "held" (continuous) ---
	var held_left  = Input.is_action_pressed("move_left")  or Input.is_key_pressed(KEY_A)
	var held_right = Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D)
	var held_up    = Input.is_action_pressed("move_up")    or Input.is_key_pressed(KEY_W)
	var held_down  = Input.is_action_pressed("move_down")  or Input.is_key_pressed(KEY_S)

	var press = Input.is_action_just_pressed("press_button") or KEY_E in _keys_this_frame or KEY_SPACE in _keys_this_frame

	_keys_this_frame.clear()

	# --- Movement priority: just-pressed first, then held (with cooldown) ---
	if just_left:
		_try_move(Vector2i.LEFT);  _move_cooldown = MOVE_INITIAL_DELAY
	elif just_right:
		_try_move(Vector2i.RIGHT); _move_cooldown = MOVE_INITIAL_DELAY
	elif just_up:
		_try_move(Vector2i.UP);    _move_cooldown = MOVE_INITIAL_DELAY
	elif just_down:
		_try_move(Vector2i.DOWN);  _move_cooldown = MOVE_INITIAL_DELAY
	elif _move_cooldown <= 0.0:
		# Held-key repeat (only fires after initial delay expires)
		if held_left:
			_try_move(Vector2i.LEFT);  _move_cooldown = MOVE_REPEAT_RATE
		elif held_right:
			_try_move(Vector2i.RIGHT); _move_cooldown = MOVE_REPEAT_RATE
		elif held_up:
			_try_move(Vector2i.UP);    _move_cooldown = MOVE_REPEAT_RATE
		elif held_down:
			_try_move(Vector2i.DOWN);  _move_cooldown = MOVE_REPEAT_RATE

	# Reset cooldown when no direction is held at all
	if not (held_left or held_right or held_up or held_down):
		_move_cooldown = 0.0

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
			SoundManager.play("wall_hit")
		else:
			_do_bump_animation(direction)
			SoundManager.play("bump")
		return

	grid_pos = new_pos
	position_changed.emit(grid_pos)
	_do_move_animation()
	SoundManager.play_pitched("move", 0.9, 1.1)

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
		SoundManager.play("hit")
	else:
		_do_press_miss_animation()
		SoundManager.play("miss")

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
	SoundManager.play("death")

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
	invincible = false
	_keys_this_frame.clear()
	_move_cooldown = 0.0
	
	# Reset touch state
	_is_touching = false
	_touch_index = -1

	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	glow.modulate = Color(1.0, 0.8, 0.0, 0.5)
	modulate.a = 1.0
	visible = true
