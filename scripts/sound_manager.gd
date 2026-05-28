extends Node

## SoundManager — autoload singleton
## Plays named sound effects with volume control & per-sound normalization.
##
## SETUP:
## 1. Add as autoload: Project > Settings > Autoload (name: SoundManager)
## 2. Put your .wav / .ogg / .mp3 files in  res://assets/sfx/
## 3. Edit SOUND_PATHS to point at your files.
## 4. Tweak SOUND_GAIN values to balance loud/quiet sounds against each other.
##
## USAGE:
##   SoundManager.play("move")
##   SoundManager.play_pitched("move", 0.9, 1.1)

# =====================
# SOUND FILE PATHS
# =====================

const SOUND_PATHS := {
	# --- Player ---
	"move":         "res://assets/sfx/step1.mp3",
	"hit":          "res://assets/sfx/testhit.mp3",
	"wall_hit":     "res://assets/sfx/testhit.mp3",
	"miss":         "res://assets/sfx/step1.mp3",
	"bump":         "res://assets/sfx/bump.mp3",
	"death":        "res://assets/sfx/attention.mp3",

	# --- UI / Menu ---
	"click":        "res://assets/sfx/click.mp3",
	"purchase":     "res://assets/sfx/purchase.wave",
	"equip":        "res://assets/sfx/equip.mp3",
	"error":        "res://assets/sfx/error.mp3",

	# --- Hazards ---
	"warning":      "res://assets/sfx/warningtest.mp3",
	"hazard_slide": "res://assets/sfx/testdrag.mp3",

	# --- Match ---
	"countdown":    "res://assets/sfx/countdown.mp3",
	"match_start":  "res://assets/sfx/attention1.mp3",
	"win":          "res://assets/sfx/win.mp3",
	"lose":         "res://assets/sfx/lose.mp3",

	"intro":        "res://assets/sfx/intro.mp3",
}

# =====================
# PER-SOUND GAIN (dB)
# =====================
## Tweak these to balance your sound files against each other.
## Negative = quieter, 0 = unchanged, positive = louder.

const SOUND_GAIN := {
	# --- Player ---
	"move":         -4.0,
	"hit":          -2.0,
	"wall_hit":     -2.0,
	"miss":         -6.0,
	"bump":         -4.0,
	"death":        -1.0,

	# --- UI ---
	"click":        -4.0,
	"purchase":     -2.0,
	"equip":        -3.0,
	"error":        -2.0,

	# --- Hazards ---
	"warning":      -3.0,
	"hazard_slide": -3.0,

	# --- Match ---
	"countdown":    -2.0,
	"match_start":  -1.0,
	"win":          -1.0,
	"lose":         -1.0,
}

# =====================
# VOLUME CAP
# =====================
const MAX_VOLUME_DB := -3.0

# =====================
# VOLUME CONTROLS (0.0 – 1.0 linear)
# =====================
var sfx_volume: float = 1.0:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume()

var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volume()

# =====================
# INTERNALS
# =====================
const POOL_SIZE := 12
var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next_player: int = 0

func _ready() -> void:
	# Keep SoundManager running even when tree is paused (for pause menu sounds)
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in POOL_SIZE:
		var asp = AudioStreamPlayer.new()
		asp.bus = "Master"
		add_child(asp)
		_players.append(asp)
	_apply_bus_volume()

# =====================
# PUBLIC API
# =====================

func play(sound_name: String, volume_db_offset: float = 0.0) -> void:
	"""Play a named sound. Silently does nothing if the file is missing."""
	if sfx_volume <= 0.0 or master_volume <= 0.0:
		return

	var path = SOUND_PATHS.get(sound_name, "")
	if path.is_empty():
		return

	var stream = _get_stream(path)
	if stream == null:
		return

	var asp = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE

	asp.stream = stream
	asp.pitch_scale = 1.0
	var gain = SOUND_GAIN.get(sound_name, 0.0) + volume_db_offset
	asp.volume_db = min(linear_to_db(sfx_volume) + gain, MAX_VOLUME_DB)
	asp.play()

func play_pitched(sound_name: String, pitch_min: float = 0.9, pitch_max: float = 1.1, volume_db_offset: float = 0.0) -> void:
	"""Play with random pitch variation — great for repeated sounds like footsteps.
	   Pass a negative volume_db_offset to make this instance quieter."""
	if sfx_volume <= 0.0 or master_volume <= 0.0:
		return

	var path = SOUND_PATHS.get(sound_name, "")
	if path.is_empty():
		return

	var stream = _get_stream(path)
	if stream == null:
		return

	var asp = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE

	asp.stream = stream
	asp.pitch_scale = randf_range(pitch_min, pitch_max)
	var gain = SOUND_GAIN.get(sound_name, 0.0) + volume_db_offset
	asp.volume_db = min(linear_to_db(sfx_volume) + gain, MAX_VOLUME_DB)
	asp.play()

# =====================
# INTERNAL
# =====================

func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var stream = load(path) as AudioStream
	_cache[path] = stream
	return stream

func _apply_bus_volume() -> void:
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
