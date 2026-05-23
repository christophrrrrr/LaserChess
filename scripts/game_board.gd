extends Node2D

# === BOARD LAYOUT ===
@export_group("Board Layout")
@export var grid_size: int = 6
@export var tile_size: float = 120.0
@export var wall_thickness: float = 45.0
@export var tile_gap: float = 6.0

# === HAZARD TIMING ===
@export_group("Rook & Bishop")
@export var hazard_warning_time: float = 0.8  ## How long danger squares pulse red before piece moves
@export var hazard_slide_speed: float = 0.08  ## Time per tile when piece slides through
@export var hazard_flash_duration: float = 0.04  ## White flash duration per tile

@export_group("Knight")
@export var knight_warning_time: float = 0.4  ## Warning time before each knight jump
@export var knight_pause_between: float = 0.1  ## Pause between knight jumps
@export var knight_num_jumps: int = 3  ## Number of L-shaped jumps per knight

@export_group("Piece Visuals")
@export var piece_fade_in_time: float = 0.2
@export var piece_fade_out_time: float = 0.2
@export var piece_sprite_scale: float = 0.8  ## Fraction of tile size
@export var piece_glow_scale: float = 1.2  ## Glow relative to piece

# Store references to all squares
var floor_squares: Array = []
var wall_squares: Dictionary = {}

# Track active targets
var active_targets: Array = []

# Track active danger colors per square (supports overlapping hazards)
var danger_colors: Dictionary = {}  # Vector2i -> Array[Color]

# Track active hazards
var active_hazards: int = 0

# Score
var score: int = 0

# Seeded RNG — deterministic when seed is set, random otherwise
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Colors
var color_floor_normal := Color(0.15, 0.15, 0.25)
var color_floor_target := Color(0.0, 1.0, 0.6)
var color_wall_normal := Color(0.1, 0.1, 0.2)
var color_wall_target := Color(0.0, 0.8, 1.0)

# Per-piece danger colors (all in the warm/red family)
var color_danger_rook   := Color(1.0, 0.12, 0.12, 0.85)   # classic red
var color_danger_bishop := Color(1.0, 0.45, 0.05, 0.85)   # orange-red
var color_danger_knight := Color(0.85, 0.05, 0.45, 0.85)  # deep crimson-rose
var color_danger_pawn   := Color(0.95, 0.75, 0.1, 0.85)  # yellow/gold

# Chess piece textures
var rook_texture: Texture2D
var bishop_texture: Texture2D
var knight_texture: Texture2D
var pawn_texture: Texture2D

# Shared shader material applied to all danger squares (crack effect)
var _danger_material: ShaderMaterial

# Signals
signal square_hit(is_wall: bool)
signal square_missed
signal score_changed(new_score: int)
signal player_hit

# Reference to player
var player: Node2D

# Flag to cancel hazards on reset
var is_resetting: bool = false

# Container for chess piece sprites
var pieces_container: Node2D

func _ready() -> void:
	# Default: randomize (solo mode). Ranked mode calls set_match_seed() before play starts.
	rng.randomize()

	var crack_shader: Shader = load("res://shaders/danger_crack.gdshader")
	_danger_material = ShaderMaterial.new()
	_danger_material.shader = crack_shader

	_load_chess_pieces()
	_create_board()

	pieces_container = Node2D.new()
	pieces_container.z_index = 10
	add_child(pieces_container)
	
	spawn_target_square()
	
	player = get_parent().get_node("Player")

# === SEEDED RNG API ===

func set_match_seed(seed_value: int) -> void:
	## Call this before the match starts to make hazards deterministic.
	## Both players use the same seed → identical hazard sequences.
	rng.seed = seed_value

func get_current_seed() -> int:
	return rng.seed

func _load_chess_pieces() -> void:
	var textures = GameSettings.get_enemy_textures()
	rook_texture = load(textures["rook"])
	bishop_texture = load(textures["bishop"])
	knight_texture = load(textures["knight"])
	pawn_texture = load(textures["pawn"])

