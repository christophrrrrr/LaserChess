extends Node2D

# Configuration - easy to tweak later
@export var grid_size: int = 6
@export var tile_size: float = 80.0
@export var wall_thickness: float = 30.0
@export var tile_gap: float = 4.0

# Hazard configuration
@export var hazard_warning_time: float = 0.8  # Time to show warning before hazard moves
@export var hazard_move_speed: float = 0.08   # Time per tile when moving

# Store references to all squares
var floor_squares: Array = []
var wall_squares: Dictionary = {}

# Track active targets (squares that are lit up)
var active_targets: Array = []

# Track danger zones for hazards
var danger_squares: Array[Vector2i] = []

# Track active hazard coroutines so we can cancel them
var active_hazards: int = 0

# Score
var score: int = 0

# Colors (neon arcade style)
var color_floor_normal := Color(0.15, 0.15, 0.25)
var color_floor_target := Color(0.0, 1.0, 0.6)  # Bright green
var color_floor_danger := Color(1.0, 0.15, 0.15, 0.8)  # Red danger
var color_wall_normal := Color(0.1, 0.1, 0.2)
var color_wall_target := Color(0.0, 0.8, 1.0)  # Cyan

# Chess piece textures
var rook_texture: Texture2D
var bishop_texture: Texture2D
var knight_texture: Texture2D

# Signals
signal square_hit(is_wall: bool)
signal square_missed
signal score_changed(new_score: int)
signal player_hit  # When player gets hit by hazard

# Reference to player (for collision checking)
var player: Node2D

# Flag to cancel hazards on reset
var is_resetting: bool = false

# Container for chess piece sprites
var pieces_container: Node2D

func _ready() -> void:
	_load_chess_pieces()
	_create_board()
	
	# Create container for chess pieces (rendered on top)
	pieces_container = Node2D.new()
	pieces_container.z_index = 10
	add_child(pieces_container)
	
	# Spawn first target
	spawn_target_square()
	
	# Get player reference
	player = get_parent().get_node("Player")

func _load_chess_pieces() -> void:
	# Load chess piece textures
	rook_texture = load("res://assets/rook.png")
	bishop_texture = load("res://assets/bishop.png")
	knight_texture = load("res://assets/knight.png")

func _create_board() -> void:
	# Calculate total board size in pixels
	var board_pixel_size = grid_size * (tile_size + tile_gap) - tile_gap
	# Offset to center the board at position (0,0)
	var offset = -board_pixel_size / 2.0
	
	# Create floor squares (the main 6x6 grid)
	for row in range(grid_size):
		for col in range(grid_size):
			var square = _create_square(tile_size, tile_size, color_floor_normal)
			square.position = Vector2(
				offset + col * (tile_size + tile_gap) + tile_size / 2,
				offset + row * (tile_size + tile_gap) + tile_size / 2
			)
			# Store grid position as metadata so we can look it up later
			square.set_meta("grid_pos", Vector2i(col, row))
			square.set_meta("is_wall", false)
			square.set_meta("is_target", false)
			square.set_meta("is_danger", false)
			add_child(square)
			floor_squares.append(square)
	
	# Create wall squares (thinner rectangles on each edge)
	_create_wall_squares(offset, board_pixel_size)

