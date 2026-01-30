extends Node

@export var initial_delay: float = 3.0  # Time before first hazard
@export var min_interval: float = 1.2   # Fastest spawn rate
@export var max_interval: float = 4.0   # Slowest spawn rate (at start)
@export var speedup_rate: float = 0.95  # How much faster each spawn gets

# Multi-hazard settings
@export var hazards_per_spawn_start: int = 1  # Start with 1 hazard at a time
@export var hazards_per_spawn_max: int = 4    # Max hazards at once
@export var spawns_to_increase: int = 8       # Every X spawns, add another hazard

var current_interval: float
var current_hazards_per_spawn: int
var spawn_count: int = 0
var game_board: Node2D
var spawn_timer: Timer
var is_active: bool = true

func _ready() -> void:
	game_board = get_parent().get_node("GameBoard")
	current_interval = max_interval
	current_hazards_per_spawn = hazards_per_spawn_start
	
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

func _on_spawn_timer_timeout() -> void:
	if not is_active:
		return
	
	# Spawn multiple hazards based on current difficulty
	for i in range(current_hazards_per_spawn):
		# Small delay between multiple hazards so they don't all overlap
		if i > 0:
			await get_tree().create_timer(0.15).timeout
		
		if not is_active:
			return
			
		game_board.spawn_random_hazard()
	
	spawn_count += 1
	
	# Check if we should increase hazards per spawn
	if spawn_count % spawns_to_increase == 0:
		current_hazards_per_spawn = min(current_hazards_per_spawn + 1, hazards_per_spawn_max)
	
	# Speed up for next time
	current_interval = max(min_interval, current_interval * speedup_rate)
	
	# Schedule next spawn
	spawn_timer.start(current_interval)

func _on_player_died() -> void:
	is_active = false
	spawn_timer.stop()

func reset() -> void:
	is_active = true
	current_interval = max_interval
	current_hazards_per_spawn = hazards_per_spawn_start
	spawn_count = 0
	spawn_timer.stop()
	spawn_timer.start(initial_delay)