func _create_board() -> void:
	var board_pixel_size = grid_size * (tile_size + tile_gap) - tile_gap
	var offset = -board_pixel_size / 2.0
	
	for row in range(grid_size):
		for col in range(grid_size):
			var square = _create_square(tile_size, tile_size, color_floor_normal)
			square.position = Vector2(
				offset + col * (tile_size + tile_gap) + tile_size / 2,
				offset + row * (tile_size + tile_gap) + tile_size / 2
			)
			square.set_meta("grid_pos", Vector2i(col, row))
			square.set_meta("is_wall", false)
			square.set_meta("is_target", false)
			square.set_meta("is_danger", false)
			add_child(square)
			floor_squares.append(square)
	
	_create_wall_squares(offset, board_pixel_size)

func _create_wall_squares(offset: float, _board_pixel_size: float) -> void:
	wall_squares["top"] = []
	wall_squares["bottom"] = []
	wall_squares["left"] = []
	wall_squares["right"] = []
	
	for col in range(grid_size):
		var x_pos = offset + col * (tile_size + tile_gap) + tile_size / 2
		
		var top_square = _create_square(tile_size, wall_thickness, color_wall_normal)
		top_square.position = Vector2(x_pos, offset - wall_thickness / 2 - tile_gap)
		top_square.set_meta("grid_pos", Vector2i(col, -1))
		top_square.set_meta("is_wall", true)
		top_square.set_meta("wall_side", "top")
		top_square.set_meta("is_target", false)
		top_square.set_meta("is_danger", false)
		add_child(top_square)
		wall_squares["top"].append(top_square)
		
		var bottom_square = _create_square(tile_size, wall_thickness, color_wall_normal)
		bottom_square.position = Vector2(x_pos, -offset + wall_thickness / 2 + tile_gap)
		bottom_square.set_meta("grid_pos", Vector2i(col, grid_size))
		bottom_square.set_meta("is_wall", true)
		bottom_square.set_meta("wall_side", "bottom")
		bottom_square.set_meta("is_target", false)
		bottom_square.set_meta("is_danger", false)
		add_child(bottom_square)
		wall_squares["bottom"].append(bottom_square)
	
	for row in range(grid_size):
		var y_pos = offset + row * (tile_size + tile_gap) + tile_size / 2
		
		var left_square = _create_square(wall_thickness, tile_size, color_wall_normal)
		left_square.position = Vector2(offset - wall_thickness / 2 - tile_gap, y_pos)
		left_square.set_meta("grid_pos", Vector2i(-1, row))
		left_square.set_meta("is_wall", true)
		left_square.set_meta("wall_side", "left")
		left_square.set_meta("is_target", false)
		left_square.set_meta("is_danger", false)
		add_child(left_square)
		wall_squares["left"].append(left_square)
		
		var right_square = _create_square(wall_thickness, tile_size, color_wall_normal)
		right_square.position = Vector2(-offset + wall_thickness / 2 + tile_gap, y_pos)
		right_square.set_meta("grid_pos", Vector2i(grid_size, row))
		right_square.set_meta("is_wall", true)
		right_square.set_meta("wall_side", "right")
		right_square.set_meta("is_target", false)
		right_square.set_meta("is_danger", false)
		add_child(right_square)
		wall_squares["right"].append(right_square)

func _create_square(width: float, height: float, color: Color) -> Node2D:
	var square = Node2D.new()
	var rect = ColorRect.new()
	rect.size = Vector2(width, height)
	rect.position = -rect.size / 2
	rect.color = color
	square.add_child(rect)
	square.set_meta("rect", rect)
	return square

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var board_pixel_size = grid_size * (tile_size + tile_gap) - tile_gap
	var offset = -board_pixel_size / 2.0
	return Vector2(
		offset + grid_pos.x * (tile_size + tile_gap) + tile_size / 2,
		offset + grid_pos.y * (tile_size + tile_gap) + tile_size / 2
	)