func _create_wall_squares(offset: float, board_pixel_size: float) -> void:
	wall_squares["top"] = []
	wall_squares["bottom"] = []
	wall_squares["left"] = []
	wall_squares["right"] = []
	
	# Top and bottom walls
	for col in range(grid_size):
		var x_pos = offset + col * (tile_size + tile_gap) + tile_size / 2
		
		# Top wall square
		var top_square = _create_square(tile_size, wall_thickness, color_wall_normal)
		top_square.position = Vector2(x_pos, offset - wall_thickness / 2 - tile_gap)
		top_square.set_meta("grid_pos", Vector2i(col, -1))
		top_square.set_meta("is_wall", true)
		top_square.set_meta("wall_side", "top")
		top_square.set_meta("is_target", false)
		add_child(top_square)
		wall_squares["top"].append(top_square)
		
		# Bottom wall square
		var bottom_square = _create_square(tile_size, wall_thickness, color_wall_normal)
		bottom_square.position = Vector2(x_pos, -offset + wall_thickness / 2 + tile_gap)
		bottom_square.set_meta("grid_pos", Vector2i(col, grid_size))
		bottom_square.set_meta("is_wall", true)
		bottom_square.set_meta("wall_side", "bottom")
		bottom_square.set_meta("is_target", false)
		add_child(bottom_square)
		wall_squares["bottom"].append(bottom_square)
	
	# Left and right walls
	for row in range(grid_size):
		var y_pos = offset + row * (tile_size + tile_gap) + tile_size / 2
		
		# Left wall square
		var left_square = _create_square(wall_thickness, tile_size, color_wall_normal)
		left_square.position = Vector2(offset - wall_thickness / 2 - tile_gap, y_pos)
		left_square.set_meta("grid_pos", Vector2i(-1, row))
		left_square.set_meta("is_wall", true)
		left_square.set_meta("wall_side", "left")
		left_square.set_meta("is_target", false)
		add_child(left_square)
		wall_squares["left"].append(left_square)
		
		# Right wall square
		var right_square = _create_square(wall_thickness, tile_size, color_wall_normal)
		right_square.position = Vector2(-offset + wall_thickness / 2 + tile_gap, y_pos)
		right_square.set_meta("grid_pos", Vector2i(grid_size, row))
		right_square.set_meta("is_wall", true)
		right_square.set_meta("wall_side", "right")
		right_square.set_meta("is_target", false)
		add_child(right_square)
		wall_squares["right"].append(right_square)

func _create_square(width: float, height: float, color: Color) -> Node2D:
	# Create a simple colored rectangle
	var square = Node2D.new()
	var rect = ColorRect.new()
	rect.size = Vector2(width, height)
	rect.position = -rect.size / 2  # Center the rect on the node
	rect.color = color
	square.add_child(rect)
	square.set_meta("rect", rect)  # Store reference for color changes later
	return square

# Helper: Convert grid position (like 2,3) to world position (pixels)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var board_pixel_size = grid_size * (tile_size + tile_gap) - tile_gap
	var offset = -board_pixel_size / 2.0
	return Vector2(
		offset + grid_pos.x * (tile_size + tile_gap) + tile_size / 2,
		offset + grid_pos.y * (tile_size + tile_gap) + tile_size / 2
	)

# Helper: Get floor square at grid position
func get_floor_square(grid_pos: Vector2i) -> Node2D:
	var index = grid_pos.y * grid_size + grid_pos.x
	if index >= 0 and index < floor_squares.size():
		return floor_squares[index]
	return null

# Create a chess piece sprite with red glow effect
func _create_chess_piece_sprite(texture: Texture2D) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	
	# Scale to fit tile size (with some padding)
	var tex_size = texture.get_size()
	var target_size = tile_size * 0.8
	var scale_factor = target_size / max(tex_size.x, tex_size.y)
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	# Store the base scale for animations
	sprite.set_meta("base_scale", sprite.scale)
	
	# Red tint and semi-transparent
	sprite.modulate = Color(1.0, 0.3, 0.3, 0.8)
	
	# Add glow effect using a duplicate sprite behind
	var glow = Sprite2D.new()
	glow.texture = texture
	glow.scale = Vector2(1.15, 1.15)  # 15% bigger than parent (relative scale)
	glow.modulate = Color(1.0, 0.0, 0.0, 0.4)
	glow.z_index = -1
	sprite.add_child(glow)
	
	# Pulse animation for the glow
	var tween = sprite.create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", 0.6, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 0.2, 0.3).set_trans(Tween.TRANS_SINE)
	
	return sprite

# =====================
# TARGET SQUARE SYSTEM
# =====================

func spawn_target_square() -> void:
	if is_resetting:
		return
	
	# 20% chance for wall square, 80% for floor
	var spawn_wall = randf() < 0.2
	
	if spawn_wall:
		_spawn_wall_target()
	else:
		_spawn_floor_target()

