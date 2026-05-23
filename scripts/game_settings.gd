extends Node

# Piece color setting: true = player is white, false = player is black
var player_is_white: bool = true

# High score (backward compat — PlayerData is now source of truth)
var high_score: int = 0

# === VOLUME (0.0 – 1.0, linear) ===
var sfx_volume: float = 1.0
var master_volume: float = 1.0

# === UI PREFS ===
var leaderboard_tab: String = "solo"  # "elo" or "solo"
var leaderboard_elo_mode: String = "bullet"  # "bullet" | "blitz" | "rapid"
var ranked_time_mode: String = "bullet"  # "bullet" | "blitz" | "rapid"

const SAVE_PATH = "user://settings.cfg"

func _ready() -> void:
	load_settings()

func get_player_king_texture() -> String:
	if player_is_white:
		return "res://assets/king.png"
	else:
		return "res://assets/king1.png"

func get_enemy_textures() -> Dictionary:
	if player_is_white:
		return {
			"rook": "res://assets/rook1.png",
			"bishop": "res://assets/bishop1.png",
			"knight": "res://assets/knight1.png",
			"pawn": "res://assets/pawn1.png"
		}
	else:
		return {
			"rook": "res://assets/rook.png",
			"bishop": "res://assets/bishop.png",
			"knight": "res://assets/knight.png",
			"pawn": "res://assets/pawn.png"
		}

func toggle_colors() -> void:
	player_is_white = not player_is_white
	save_settings()

func update_high_score(score: int) -> void:
	if score > high_score:
		high_score = score
		save_settings()

# === VOLUME API ===

func set_leaderboard_tab(tab: String) -> void:
	leaderboard_tab = tab
	save_settings()

func set_leaderboard_elo_mode(mode: String) -> void:
	leaderboard_elo_mode = mode
	save_settings()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	SoundManager.sfx_volume = sfx_volume
	save_settings()

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	SoundManager.master_volume = master_volume
	save_settings()

# === SAVE / LOAD ===

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("settings", "player_is_white", player_is_white)
	config.set_value("stats", "high_score", high_score)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("ui", "leaderboard_tab", leaderboard_tab)
	config.set_value("ui", "leaderboard_elo_mode", leaderboard_elo_mode)
	config.save(SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		player_is_white = config.get_value("settings", "player_is_white", true)
		high_score = config.get_value("stats", "high_score", 0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		master_volume = config.get_value("audio", "master_volume", 1.0)
		leaderboard_tab = config.get_value("ui", "leaderboard_tab", "solo")
		leaderboard_elo_mode = config.get_value("ui", "leaderboard_elo_mode", "bullet")

	# Push saved volumes to SoundManager (it's loaded before us as autoload)
	_apply_volume.call_deferred()

func _apply_volume() -> void:
	SoundManager.sfx_volume = sfx_volume
	SoundManager.master_volume = master_volume