func get_floor_square(grid_pos: Vector2i) -> Node2D:
	var index = grid_pos.y * grid_size + grid_pos.x
	if index >= 0 and index < floor_squares.size():
		return floor_squares[index]
	return null

func _is_square_in_danger(square: Node2D) -> bool:
	return square.has_meta("is_danger") and square.get_meta("is_danger")

func _stop_square_tween(square: Node2D, tween_name: String) -> void:
	if square.has_meta(tween_name):
		var tween = square.get_meta(tween_name) as Tween
		if tween and tween.is_valid():
			tween.kill()
		square.remove_meta(tween_name)

func _get_square_base_color(square: Node2D) -> Color:
	var is_wall = square.get_meta("is_wall")
	var is_target = square.get_meta("is_target")
	
	if is_wall:
		return color_wall_target if is_target else color_wall_normal
	else:
		return color_floor_target if is_target else color_floor_normal

func _create_chess_piece_sprite(texture: Texture2D, glow_color: Color = Color(1.0, 0.0, 0.0)) -> Sprite2D:
	var container = Sprite2D.new()
	container.texture = texture

	var tex_size = texture.get_size()
	var target_size = tile_size * piece_sprite_scale
	var scale_factor = target_size / max(tex_size.x, tex_size.y)
	container.scale = Vector2(scale_factor, scale_factor)
	container.modulate = Color(1.0, 1.0, 1.0, 0.9)

	var glow = Sprite2D.new()
	glow.texture = texture
	glow.scale = Vector2(piece_glow_scale, piece_glow_scale)
	glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, 0.5)
	glow.z_index = -1
	container.add_child(glow)

	container.set_meta("glow", glow)

	var tween = container.create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", 0.7, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 0.3, 0.3).set_trans(Tween.TRANS_SINE)

	return container

# =====================
# TARGET SQUARE SYSTEM
# =====================

func spawn_target_square() -> void:
	if is_resetting:
		return
	
	var spawn_wall = rng.randf() < 0.2
	
	if spawn_wall:
		_spawn_wall_target()
	else:
		_spawn_floor_target()

func _spawn_floor_target() -> void:
	var available = floor_squares.filter(func(sq): return not sq.get_meta("is_target"))
	
	if available.is_empty():
		return
	
	var square = available[rng.randi() % available.size()]
	_activate_target(square)

func _spawn_wall_target() -> void:
	var sides = ["top", "bottom", "left", "right"]
	var side = sides[rng.randi() % sides.size()]
	var available = wall_squares[side].filter(func(sq): return not sq.get_meta("is_target"))
	
	if available.is_empty():
		return
	
	var square = available[rng.randi() % available.size()]
	_activate_target(square)

