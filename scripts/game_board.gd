extends Node2D

# Configuration - easy to tweak later
@export var grid_size: int = 6
@export var tile_size: float = 80.0
@export var wall_thickness: float = 30.0
@export var tile_gap: float = 4.0

# Hazard configuration
@export var hazard_warning_time: float = 0.8  # Time to show warning before hazard moves
@export var hazard_move_speed: float = 0.06  # Time per tile when moving

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

# Signals
signal square_hit(is_wall: bool)
signal square_missed
signal score_changed(new_score: int)
signal player_hit  # When player gets hit by hazard

# Reference to player (for collision checking)
var player: Node2D

# Flag to cancel hazards on reset
var is_resetting: bool = false

func _ready() -> void:
	_create_board()
	# Spawn first target
	spawn_target_square()
	
	# Get player reference
	player = get_parent().get_node("Player")

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
	
	var positions: Array[Vector2i] = []
	
	if is_row:
		# Horizontal line
		for col in range(grid_size):
			positions.append(Vector2i(col, index))
	else:
		# Vertical line
		for row in range(grid_size):
			positions.append(Vector2i(index, row))
	
	_execute_hazard(positions)

func spawn_bishop_hazard() -> void:
	# Choose a random starting edge position and diagonal direction
	var positions: Array[Vector2i] = []
	
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
		1:  # Top-left to bottom-right, starting from left edge
			var start_row = randi() % grid_size
			var col = 0
			var row = start_row
			while col < grid_size and row < grid_size:
				positions.append(Vector2i(col, row))
				col += 1
				row += 1
		2:  # Top-right to bottom-left, starting from top edge
			var start_col = randi() % grid_size
			var col = start_col
			var row = 0
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
		3:  # Top-right to bottom-left, starting from right edge
			var start_row = randi() % grid_size
			var col = grid_size - 1
			var row = start_row
			while col >= 0 and row < grid_size:
				positions.append(Vector2i(col, row))
				col -= 1
				row += 1
	
	if positions.size() > 0:
		_execute_hazard(positions)

func spawn_knight_hazard() -> void:
	# Knight attacks specific squares from a position
	var knight_pos = Vector2i(randi() % grid_size, randi() % grid_size)
	var positions: Array[Vector2i] = []
	
	# All possible knight moves
	var offsets = [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	# Add the knight's position and all valid attack squares
	positions.append(knight_pos)
	
	for offset in offsets:
		var target = knight_pos + offset
		if target.x >= 0 and target.x < grid_size and target.y >= 0 and target.y < grid_size:
			positions.append(target)
	
	_execute_hazard(positions)

func _execute_hazard(positions: Array[Vector2i]) -> void:
	if positions.is_empty() or is_resetting:
		return
	
	active_hazards += 1
	
	# Phase 1: Show warning (red squares)
	_show_danger_warning(positions)
	
	# Phase 2: After warning time, check for collision and clear
	await get_tree().create_timer(hazard_warning_time).timeout
	
	# Check if game was reset during the wait
	if is_resetting:
		active_hazards -= 1
		return
	
	# Check if player is on any danger square
	if player and not player.is_dead:
		if player.grid_pos in positions:
			player_hit.emit()
			player.die()
	
	# Phase 3: Animate the hazard moving through (visual only, damage already checked)
	await _animate_hazard_passage(positions)
	
	# Check if game was reset during animation
	if is_resetting:
		active_hazards -= 1
		return
	
	# Phase 4: Clear danger
	_clear_danger_warning(positions)
	
	active_hazards -= 1

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

func _animate_hazard_passage(positions: Array[Vector2i]) -> void:
	# Quick flash through each position to show the piece "moving"
	for pos in positions:
		if is_resetting:
			return
			
		var square = get_floor_square(pos)
		if square:
			var rect = square.get_meta("rect") as ColorRect
			
			# Bright flash
			var tween = create_tween()
			tween.tween_property(rect, "color", Color.WHITE, 0.02)
			tween.tween_property(rect, "color", color_floor_danger, 0.04)
		
		await get_tree().create_timer(hazard_move_speed).timeout
		
		if is_resetting:
			return
		
		# Check collision again during movement (in case player moved into danger)
		if player and not player.is_dead:
			if player.grid_pos == pos:
				player_hit.emit()
				player.die()

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