func _spawn_floor_target() -> void:
	# Get all non-active floor squares
	var available = floor_squares.filter(func(sq): return not sq.get_meta("is_target"))
	
	if available.is_empty():
		return
	
	# Pick a random one
	var square = available[randi() % available.size()]
	_activate_target(square)

func _spawn_wall_target() -> void:
	# Pick a random wall side
	var sides = ["top", "bottom", "left", "right"]
	var side = sides[randi() % sides.size()]
	
	# Get non-active squares on that side
	var available = wall_squares[side].filter(func(sq): return not sq.get_meta("is_target"))
	
	if available.is_empty():
		return
	
	var square = available[randi() % available.size()]
	_activate_target(square)

func _activate_target(square: Node2D) -> void:
	if is_resetting:
		return
		
	square.set_meta("is_target", true)
	active_targets.append(square)
	
	var rect = square.get_meta("rect") as ColorRect
	var is_wall = square.get_meta("is_wall")
	var target_color = color_wall_target if is_wall else color_floor_target
	
	# Juicy activation animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Color flash: white -> target color
	rect.color = Color.WHITE
	tween.tween_property(rect, "color", target_color, 0.2)
	
	# Pop scale effect
	square.scale = Vector2(1.3, 1.3)
	tween.tween_property(square, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Start pulsing glow animation
	_start_pulse(square, target_color)

func _start_pulse(square: Node2D, base_color: Color) -> void:
	var rect = square.get_meta("rect") as ColorRect
	
	# Create a looping pulse
	var pulse_tween = create_tween()
	pulse_tween.set_loops()  # Loop forever
	
	var bright_color = base_color.lightened(0.3)
	pulse_tween.tween_property(rect, "color", bright_color, 0.4).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(rect, "color", base_color, 0.4).set_trans(Tween.TRANS_SINE)
	
	# Store tween reference so we can stop it later
	square.set_meta("pulse_tween", pulse_tween)

func _stop_pulse(square: Node2D) -> void:
	if square.has_meta("pulse_tween"):
		var tween = square.get_meta("pulse_tween") as Tween
		if tween and tween.is_valid():
			tween.kill()

# Called by player when pressing space (floor squares only now)
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

# Called by player when moving into a wall
func try_wall_press(player_grid_pos: Vector2i, direction: Vector2i) -> bool:
	var wall_side = ""
	var wall_index = -1
	
	# Check if player is at the correct edge for the direction they're pressing
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
	
	# Spawn new target after short delay (check if not resetting)
	if not is_resetting:
		get_tree().create_timer(0.15).timeout.connect(spawn_target_square)

func _deactivate_target(square: Node2D) -> void:
	square.set_meta("is_target", false)
	active_targets.erase(square)
	
	_stop_pulse(square)
	
	var rect = square.get_meta("rect") as ColorRect
	var is_wall = square.get_meta("is_wall")
	var normal_color = color_wall_normal if is_wall else color_floor_normal
	
	# Juicy hit animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Flash white then fade to normal
	rect.color = Color.WHITE
	tween.tween_property(rect, "color", normal_color, 0.3)
	
	# Pop and shrink
	square.scale = Vector2(1.4, 1.4)
	tween.tween_property(square, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)

# =====================
# HAZARD SYSTEM
# =====================

func spawn_rook_hazard() -> void:
	# Choose random row or column
	var is_row = randf() < 0.5
	var index = randi() % grid_size
	# Random direction (start from beginning or end)
	var reverse = randf() < 0.5
	
	var positions: Array[Vector2i] = []
	var start_pos: Vector2  # Where the rook sprite starts (outside board)
	
	if is_row:
		# Horizontal line
		for col in range(grid_size):
			positions.append(Vector2i(col, index))
		if reverse:
			positions.reverse()
			start_pos = grid_to_world(Vector2i(grid_size, index))  # Start from right
		else:
			start_pos = grid_to_world(Vector2i(-1, index))  # Start from left
	else:
		# Vertical line
		for row in range(grid_size):
			positions.append(Vector2i(index, row))
		if reverse:
			positions.reverse()
			start_pos = grid_to_world(Vector2i(index, grid_size))  # Start from bottom
		else:
			start_pos = grid_to_world(Vector2i(index, -1))  # Start from top
	
	_execute_hazard_with_piece(positions, rook_texture, start_pos, "slide")

func spawn_bishop_hazard() -> void:
	var positions: Array[Vector2i] = []
	var start_pos: Vector2
	
	# Pick random diagonal
	var diagonal_type = randi() % 4
	
	match diagonal_type:
		0:  # Top-left to bottom-right, starting from top edge
			var start_col = randi() % grid_size
			var col = start_col
			var row = 0
			while col < grid_size and row < grid_size:
				positions.append(Vector2i(col, row))
				col += 1
				row += 1
			start_pos = grid_to_world(Vector2i(start_col - 1, -1))
		1:  # Top-left to bottom-right, starting from left edge
			var start_row = randi() % grid_size
			var col = 0
			var row = start_row
			while col < grid_size and row < grid_size:
				positions.append(Vector2i(col, row))
				col += 1
				row += 1
			start_pos = grid_to_world(Vector2i(-1, start_row - 1))
		2:  # Top-right to bottom-left, starting from top edge
			var start_col = randi() % grid_size
			var col = start_col
			var row = 0
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
			start_pos = grid_to_world(Vector2i(start_col + 1, -1))
		3:  # Top-right to bottom-left, starting from right edge
			var start_row = randi() % grid_size
			var col = grid_size - 1
			var row = start_row
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
			start_pos = grid_to_world(Vector2i(grid_size, start_row - 1))
	
	if positions.size() > 0:
		_execute_hazard_with_piece(positions, bishop_texture, start_pos, "slide")

func spawn_knight_hazard() -> void:
	# Knight spawns at random position and makes 3 sequential L-shaped jumps
	var start_pos = Vector2i(randi() % grid_size, randi() % grid_size)
	_execute_knight_hazard(start_pos)

func _get_valid_knight_moves(from_pos: Vector2i) -> Array[Vector2i]:
	# All possible L-shaped moves
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

func _execute_knight_hazard(start_pos: Vector2i) -> void:
	if is_resetting:
		return
	
	active_hazards += 1
	
	# Create knight sprite
	var piece = _create_chess_piece_sprite(knight_texture)
	var base_scale = piece.get_meta("base_scale") as Vector2
	piece.position = grid_to_world(start_pos)
	piece.modulate.a = 0
	pieces_container.add_child(piece)
	
	# Fade in
	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 0.8, 0.2)
	await fade_in.finished
	
	if is_resetting:
		piece.queue_free()
		active_hazards -= 1
		return
	
	var current_pos = start_pos
	var jump_warning_time = 0.4  # Time to show warning before each jump
	var num_jumps = 3
	
	# Perform 3 jumps
	for i in range(num_jumps):
		if is_resetting:
			piece.queue_free()
			active_hazards -= 1
			return
		
		# Get valid moves from current position
		var valid_moves = _get_valid_knight_moves(current_pos)
		
		if valid_moves.is_empty():
			break  # No valid moves, end early
		
		# Pick a random target
		var target_pos = valid_moves[randi() % valid_moves.size()]
		
		# Show warning on target square only
		_show_danger_warning_single(target_pos)
		
		# Wait for warning
		await get_tree().create_timer(jump_warning_time).timeout
		
		if is_resetting:
			_clear_danger_warning_single(target_pos)
			piece.queue_free()
			active_hazards -= 1
			return
		
		# Check collision before jump
		if player and not player.is_dead:
			if player.grid_pos == target_pos:
				player_hit.emit()
				player.die()
		
		# Teleport knight to target
		piece.position = grid_to_world(target_pos)
		
		# Flash the square white
		var square = get_floor_square(target_pos)
		if square:
			var rect = square.get_meta("rect") as ColorRect
			var flash_tween = create_tween()
			flash_tween.tween_property(rect, "color", Color.WHITE, 0.03)
			flash_tween.tween_property(rect, "color", color_floor_danger, 0.05)
		
		# Clear danger on this square
		_clear_danger_warning_single(target_pos)
		
		# Check collision after landing
		if player and not player.is_dead:
			if player.grid_pos == target_pos:
				player_hit.emit()
				player.die()
		
		# Update current position for next jump
		current_pos = target_pos
		
		# Small pause before next jump
		await get_tree().create_timer(0.1).timeout
	
	if is_resetting:
		piece.queue_free()
		active_hazards -= 1
		return
	
	# Fade out and remove
	var fade_out = create_tween()
	fade_out.tween_property(piece, "modulate:a", 0.0, 0.2)
	fade_out.tween_callback(piece.queue_free)
	
	active_hazards -= 1

