extends Node

@export var initial_delay: float = 3.0  ## Time before first hazard

@export_group("Difficulty Curve")
@export var base_interval: float = 2.8  ## Starting interval between spawns
@export var min_interval: float = 0.8   ## Absolute fastest spawn rate
@export var difficulty_scale: float = 0.5  ## How much log() affects interval
@export var difficulty_curve: float = 0.12  ## How quickly the curve bends

@export_group("Multi-Hazard")
@export var max_hazards_per_spawn: int = 4  ## Max simultaneous hazards
@export var score_per_extra_hazard: int = 18  ## Score per additional hazard (sqrt-based)

var game_board: Node2D
var spawn_timer: Timer
var is_active: bool = true

func _ready() -> void:
	game_board = get_parent().get_node("GameBoard")
	
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	spawn_timer.start(initial_delay)
	
	var player = get_parent().get_node("Player")
	player.died.connect(_on_player_died)

func _get_current_interval() -> float:
	var s = game_board.score
	var interval = base_interval - difficulty_scale * log(1.0 + s * difficulty_curve)
	return max(min_interval, interval)

func _get_hazards_per_spawn() -> int:
	var s = game_board.score
	var hazards = 1 + int(sqrt(float(s) / score_per_extra_hazard))
	return min(hazards, max_hazards_per_spawn)

func _on_spawn_timer_timeout() -> void:
	if not is_active:
		return
	
	var hazards_to_spawn = _get_hazards_per_spawn()
	
	for i in range(hazards_to_spawn):
		if i > 0:
			await get_tree().create_timer(0.15).timeout
		
		if not is_active:
			return
		
		game_board.spawn_random_hazard()
	
	var next_interval = _get_current_interval()
	spawn_timer.start(next_interval)

func _on_player_died() -> void:
	is_active = false
	spawn_timer.stop()

func reset() -> void:
	is_active = true
	spawn_timer.stop()
	spawn_timer.start(initial_delay)
