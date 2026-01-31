extends Node

# Piece color setting: true = player is white, false = player is black
var player_is_white: bool = true

# High score (for profile)
var high_score: int = 0

# Save file path
const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func get_player_king_texture() -> String:
	if player_is_white:
		return "res://assets/king.png"
	else:
		return "res://assets/king1.png"

func get_enemy_textures() -> Dictionary:
	# Player white = enemies black, and vice versa
	if player_is_white:
		return {
			"rook": "res://assets/rook1.png",
			"bishop": "res://assets/bishop1.png",
			"knight": "res://assets/knight1.png"
		}
	else:
		return {
			"rook": "res://assets/rook.png",
			"bishop": "res://assets/bishop.png",
			"knight": "res://assets/knight.png"
		}

func toggle_colors() -> void:
	player_is_white = not player_is_white
	save_settings()

func update_high_score(score: int) -> void:
	if score > high_score:
		high_score = score
		save_settings()

func get_title() -> String:
	# Chess-themed titles based on high score
	if high_score >= 100:
		return "Grandmaster"
	elif high_score >= 75:
		return "International Master"
	elif high_score >= 50:
		return "FIDE Master"
	elif high_score >= 35:
		return "Candidate Master"
	elif high_score >= 25:
		return "Expert"
	elif high_score >= 15:
		return "Class A"
	elif high_score >= 10:
		return "Class B"
	elif high_score >= 5:
		return "Class C"
	else:
		return "Beginner"

func get_elo() -> int:
	# Rough ELO estimate based on high score
	return 800 + (high_score * 20)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "player_is_white", player_is_white)
	config.set_value("stats", "high_score", high_score)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		player_is_white = config.get_value("settings", "player_is_white", true)
		high_score = config.get_value("stats", "high_score", 0)
