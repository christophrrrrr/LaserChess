extends Node

@export var initial_delay: float = 3.0  # Time before first hazard
@export var base_interval: float = 2.5  # Base time between hazards

# Difficulty scaling based on score
@export var min_interval: float = 0.8           # Fastest spawn rate
@export var interval_decrease_per_score: float = 0.08  # How much faster per point
@export var max_hazards_per_spawn: int = 4      # Max hazards at once
@export var score_per_extra_hazard: int = 10    # Every X points, add another hazard

var game_board: Node2D
var spawn_timer: Timer
var is_active: bool = true

func _ready() -> void:
	game_board = get_parent().get_node("GameBoard")
	
	# Create and configure timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Start with initial delay
	spawn_timer.start(initial_delay)
	
	# Connect to player death to stop spawning
	var player = get_parent().get_node("Player")
	player.died.connect(_on_player_died)

func _get_current_interval() -> float:
	# Calculate interval based on current score
	var score = game_board.score
	var interval = base_interval - (score * interval_decrease_per_score)
	return max(min_interval, interval)

func _get_hazards_per_spawn() -> int:
	# Calculate how many hazards to spawn based on score
	var score = game_board.score
	var hazards = 1 + int(score / score_per_extra_hazard)
	return min(hazards, max_hazards_per_spawn)

func _on_spawn_timer_timeout() -> void:
	if not is_active:
		return
	
	var hazards_to_spawn = _get_hazards_per_spawn()
	
	# Spawn multiple hazards based on current difficulty
	for i in range(hazards_to_spawn):
		# Small delay between multiple hazards so they don't all overlap
		if i > 0:
			await get_tree().create_timer(0.15).timeout
		
		if not is_active:
			return
			
		game_board.spawn_random_hazard()
	
	# Schedule next spawn based on current score
	var next_interval = _get_current_interval()
	spawn_timer.start(next_interval)

func _on_player_died() -> void:
	is_active = false
	spawn_timer.stop()

func reset() -> void:
	is_active = true
	spawn_timer.stop()
	spawn_timer.start(initial_delay)
