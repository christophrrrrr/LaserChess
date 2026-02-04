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

# Track danger zones with reference counting (for overlapping hazards)
var danger_count: Dictionary = {}  # Vector2i -> int

# Track active hazards
var active_hazards: int = 0

# Score
var score: int = 0

# Seeded RNG — deterministic when seed is set, random otherwise
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Colors
var color_floor_normal := Color(0.15, 0.15, 0.25)
var color_floor_target := Color(0.0, 1.0, 0.6)
var color_floor_danger := Color(1.0, 0.15, 0.15, 0.8)
var color_wall_normal := Color(0.1, 0.1, 0.2)
var color_wall_target := Color(0.0, 0.8, 1.0)

# Chess piece textures
var rook_texture: Texture2D
var bishop_texture: Texture2D
var knight_texture: Texture2D

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

func _create_chess_piece_sprite(texture: Texture2D) -> Sprite2D:
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
	glow.modulate = Color(1.0, 0.0, 0.0, 0.5)
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
	
	# Only start pulse if not in danger
	if not _is_square_in_danger(square):
		_stop_square_tween(square, "pulse_tween")
		
		rect.color = Color.WHITE
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(rect, "color", target_color, 0.2)
		square.scale = Vector2(1.3, 1.3)
		tween.tween_property(square, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		tween.chain().tween_callback(_start_pulse.bind(square, target_color))

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
	
	# If in danger, keep danger color; otherwise animate to normal
	if _is_square_in_danger(square):
		rect.color = color_floor_danger
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
	
	_execute_hazard_with_piece(positions, rook_texture, start_pos)

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
		_execute_hazard_with_piece(positions, bishop_texture, start_pos)

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

func _mark_danger(pos: Vector2i) -> void:
	if pos not in danger_count:
		danger_count[pos] = 0
	danger_count[pos] += 1
	
	var square = get_floor_square(pos)
	if square and not _is_square_in_danger(square):
		square.set_meta("is_danger", true)
		_stop_square_tween(square, "pulse_tween")
		_start_danger_pulse(square)

func _unmark_danger(pos: Vector2i) -> void:
	if pos not in danger_count:
		return
	
	danger_count[pos] -= 1
	if danger_count[pos] <= 0:
		danger_count.erase(pos)
		
		var square = get_floor_square(pos)
		if square:
			square.set_meta("is_danger", false)
			_stop_square_tween(square, "danger_tween")
			
			var rect = square.get_meta("rect") as ColorRect
			var base_color = _get_square_base_color(square)
			rect.color = base_color
			
			# Restart pulse if it's a target
			if square.get_meta("is_target"):
				_start_pulse(square, base_color)

func _start_danger_pulse(square: Node2D) -> void:
	_stop_square_tween(square, "danger_tween")
	
	var rect = square.get_meta("rect") as ColorRect
	var base_color = _get_square_base_color(square)
	
	rect.color = color_floor_danger
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(rect, "color", base_color.lerp(color_floor_danger, 0.5), 0.1)
	tween.tween_property(rect, "color", color_floor_danger, 0.1)
	
	square.set_meta("danger_tween", tween)

# =====================
# KNIGHT HAZARD
# =====================

func _execute_knight_hazard(start_pos: Vector2i) -> void:
	if is_resetting:
		return
	
	active_hazards += 1
	
	var piece = _create_chess_piece_sprite(knight_texture)
	piece.position = grid_to_world(start_pos)
	piece.modulate.a = 0
	pieces_container.add_child(piece)
	
	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 1.0, piece_fade_in_time)
	await fade_in.finished
	
	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return
	
	var current_pos = start_pos
	
	for i in range(knight_num_jumps):
		if is_resetting or not is_instance_valid(piece):
			if is_instance_valid(piece):
				piece.queue_free()
			active_hazards -= 1
			return
		
		var valid_moves = _get_valid_knight_moves(current_pos)
		
		if valid_moves.is_empty():
			break
		
		var target_pos = valid_moves[rng.randi() % valid_moves.size()]
		
		_mark_danger(target_pos)
		SoundManager.play("warning")
		
		await get_tree().create_timer(knight_warning_time).timeout
		
		if is_resetting or not is_instance_valid(piece):
			_unmark_danger(target_pos)
			if is_instance_valid(piece):
				piece.queue_free()
			active_hazards -= 1
			return
		
		# Teleport piece, then check collision
		piece.position = grid_to_world(target_pos)
		_flash_square(target_pos)
		
		if player and not player.is_dead:
			if player.grid_pos == target_pos:
				player_hit.emit()
				player.die()
		
		_unmark_danger(target_pos)
		
		current_pos = target_pos
		
		await get_tree().create_timer(knight_pause_between).timeout
	
	if is_resetting or not is_instance_valid(piece):
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return
	
	var fade_out = create_tween()
	fade_out.tween_property(piece, "modulate:a", 0.0, piece_fade_out_time)
	fade_out.tween_callback(piece.queue_free)
	
	active_hazards -= 1

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

func _execute_hazard_with_piece(positions: Array[Vector2i], texture: Texture2D, start_pos: Vector2) -> void:
	if positions.is_empty() or is_resetting:
		return
	
	active_hazards += 1
	
	var piece = _create_chess_piece_sprite(texture)
	piece.position = start_pos
	piece.modulate.a = 0
	pieces_container.add_child(piece)
	
	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 1.0, piece_fade_in_time)
	
	# Mark all positions as danger (warning phase)
	for pos in positions:
		_mark_danger(pos)
	SoundManager.play("warning")
	
	# Wait for warning
	await get_tree().create_timer(hazard_warning_time).timeout
	
	if is_resetting or not is_instance_valid(piece):
		for pos in positions:
			_unmark_danger(pos)
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return
	
	# Animate piece through
	SoundManager.play("hazard_slide")
	await _animate_sliding_piece(piece, positions)
	
	if is_resetting or not is_instance_valid(piece):
		for pos in positions:
			_unmark_danger(pos)
		if is_instance_valid(piece):
			piece.queue_free()
		active_hazards -= 1
		return
	
	# Clear all danger
	for pos in positions:
		_unmark_danger(pos)
	
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
			rect.color = Color.WHITE
			var flash_tween = create_tween()
			flash_tween.tween_property(rect, "color", color_floor_danger, hazard_flash_duration)
		
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

func spawn_random_hazard() -> void:
	if is_resetting:
		return
	
	var hazard_type = rng.randi() % 3
	
	match hazard_type:
		0:
			spawn_rook_hazard()
		1:
			spawn_bishop_hazard()
		2:
			spawn_knight_hazard()

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
		square.set_meta("is_target", false)
		square.set_meta("is_danger", false)
		
		var rect = square.get_meta("rect") as ColorRect
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
	danger_count.clear()
	active_hazards = 0
	
	await get_tree().process_frame
	
	is_resetting = false
	
	spawn_target_square()