func _show_danger_warning_single(pos: Vector2i) -> void:
	if pos not in danger_squares:
		danger_squares.append(pos)
	
	var square = get_floor_square(pos)
	if square:
		square.set_meta("is_danger", true)
		var rect = square.get_meta("rect") as ColorRect
		
		var base_color = color_floor_target if square.get_meta("is_target") else color_floor_normal
		
		# Pulsing danger effect
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(rect, "color", color_floor_danger, 0.1)
		tween.tween_property(rect, "color", base_color.lerp(color_floor_danger, 0.5), 0.1)
		
		square.set_meta("danger_tween", tween)

func _clear_danger_warning_single(pos: Vector2i) -> void:
	var square = get_floor_square(pos)
	if square:
		square.set_meta("is_danger", false)
		
		if square.has_meta("danger_tween"):
			var tween = square.get_meta("danger_tween") as Tween
			if tween and tween.is_valid():
				tween.kill()
		
		var rect = square.get_meta("rect") as ColorRect
		var target_color = color_floor_target if square.get_meta("is_target") else color_floor_normal
		
		var fade_tween = create_tween()
		fade_tween.tween_property(rect, "color", target_color, 0.15)
	
	danger_squares.erase(pos)

func _execute_hazard_with_piece(positions: Array[Vector2i], texture: Texture2D, start_pos: Vector2, move_type: String) -> void:
	if positions.is_empty() or is_resetting:
		return
	
	active_hazards += 1
	
	# Create chess piece sprite
	var piece = _create_chess_piece_sprite(texture)
	piece.position = start_pos
	piece.modulate.a = 0  # Start invisible
	pieces_container.add_child(piece)
	
	# Fade in the piece
	var fade_in = create_tween()
	fade_in.tween_property(piece, "modulate:a", 0.8, 0.2)
	
	# Phase 1: Show warning (red squares)
	_show_danger_warning(positions)
	
	# Phase 2: After warning time, check for collision
	await get_tree().create_timer(hazard_warning_time).timeout
	
	if is_resetting:
		piece.queue_free()
		active_hazards -= 1
		return
	
	# Check if player is on any danger square
	if player and not player.is_dead:
		if player.grid_pos in positions:
			player_hit.emit()
			player.die()
	
	# Phase 3: Animate the piece moving through
	await _animate_sliding_piece(piece, positions)
	
	if is_resetting:
		piece.queue_free()
		active_hazards -= 1
		return
	
	# Phase 4: Clear danger and remove piece
	_clear_danger_warning(positions)
	
	# Fade out and remove piece
	var fade_out = create_tween()
	fade_out.tween_property(piece, "modulate:a", 0.0, 0.2)
	fade_out.tween_callback(piece.queue_free)
	
	active_hazards -= 1

