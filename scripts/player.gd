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

func _ready() -> void:
	game_board = get_parent().get_node("GameBoard")
	grid_size = game_board.grid_size
	
	grid_pos = Vector2i(grid_size / 2, grid_size / 2)
	position = game_board.grid_to_world(grid_pos)
	
	_setup_visuals()

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

func _process(_delta: float) -> void:
	if is_moving or is_dead:
		return
	
	if Input.is_action_just_pressed("move_left"):
		_try_move(Vector2i.LEFT)
	elif Input.is_action_just_pressed("move_right"):
		_try_move(Vector2i.RIGHT)
	elif Input.is_action_just_pressed("move_up"):
		_try_move(Vector2i.UP)
	elif Input.is_action_just_pressed("move_down"):
		_try_move(Vector2i.DOWN)
	
	if Input.is_action_just_pressed("press_button"):
		_try_press()

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
	
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	glow.modulate = Color(1.0, 0.8, 0.0, 0.5)
	modulate.a = 1.0
	visible = true