func _activate_target(square: Node2D) -> void:
	if is_resetting:
		return
	
	square.set_meta("is_target", true)
	active_targets.append(square)
	
	var rect = square.get_meta("rect") as ColorRect
	var is_wall = square.get_meta("is_wall")
	var target_color = color_wall_target if is_wall else color_floor_target
	
	if not _is_square_in_danger(square):
		_stop_square_tween(square, "pulse_tween")

		rect.color = Color.WHITE
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(rect, "color", target_color, 0.2)
		square.scale = Vector2(1.3, 1.3)
		tween.tween_property(square, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		tween.chain().tween_callback(_start_pulse.bind(square, target_color))
	else:
		# Restart danger pulse so it switches to the target-aware style
		_start_danger_pulse(square)

func _start_pulse(square: Node2D, base_color: Color) -> void:
	if is_resetting or _is_square_in_danger(square):
		return
	
	_stop_square_tween(square, "pulse_tween")
	
	var rect = square.get_meta("rect") as ColorRect
	
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	var bright_color = base_color.lightened(0.3)
	pulse_tween.tween_property(rect, "color", bright_color, 0.4).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(rect, "color", base_color, 0.4).set_trans(Tween.TRANS_SINE)
	
	square.set_meta("pulse_tween", pulse_tween)

func try_floor_press(player_grid_pos: Vector2i) -> bool:
	var square = get_floor_square(player_grid_pos)
	if square and square.get_meta("is_target"):
		_deactivate_target(square)
		_add_score()
		square_hit.emit(false)
		return true
	else:
		square_missed.emit()
		return false

func try_wall_press(player_grid_pos: Vector2i, direction: Vector2i) -> bool:
	var wall_side = ""
	var wall_index = -1
	
	if direction == Vector2i.UP and player_grid_pos.y == 0:
		wall_side = "top"
		wall_index = player_grid_pos.x
	elif direction == Vector2i.DOWN and player_grid_pos.y == grid_size - 1:
		wall_side = "bottom"
		wall_index = player_grid_pos.x
	elif direction == Vector2i.LEFT and player_grid_pos.x == 0:
		wall_side = "left"
		wall_index = player_grid_pos.y
	elif direction == Vector2i.RIGHT and player_grid_pos.x == grid_size - 1:
		wall_side = "right"
		wall_index = player_grid_pos.y
	
	if wall_side == "" or wall_index < 0:
		return false
	
	var square = wall_squares[wall_side][wall_index]
	if square.get_meta("is_target"):
		_deactivate_target(square)
		_add_score()
		square_hit.emit(true)
		return true
	
	return false

func _add_score() -> void:
	score += 1
	score_changed.emit(score)
	
	if not is_resetting:
		get_tree().create_timer(0.15).timeout.connect(spawn_target_square)

func _deactivate_target(square: Node2D) -> void:
	square.set_meta("is_target", false)
	active_targets.erase(square)
	
	_stop_square_tween(square, "pulse_tween")
	
	var rect = square.get_meta("rect") as ColorRect
	var is_wall = square.get_meta("is_wall")
	
	# If in danger, restart pulse with is_target now false; otherwise animate to normal
	if _is_square_in_danger(square):
		_start_danger_pulse(square)
	else:
		var normal_color = color_wall_normal if is_wall else color_floor_normal
		rect.color = Color.WHITE
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(rect, "color", normal_color, 0.3)
		square.scale = Vector2(1.4, 1.4)
		tween.tween_property(square, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

# =====================
# HAZARD SYSTEM
# =====================

func spawn_rook_hazard() -> void:
	var is_row = rng.randf() < 0.5
	var index = rng.randi() % grid_size
	var reverse = rng.randf() < 0.5
	
	var positions: Array[Vector2i] = []
	var start_pos: Vector2
	
	if is_row:
		for col in range(grid_size):
			positions.append(Vector2i(col, index))
		if reverse:
			positions.reverse()
			start_pos = grid_to_world(Vector2i(grid_size, index))
		else:
			start_pos = grid_to_world(Vector2i(-1, index))
	else:
		for row in range(grid_size):
			positions.append(Vector2i(index, row))
		if reverse:
			positions.reverse()
			start_pos = grid_to_world(Vector2i(index, grid_size))
		else:
			start_pos = grid_to_world(Vector2i(index, -1))
	
	_execute_hazard_with_piece(positions, rook_texture, start_pos, color_danger_rook)

func spawn_bishop_hazard() -> void:
	var positions: Array[Vector2i] = []
	var start_pos: Vector2
	
	var diagonal_type = rng.randi() % 4
	
	match diagonal_type:
		0:
			var start_col = rng.randi() % grid_size
			var col = start_col
			var row = 0
			while col < grid_size and row < grid_size:
				positions.append(Vector2i(col, row))
				col += 1
				row += 1
			start_pos = grid_to_world(Vector2i(start_col - 1, -1))
		1:
			var start_row = rng.randi() % grid_size
			var col = 0
			var row = start_row
			while col < grid_size and row < grid_size:
				positions.append(Vector2i(col, row))
				col += 1
				row += 1
			start_pos = grid_to_world(Vector2i(-1, start_row - 1))
		2:
			var start_col = rng.randi() % grid_size
			var col = start_col
			var row = 0
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
			start_pos = grid_to_world(Vector2i(start_col + 1, -1))
		3:
			var start_row = rng.randi() % grid_size
			var col = grid_size - 1
			var row = start_row
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
			start_pos = grid_to_world(Vector2i(grid_size, start_row - 1))
	
	if positions.size() > 0:
		_execute_hazard_with_piece(positions, bishop_texture, start_pos, color_danger_bishop)

func spawn_knight_hazard() -> void:
	var start_pos = Vector2i(rng.randi() % grid_size, rng.randi() % grid_size)
	_execute_knight_hazard(start_pos)

func _get_valid_knight_moves(from_pos: Vector2i) -> Array[Vector2i]:
	var offsets = [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	var valid_moves: Array[Vector2i] = []
	for offset in offsets:
		var target = from_pos + offset
		if target.x >= 0 and target.x < grid_size and target.y >= 0 and target.y < grid_size:
			valid_moves.append(target)
	
	return valid_moves

# =====================
# DANGER SYSTEM (ref-counted)
# =====================

func _mix_danger_colors(colors: Array) -> Color:
	var r := 0.0; var g := 0.0; var b := 0.0; var a := 0.0
	for c in colors:
		r += c.r; g += c.g; b += c.b; a += c.a
	var n := float(colors.size())
	return Color(r / n, g / n, b / n, a / n)

func _mark_danger(pos: Vector2i, danger_color: Color = color_danger_rook) -> void:
	if pos not in danger_colors:
		danger_colors[pos] = []
	danger_colors[pos].append(danger_color)

	var square = get_floor_square(pos)
	if square:
		var was_danger = _is_square_in_danger(square)
		if not was_danger:
			square.set_meta("is_danger", true)
			_stop_square_tween(square, "pulse_tween")
			(square.get_meta("rect") as ColorRect).material = _danger_material
		square.set_meta("danger_color", _mix_danger_colors(danger_colors[pos]))
		_start_danger_pulse(square)

func _unmark_danger(pos: Vector2i, danger_color: Color = color_danger_rook) -> void:
	if pos not in danger_colors:
		return

	var colors: Array = danger_colors[pos]
	for i in range(colors.size() - 1, -1, -1):
		if colors[i].is_equal_approx(danger_color):
			colors.remove_at(i)
			break

	if colors.is_empty():
		danger_colors.erase(pos)

		var square = get_floor_square(pos)
		if square:
			square.set_meta("is_danger", false)
			_stop_square_tween(square, "danger_tween")
			_stop_square_tween(square, "flash_tween")

			var rect = square.get_meta("rect") as ColorRect
			rect.material = null
			var base_color = _get_square_base_color(square)
			rect.color = base_color

			if square.get_meta("is_target"):
				_start_pulse(square, base_color)
	else:
		# Update to the blend of remaining hazards
		var square = get_floor_square(pos)
		if square:
			square.set_meta("danger_color", _mix_danger_colors(colors))
			_start_danger_pulse(square)

func _start_danger_pulse(square: Node2D) -> void:
	_stop_square_tween(square, "danger_tween")

	var rect = square.get_meta("rect") as ColorRect
	var base_color = _get_square_base_color(square)
	var dc: Color = square.get_meta("danger_color") if square.has_meta("danger_color") else color_danger_rook

	rect.color = dc

	var tween = create_tween()
	tween.set_loops()
	if square.get_meta("is_target"):
		# Full swing between target color and danger — both clearly visible
		tween.tween_property(rect, "color", base_color, 0.3).set_trans(Tween.TRANS_SINE)
		tween.tween_property(rect, "color", dc, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		# Fast urgent pulse near danger color
		tween.tween_property(rect, "color", base_color.lerp(dc, 0.5), 0.1)
		tween.tween_property(rect, "color", dc, 0.1)

	square.set_meta("danger_tween", tween)

# =====================
# KNIGHT HAZARD
# =====================

func _execute_knight_hazard(start_pos: Vector2i) -> void:
	if is_resetting:
		return

	active_hazards += 1

	var piece = _create_chess_piece_sprite(knight_texture, color_danger_knight)
	pieces_container.add_child(piece)
	var base_scale: Vector2 = piece.scale

	# Spawn: drop from above with gravity feel
	var spawn_world := grid_to_world(start_pos)
	piece.position = spawn_world + Vector2(0, -110)
	piece.modulate.a = 0

	var spawn_tween = create_tween()
	spawn_tween.set_parallel(true)
	spawn_tween.tween_property(piece, "position", spawn_world, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spawn_tween.tween_property(piece, "modulate:a", 1.0, 0.2)
	await spawn_tween.finished

	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece): piece.queue_free()
		active_hazards -= 1
		return

	await _knight_squash(piece, base_scale)

	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece): piece.queue_free()
		active_hazards -= 1
		return

	var current_pos = start_pos

	for i in range(knight_num_jumps):
		if is_resetting or not is_instance_valid(piece):
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

		var valid_moves = _get_valid_knight_moves(current_pos)
		if valid_moves.is_empty():
			break

		var target_pos = valid_moves[rng.randi() % valid_moves.size()]
		_mark_danger(target_pos, color_danger_knight)
		SoundManager.play("warning")

		await get_tree().create_timer(knight_warning_time).timeout

		if is_resetting or not is_instance_valid(piece):
			_unmark_danger(target_pos, color_danger_knight)
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

		await _knight_arc_jump(piece, piece.position, grid_to_world(target_pos))

		if is_resetting or not is_instance_valid(piece):
			_unmark_danger(target_pos, color_danger_knight)
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

		await _knight_squash(piece, base_scale)

		if player and not player.is_dead:
			if player.grid_pos == target_pos:
				player_hit.emit()
				player.die()

		_unmark_danger(target_pos, color_danger_knight)
		current_pos = target_pos

		await get_tree().create_timer(knight_pause_between).timeout

	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece): piece.queue_free()
		active_hazards -= 1
		return

	var fade_out = create_tween()
	fade_out.tween_property(piece, "modulate:a", 0.0, piece_fade_out_time)
	fade_out.tween_callback(piece.queue_free)

	active_hazards -= 1

func _knight_arc_jump(piece: Node2D, from: Vector2, to: Vector2) -> void:
	var jump_height := 80.0
	var duration := 0.28
	var tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(piece):
			piece.position = Vector2(
				lerp(from.x, to.x, t),
				lerp(from.y, to.y, t) - sin(t * PI) * jump_height
			)
	, 0.0, 1.0, duration)
	await tween.finished

func _knight_squash(piece: Node2D, base_scale: Vector2) -> void:
	if not is_instance_valid(piece):
		return
	var tween = create_tween()
	tween.tween_property(piece, "scale", base_scale * Vector2(1.2, 0.8), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(piece, "scale", base_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

func _flash_square(pos: Vector2i) -> void:
	var square = get_floor_square(pos)
	if square:
		var rect = square.get_meta("rect") as ColorRect
		rect.color = Color.WHITE
		var flash_tween = create_tween()
		flash_tween.tween_property(rect, "color", _get_square_base_color(square), 0.1)

# =====================
# ROOK / BISHOP HAZARD
# =====================

func _execute_hazard_with_piece(positions: Array[Vector2i], texture: Texture2D, start_pos: Vector2, danger_color: Color = color_danger_rook) -> void:
	if positions.is_empty() or is_resetting:
		return

	active_hazards += 1

	var piece = _create_chess_piece_sprite(texture, danger_color)
	piece.position = start_pos
	piece.modulate.a = 0
	pieces_container.add_child(piece)

	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 1.0, piece_fade_in_time)

	# Mark all positions as danger (warning phase)
	for pos in positions:
		_mark_danger(pos, danger_color)
	SoundManager.play("warning")
	
	# Wait for warning
	await get_tree().create_timer(hazard_warning_time).timeout
	
	if is_resetting or not is_instance_valid(piece):
		for pos in positions:
			_unmark_danger(pos, danger_color)
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return

	# Animate piece through
	SoundManager.play("hazard_slide")
	await _animate_sliding_piece(piece, positions)

	if is_resetting or not is_instance_valid(piece):
		for pos in positions:
			_unmark_danger(pos, danger_color)
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return

	# Clear all danger
	for pos in positions:
		_unmark_danger(pos, danger_color)
	
	if is_instance_valid(piece):
		var fade_out = create_tween()
		fade_out.tween_property(piece, "modulate:a", 0.0, piece_fade_out_time)
		fade_out.tween_callback(piece.queue_free)
	
	active_hazards -= 1

func _animate_sliding_piece(piece: Sprite2D, positions: Array[Vector2i]) -> void:
	for i in range(positions.size()):
		if is_resetting or not is_instance_valid(piece):
			return
		
		var pos = positions[i]
		var target_world = grid_to_world(pos)
		
		if is_instance_valid(piece):
			var move_tween = create_tween()
			move_tween.tween_property(piece, "position", target_world, hazard_slide_speed).set_trans(Tween.TRANS_LINEAR)
		
		await get_tree().create_timer(hazard_slide_speed).timeout
		
		if is_resetting or not is_instance_valid(piece):
			return
		
		# Flash the square white as piece passes
		var square = get_floor_square(pos)
		if square:
			var rect = square.get_meta("rect") as ColorRect
			var dc: Color = square.get_meta("danger_color") if square.has_meta("danger_color") else color_danger_rook
			_stop_square_tween(square, "flash_tween")
			rect.color = Color.WHITE
			var flash_tween = create_tween()
			flash_tween.tween_property(rect, "color", dc, hazard_flash_duration)
			square.set_meta("flash_tween", flash_tween)
		
		# Check collision AFTER piece has arrived
		if player and not player.is_dead:
			if player.grid_pos == pos:
				player_hit.emit()
				player.die()
	
	# Exit animation
	if positions.size() >= 2 and is_instance_valid(piece):
		var last_pos = grid_to_world(positions[-1])
		var second_last_pos = grid_to_world(positions[-2])
		var direction = (last_pos - second_last_pos).normalized()
		var exit_pos = last_pos + direction * tile_size * 2
		
		var exit_tween = create_tween()
		exit_tween.tween_property(piece, "position", exit_pos, hazard_slide_speed * 2)
		await exit_tween.finished

# =====================
# PAWN HAZARD
# =====================

func spawn_pawn_hazard() -> void:
	var col := rng.randi() % grid_size
	var moving_down := rng.randf() < 0.5
	_execute_pawn_hazard(col, moving_down)

func _execute_pawn_hazard(col: int, moving_down: bool) -> void:
	if is_resetting:
		return

	active_hazards += 1

	# Sprite glows red so the piece reads as dangerous even with yellow floor squares
	var piece = _create_chess_piece_sprite(pawn_texture, Color(1.0, 0.15, 0.0))
	pieces_container.add_child(piece)

	var step_dir  := 1 if moving_down else -1
	var start_row := -1 if moving_down else grid_size

	piece.position = grid_to_world(Vector2i(col, start_row))
	piece.modulate.a = 0

	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 1.0, piece_fade_in_time)
	await fade_in.finished

	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece): piece.queue_free()
		active_hazards -= 1
		return

	# Warning pause — pawn is visible on the edge so the player has time to react
	SoundManager.play("warning")
	await get_tree().create_timer(hazard_warning_time).timeout

	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece): piece.queue_free()
		active_hazards -= 1
		return

	var current_row := start_row

	while true:
		if is_resetting or not is_instance_valid(piece):
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

		current_row += step_dir

		# Slide to next square
		var target_world = grid_to_world(Vector2i(col, current_row))
		var slide = create_tween()
		slide.tween_property(piece, "position", target_world, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await slide.finished

		if is_resetting or not is_instance_valid(piece):
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

		# Off-board — exit loop
		if current_row < 0 or current_row >= grid_size:
			break

		# Mark capture diagonals and dwell
		var diagonals := _get_pawn_diagonals(col, current_row, moving_down)
		for d in diagonals:
			_mark_danger(d, color_danger_pawn)

		col = await _pawn_dwell_watch(piece, col, diagonals, 1.0, 0.5)

		for d in diagonals:
			_unmark_danger(d, color_danger_pawn)

		if is_resetting:
			if is_instance_valid(piece): piece.queue_free()
			active_hazards -= 1
			return

	# Fade out off-board
	if is_instance_valid(piece):
		var fade_out = create_tween()
		fade_out.tween_property(piece, "modulate:a", 0.0, piece_fade_out_time)
		fade_out.tween_callback(piece.queue_free)

	active_hazards -= 1

func _get_pawn_diagonals(col: int, row: int, moving_down: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var diag_row := row + (1 if moving_down else -1)
	for dc in [-1, 1]:
		var d := Vector2i(col + dc, diag_row)
		if d.x >= 0 and d.x < grid_size and d.y >= 0 and d.y < grid_size:
			result.append(d)
	return result

func _pawn_dwell_watch(piece: Node2D, start_col: int, diagonals: Array[Vector2i], dwell_time: float, lunge_duration: float) -> int:
	var dwell_end_ms := Time.get_ticks_msec() + int(dwell_time * 1000)
	var is_lunging   := false
	var current_col  := start_col

	while Time.get_ticks_msec() < dwell_end_ms:
		if is_resetting:
			return current_col
		if not is_instance_valid(piece):
			return current_col
		if not is_inside_tree():
			return current_col

		await get_tree().process_frame

		if is_lunging:
			continue

		if not (player and not player.is_dead):
			continue

		# Check if player stepped onto any diagonal
		for d in diagonals:
			if player.grid_pos != d:
				continue

			# Player is on diagonal — pawn lunges!
			is_lunging = true
			SoundManager.play("warning")

			var lunge = create_tween()
			lunge.tween_property(piece, "position", grid_to_world(d), lunge_duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await lunge.finished

			if is_resetting or not is_instance_valid(piece):
				return current_col

			# Pawn has arrived — commit to the new lane regardless of outcome
			current_col = d.x

			# Kill if player is still on that square
			if player and not player.is_dead and player.grid_pos == d:
				player_hit.emit()
				player.die()
				return current_col

			# Player dodged — continue marching from new lane
			is_lunging = false
			break  # resume watching from next frame

	return current_col

func spawn_random_hazard() -> void:
	if is_resetting:
		return

	# Weighted: rook ~29%, bishop ~29%, knight ~29%, pawn ~14%
	var roll := rng.randi() % 7
	match roll:
		0, 1: spawn_rook_hazard()
		2, 3: spawn_bishop_hazard()
		4, 5: spawn_knight_hazard()
		6:    spawn_pawn_hazard()

# =====================
# RESET
# =====================

func reset() -> void:
	is_resetting = true
	
	score = 0
	score_changed.emit(score)
	
	for child in pieces_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	
	for square in floor_squares:
		_stop_square_tween(square, "pulse_tween")
		_stop_square_tween(square, "danger_tween")
		_stop_square_tween(square, "flash_tween")
		square.set_meta("is_target", false)
		square.set_meta("is_danger", false)

		var rect = square.get_meta("rect") as ColorRect
		rect.material = null
		rect.color = color_floor_normal
		square.scale = Vector2.ONE
	
	for side in wall_squares:
		for square in wall_squares[side]:
			_stop_square_tween(square, "pulse_tween")
			_stop_square_tween(square, "danger_tween")
			square.set_meta("is_target", false)
			square.set_meta("is_danger", false)
			
			var rect = square.get_meta("rect") as ColorRect
			rect.color = color_wall_normal
			square.scale = Vector2.ONE
	
	active_targets.clear()
	danger_colors.clear()
	active_hazards = 0
	
	await get_tree().process_frame
	
	is_resetting = false
	
	spawn_target_square()