func _animate_sliding_piece(piece: Sprite2D, positions: Array[Vector2i]) -> void:
	for i in range(positions.size()):
		if is_resetting:
			return
		
		var pos = positions[i]
		var target_world = grid_to_world(pos)
		
		# Move piece to this square
		var move_tween = create_tween()
		move_tween.tween_property(piece, "position", target_world, hazard_move_speed).set_trans(Tween.TRANS_LINEAR)
		
		# Flash the square
		var square = get_floor_square(pos)
		if square:
			var rect = square.get_meta("rect") as ColorRect
			var flash_tween = create_tween()
			flash_tween.tween_property(rect, "color", Color.WHITE, 0.02)
			flash_tween.tween_property(rect, "color", color_floor_danger, 0.04)
		
		await get_tree().create_timer(hazard_move_speed).timeout
		
		if is_resetting:
			return
		
		# Check collision during movement
		if player and not player.is_dead:
			if player.grid_pos == pos:
				player_hit.emit()
				player.die()
	
	# Move piece off the board (continue in same direction)
	if positions.size() >= 2:
		var last_pos = grid_to_world(positions[-1])
		var second_last_pos = grid_to_world(positions[-2])
		var direction = (last_pos - second_last_pos).normalized()
		var exit_pos = last_pos + direction * tile_size * 2
		
		var exit_tween = create_tween()
		exit_tween.tween_property(piece, "position", exit_pos, hazard_move_speed * 2)
		await exit_tween.finished

