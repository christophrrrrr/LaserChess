extends Node2D

signal died

@export var move_duration: float = 0.08  # Fast and snappy

var grid_pos: Vector2i = Vector2i(2, 2)  # Starting position (center-ish)
var is_moving: bool = false
var grid_size: int = 6
var is_dead: bool = false

# Reference to game board (set in _ready)
var game_board: Node2D

# Visual node
var sprite: ColorRect

func _ready() -> void:
	# Get reference to game board (sibling node)
	game_board = get_parent().get_node("GameBoard")
	grid_size = game_board.grid_size
	
	# Start in the center
	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)
	
	_setup_visuals()

func _setup_visuals() -> void:
	# Create a simple colored square as placeholder
	# You'll replace this with your pixel art sprite later
	sprite = ColorRect.new()
	sprite.size = Vector2(60, 60)
	sprite.position = -sprite.size / 2  # Center it
	sprite.color = Color(1.0, 0.85, 0.2)  # Golden yellow
	add_child(sprite)

func _process(_delta: float) -> void:
	# Don't accept input while moving or dead
	if is_moving or is_dead:
		return
	
	# Handle movement
	if Input.is_action_just_pressed("move_left"):
		_try_move(Vector2i.LEFT)
	elif Input.is_action_just_pressed("move_right"):
		_try_move(Vector2i.RIGHT)
	elif Input.is_action_just_pressed("move_up"):
		_try_move(Vector2i.UP)
	elif Input.is_action_just_pressed("move_down"):
		_try_move(Vector2i.DOWN)
	
	# Handle pressing floor squares (only when not dead)
	if Input.is_action_just_pressed("press_button"):
		_try_press()

func _try_move(direction: Vector2i) -> void:
	var new_pos = grid_pos + direction
	
	# Check if move is within bounds
	if new_pos.x < 0 or new_pos.x >= grid_size or new_pos.y < 0 or new_pos.y >= grid_size:
		# Hit a wall - check if there's a target wall square to hit
		var hit = game_board.try_wall_press(grid_pos, direction)
		
		if hit:
			_do_wall_hit_animation(direction)
		else:
			_do_bump_animation(direction)
		return
	
	# Valid move - update position and animate
	grid_pos = new_pos
	_do_move_animation()

func _do_move_animation() -> void:
	is_moving = true
	var target_pos = game_board.grid_to_world(grid_pos)
	
	# Smooth movement with slight overshoot (juicy!)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, move_duration)
	tween.tween_callback(func(): is_moving = false)
	
	# Squash and stretch effect
	var squash_tween = create_tween()
	squash_tween.tween_property(self, "scale", Vector2(1.2, 0.8), move_duration * 0.4)
	squash_tween.tween_property(self, "scale", Vector2.ONE, move_duration * 0.4).set_trans(Tween.TRANS_BACK)

func _do_bump_animation(direction: Vector2i) -> void:
	# Small bump against the wall - feels responsive
	is_moving = true
	var bump_offset = Vector2(direction) * 15
	var original_pos = position
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + bump_offset, 0.04)
	tween.tween_property(self, "position", original_pos, 0.08).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_moving = false)
	
	# Little shake
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "scale", Vector2(0.9, 1.1), 0.04)
	shake_tween.tween_property(self, "scale", Vector2.ONE, 0.06)

func _do_wall_hit_animation(direction: Vector2i) -> void:
	# Bump into wall but with success feeling
	is_moving = true
	var bump_offset = Vector2(direction) * 20
	var original_pos = position
	
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + bump_offset, 0.05)
	tween.tween_property(self, "position", original_pos, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func(): is_moving = false)
	
	# Satisfying squash
	var squash_tween = create_tween()
	squash_tween.tween_property(self, "scale", Vector2(0.8, 1.2), 0.05)
	squash_tween.tween_property(self, "scale", Vector2(1.15, 0.85), 0.08)
	squash_tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK)

func _try_press() -> void:
	# Only handles floor squares now (walls are handled by movement)
	var hit = game_board.try_floor_press(grid_pos)
	
	# Different animation based on hit or miss
	if hit:
		_do_press_hit_animation()
	else:
		_do_press_miss_animation()

func _do_press_hit_animation() -> void:
	# Satisfying squash on successful hit
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.05)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)

func _do_press_miss_animation() -> void:
	# Small shake for miss
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(5, 0), 0.02)
	tween.tween_property(self, "position", original_pos - Vector2(5, 0), 0.04)
	tween.tween_property(self, "position", original_pos, 0.02)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Death animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "color", Color.RED, 0.1)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.tween_property(self, "rotation", PI * 2, 0.3)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(func(): died.emit())

# Reset player for new game
func reset() -> void:
	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)
	scale = Vector2.ONE
	rotation = 0
	is_moving = false
	is_dead = false
	sprite.color = Color(1.0, 0.85, 0.2)
	sprite.modulate.a = 1.0
	modulate.a = 1.0
	visible = true