func _show_danger_warning(positions: Array[Vector2i]) -> void:
	for pos in positions:
		if pos not in danger_squares:
			danger_squares.append(pos)
	
	for pos in positions:
		var square = get_floor_square(pos)
		if square:
			square.set_meta("is_danger", true)
			var rect = square.get_meta("rect") as ColorRect
			
			# Don't override target color completely, blend it
			var base_color = color_floor_target if square.get_meta("is_target") else color_floor_normal
			
			# Pulsing danger effect
			var tween = create_tween()
			tween.set_loops(int(hazard_warning_time / 0.2))  # Pulse during warning
			tween.tween_property(rect, "color", color_floor_danger, 0.1)
			tween.tween_property(rect, "color", base_color.lerp(color_floor_danger, 0.5), 0.1)
			
			square.set_meta("danger_tween", tween)

func _clear_danger_warning(positions: Array[Vector2i]) -> void:
	for pos in positions:
		var square = get_floor_square(pos)
		if square:
			square.set_meta("is_danger", false)
			
			# Stop danger tween if running
			if square.has_meta("danger_tween"):
				var tween = square.get_meta("danger_tween") as Tween
				if tween and tween.is_valid():
					tween.kill()
			
			var rect = square.get_meta("rect") as ColorRect
			var target_color = color_floor_target if square.get_meta("is_target") else color_floor_normal
			
			# Fade back to normal
			var tween = create_tween()
			tween.tween_property(rect, "color", target_color, 0.2)
		
		danger_squares.erase(pos)

func spawn_random_hazard() -> void:
	if is_resetting:
		return
		
	# Randomly choose a hazard type
	var hazard_type = randi() % 3
	
	match hazard_type:
		0:
			spawn_rook_hazard()
		1:
			spawn_bishop_hazard()
		2:
			spawn_knight_hazard()

# Reset for new game
func reset() -> void:
	is_resetting = true
	
	score = 0
	score_changed.emit(score)
	
	# Remove all chess piece sprites
	for child in pieces_container.get_children():
		child.queue_free()
	
	# Stop all danger tweens and reset colors immediately
	for square in floor_squares:
		_stop_pulse(square)
		square.set_meta("is_target", false)
		square.set_meta("is_danger", false)
		
		if square.has_meta("danger_tween"):
			var tween = square.get_meta("danger_tween") as Tween
			if tween and tween.is_valid():
				tween.kill()
		
		var rect = square.get_meta("rect") as ColorRect
		rect.color = color_floor_normal
		square.scale = Vector2.ONE
	
	# Reset all wall squares
	for side in wall_squares:
		for square in wall_squares[side]:
			_stop_pulse(square)
			square.set_meta("is_target", false)
			var rect = square.get_meta("rect") as ColorRect
			rect.color = color_wall_normal
			square.scale = Vector2.ONE
	
	active_targets.clear()
	danger_squares.clear()
	active_hazards = 0
	
	# Wait a frame then re-enable
	await get_tree().process_frame
	
	is_resetting = false
	
	# Spawn first target
	spawn_target_square()
