extends Node
## PlayerData — autoload singleton
## Manages player identity, stats, currency, cosmetics, and Firebase sync.

# =====================================================
# FIREBASE CONFIG
# =====================================================
var firebase_url: String = "https://laserchess-a255a-default-rtdb.europe-west1.firebasedatabase.app/"

# === SIGNALS ===
signal profile_loaded()
signal profile_saved()
signal leaderboard_loaded(players: Array)
signal player_profile_loaded(data: Dictionary)
signal firebase_error(msg: String)
signal points_changed(new_total: int)
signal hat_changed(hat_id: String)

# === PLAYER DATA ===
var player_id: String = ""
var player_name: String = ""
var elo: int = 1000
var solo_highscore: int = 0
var total_points: int = 0
var purchased_hats: Array = []   # Array of hat_id strings
var equipped_hat: String = ""    # Currently equipped hat ID ("" = none)
var matches: Array = []          # last 20 match results
var total_games: int = 0
var wins: int = 0
var losses: int = 0
var draws: int = 0

var _save_path: String = "user://player.json"

# === SHOP ITEMS ===
# === SHOP ITEMS (auto from res://assets/hats) ===
var SHOP_HATS: Dictionary = {}
const DEFAULT_HAT_COST := 50

const HAT_PRICES := {
	# === COMMON / JOKE (10–30) ===
	"hotdog": 10,
	"pinwheel": 15,
	"birthday": 20,
	"umbrella": 20,
	"sunhat": 25,
	"beanie": 30,
	"beret": 30,

	# === UNCOMMON (40–75) ===
	"baseballCap": 40,
	"bowlerHat": 45,
	"outback": 45,
	"redBonnet": 50,
	"50sMilitary": 50,
	"50sNurse": 50,
	"police": 60,
	"hardHat": 60,
	"fireman": 60,
	"lumberjack": 70,
	"cowboy": 75,

	# === RARE (90–150) ===
	"bicorn": 90,
	"classicFedora": 100,
	"tophat": 110,
	"fez": 120,
	"leprechaun": 130,
	"captains": 140,
	"graduation": 150,

	# === EPIC (180–300) ===
	"princess": 180,
	"wig": 200,
	"catEars": 220,
	"bunny": 240,
	"antlers": 260,
	"viking": 280,
	"spartann": 300,

	# === LEGENDARY (350–600) ===
	"shark": 350,
	"skeleton": 400,
	"horseHead": 500,
	"freakazoid": 600,

	# === MYTHIC / SPECIAL (800–1000) ===
	"crown": 1000,
	"ww1German": 800
}

const HATS_DIR := "res://assets/HatPack/"

# Per-hat sprite tweaks (only add entries for hats that need fixing)
# pos = extra offset applied to the hat sprite
# scale = multiplier (1.0 = normal, 0.8 = smaller, 1.2 = bigger)
# rot_deg = rotation in degrees
const HAT_TWEAKS := {
	# examples (edit these):
	# "horseHead": {"pos": Vector2(0, 8), "scale": 0.75, "rot_deg": 0},
	# "bicorn": {"pos": Vector2(0, 2), "scale": 0.9, "rot_deg": -5},
	"pinwheel": {"pos": Vector2(0,0), "scale": 1, "rot_deg": 20},
	"hotdog": {"pos": Vector2(0,0), "scale": 1, "rot_deg": 10},
	"umbrella": {"pos": Vector2(0,0), "scale": 1, "rot_deg": 20},
	"birthday": {"pos": Vector2(0,5), "scale": 1, "rot_deg": 20},
	"sunhat": {"pos": Vector2(0,5), "scale": 1, "rot_deg": 0},
	"beanie": {"pos": Vector2(-3,5), "scale": 1, "rot_deg": 45},
	"beret": {"pos": Vector2(0,0), "scale": 0.8, "rot_deg": 20},
	"baseballCap": {"pos": Vector2(5,5), "scale": 1, "rot_deg": 0},
	"takuhatsugasa": {"pos": Vector2(0,3), "scale": 1, "rot_deg": 0},
	"spartan": {"pos": Vector2(0,6), "scale": 1, "rot_deg": 0},
	"robinhood": {"pos": Vector2(0,1), "scale": 1.1, "rot_deg": 0},
	"redBonnet": {"pos": Vector2(0,5), "scale": 0.9, "rot_deg": 0},
	"waldo": {"pos": Vector2(-7,5), "scale": 1, "rot_deg": 20},
	"50sMilitary": {"pos": Vector2(0,2), "scale": 1, "rot_deg": 0},
	"50sNurse": {"pos": Vector2(-2,2), "scale": 1, "rot_deg": 0},
	"beanieWithTassels": {"pos": Vector2(-8,12), "scale": 1.2, "rot_deg": 10},
	"lumberjack": {"pos": Vector2(-2,10), "scale": 1.5, "rot_deg": 0},
	"bicorn": {"pos": Vector2(-3,5), "scale": 1.2, "rot_deg": 0},
	"fez": {"pos": Vector2(-3,5), "scale": 0.9, "rot_deg": 0},
	"leprechaun": {"pos": Vector2(-3,5), "scale": 1.1, "rot_deg": 0},
	"graduation": {"pos": Vector2(-3,5), "scale": 1.1, "rot_deg": 0},
	"princess": {"pos": Vector2(-7,2), "scale": 1.1, "rot_deg": 0},
	"shark": {"pos": Vector2(-11,5), "scale": 1.5, "rot_deg": 0},
	"horseHead": {"pos": Vector2(5,5), "scale": 1.5, "rot_deg": 0},
	"freakazoid": {"pos": Vector2(-11,5), "scale": 1.5, "rot_deg": 0},
	"crown": {"pos": Vector2(-3,5), "scale": 1.4, "rot_deg": 0},
	
}


# === NAME GENERATOR ===
const _ADJ = [
	"Swift","Bold","Sly","Fierce","Quick","Sharp","Wild","Dark","Bright",
	"Lucky","Brave","Cool","Keen","Grim","Deft","Calm","Red","Iron","Jade","Void"
]
const _PIECE = ["Pawn","Rook","Bishop","Knight","King","Queen","Castle"]

# =====================
# LIFECYCLE
# =====================

func _ready() -> void:
	_build_shop_hats()
	_load_local()
	if player_id.is_empty():
		_create_new_player()
	elif firebase_url != "":
		load_from_firebase()

# =====================
# LOCAL SAVE / LOAD
# =====================

func _load_local() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var file = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var d = json.data
		player_id = d.get("player_id", "")
		player_name = d.get("name", "")
		elo = d.get("elo", 1000)
		solo_highscore = d.get("solo_highscore", 0)
		total_points = d.get("total_points", 0)
		purchased_hats = d.get("purchased_hats", [])
		if purchased_hats == null:
			purchased_hats = []
		equipped_hat = d.get("equipped_hat", "")
		matches = d.get("matches", [])
		if matches == null:
			matches = []
		total_games = d.get("total_games", 0)
		wins = d.get("wins", 0)
		losses = d.get("losses", 0)
		draws = d.get("draws", 0)

func _save_local() -> void:
	var file = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"player_id": player_id,
		"name": player_name,
		"elo": elo,
		"solo_highscore": solo_highscore,
		"total_points": total_points,
		"purchased_hats": purchased_hats,
		"equipped_hat": equipped_hat,
		"matches": matches,
		"total_games": total_games,
		"wins": wins,
		"losses": losses,
		"draws": draws
	}))

func _create_new_player() -> void:
	player_id = _generate_uuid()
	player_name = _random_name()
	elo = 1000
	solo_highscore = 0
	total_points = 0
	purchased_hats = []
	equipped_hat = ""
	matches = []
	total_games = 0
	wins = 0
	losses = 0
	draws = 0
	_save_local()
	if firebase_url != "":
		save_to_firebase()

# =====================
# PUBLIC API
# =====================

func set_player_name(new_name: String) -> void:
	player_name = new_name.strip_edges().substr(0, 16)
	if player_name.is_empty():
		player_name = _random_name()
	_save_local()
	if firebase_url != "":
		save_to_firebase()

func update_solo_highscore(score: int) -> void:
	if score > solo_highscore:
		solo_highscore = score
		_save_local()
		if firebase_url != "":
			save_to_firebase()

func add_points(amount: int) -> void:
	if amount <= 0:
		return
	total_points += amount
	points_changed.emit(total_points)
	_save_local()
	if firebase_url != "":
		save_to_firebase()

func purchase_hat(hat_id: String) -> bool:
	if hat_id not in SHOP_HATS:
		return false
	if hat_id in purchased_hats:
		return false  # already owned
	var cost = SHOP_HATS[hat_id]["cost"]
	if total_points < cost:
		return false  # can't afford
	total_points -= cost
	purchased_hats.append(hat_id)
	points_changed.emit(total_points)
	_save_local()
	if firebase_url != "":
		save_to_firebase()
	return true

func equip_hat(hat_id: String) -> void:
	if hat_id == "" or hat_id in purchased_hats:
		equipped_hat = hat_id
		hat_changed.emit(equipped_hat)
		_save_local()

func apply_match_result(result: String, my_score: int, opp_score: int,
		opp_name: String, opp_elo: int, elo_change: int) -> void:
	# If server didn't calculate ELO (elo_change=0), calculate client-side
	var actual_elo_change := elo_change
	if elo_change == 0 and result != "draw":
		actual_elo_change = calculate_elo_change(elo, opp_elo, result)
		print("[DEBUG ELO] Server returned 0, calculated client-side: ", actual_elo_change)
	elif elo_change == 0 and result == "draw":
		# For draws, still calculate a small change based on ELO difference
		actual_elo_change = calculate_elo_change(elo, opp_elo, result)
		print("[DEBUG ELO] Draw - calculated client-side: ", actual_elo_change)
	
	elo += actual_elo_change
	elo = max(100, elo)
	total_games += 1

	match result:
		"win":
			wins += 1
		"lose":
			losses += 1
		"draw":
			draws += 1

	matches.append({
		"opponent": opp_name,
		"opp_elo": opp_elo,
		"my_score": my_score,
		"opp_score": opp_score,
		"result": result,
		"elo_change": actual_elo_change,
		"timestamp": int(Time.get_unix_time_from_system())
	})
	if matches.size() > 20:
		matches = matches.slice(matches.size() - 20)

	_save_local()
	if firebase_url != "":
		save_to_firebase()

## Calculate ELO change using standard chess formula (like chess.com)
## K-factor = 32 (standard for online play)
func calculate_elo_change(my_elo: int, opponent_elo: int, result: String) -> int:
	const K_FACTOR := 32.0
	
	# Expected score formula: E = 1 / (1 + 10^((opponent_elo - my_elo) / 400))
	var expected := 1.0 / (1.0 + pow(10.0, float(opponent_elo - my_elo) / 400.0))
	
	# Actual score: 1 for win, 0.5 for draw, 0 for loss
	var actual := 0.5
	match result:
		"win":
			actual = 1.0
		"lose":
			actual = 0.0
		"draw":
			actual = 0.5
	
	# ELO change = K * (actual - expected)
	var change := K_FACTOR * (actual - expected)
	return int(round(change))

func get_win_rate() -> float:
	if total_games == 0:
		return 0.0
	return float(wins) / float(total_games) * 100.0

# =====================
# FIREBASE — SAVE
# =====================

func save_to_firebase() -> void:
	if firebase_url.is_empty():
		return

	var url = firebase_url + "/players/" + player_id + ".json"
	var data = JSON.stringify({
		"name": player_name,
		"elo": elo,
		"solo_highscore": solo_highscore,
		"total_points": total_points,
		"total_games": total_games,
		"wins": wins,
		"losses": losses,
		"draws": draws,
		"matches": matches
	})

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code, _h, _b):
		http.queue_free()
		if code >= 200 and code < 300:
			profile_saved.emit()
		else:
			firebase_error.emit("Save failed (HTTP " + str(code) + ")")
	)
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_PUT, data)

# =====================
# FIREBASE — LOAD OWN PROFILE
# =====================

func load_from_firebase() -> void:
	if firebase_url.is_empty():
		profile_loaded.emit()
		return

	var url = firebase_url + "/players/" + player_id + ".json"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_profile_loaded.bind(http))
	http.request(url)

func _on_profile_loaded(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if code != 200:
		profile_loaded.emit()
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or json.data == null:
		save_to_firebase()
		profile_loaded.emit()
		return

	if json.data is Dictionary:
		var d = json.data
		player_name = d.get("name", player_name)
		elo = d.get("elo", elo)
		solo_highscore = d.get("solo_highscore", solo_highscore)
		total_points = d.get("total_points", total_points)
		total_games = d.get("total_games", total_games)
		wins = d.get("wins", wins)
		losses = d.get("losses", losses)
		draws = d.get("draws", draws)
		matches = d.get("matches", matches)
		if matches == null:
			matches = []
		_save_local()

	profile_loaded.emit()

# =====================
# FIREBASE — LEADERBOARD
# =====================

func load_leaderboard() -> void:
	if firebase_url.is_empty():
		firebase_error.emit("Firebase not configured")
		leaderboard_loaded.emit([])
		return

	var url = firebase_url + "/players.json?orderBy=\"elo\"&limitToLast=50"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_leaderboard_loaded.bind(http))
	http.request(url)

func _on_leaderboard_loaded(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if code != 200:
		firebase_error.emit("Leaderboard load failed")
		leaderboard_loaded.emit([])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		leaderboard_loaded.emit([])
		return

	var players_arr: Array = []
	for pid in json.data:
		var p = json.data[pid]
		if p is Dictionary:
			p["player_id"] = pid
			players_arr.append(p)

	players_arr.sort_custom(func(a, b): return a.get("elo", 0) > b.get("elo", 0))
	leaderboard_loaded.emit(players_arr)

# =====================
# FIREBASE — OTHER PLAYER PROFILE
# =====================

func load_player_profile(pid: String) -> void:
	if firebase_url.is_empty():
		firebase_error.emit("Firebase not configured")
		return

	var url = firebase_url + "/players/" + pid + ".json"
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_other_profile_loaded.bind(http, pid))
	http.request(url)

func _on_other_profile_loaded(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest, pid: String) -> void:
	http.queue_free()

	if code != 200:
		player_profile_loaded.emit({})
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		player_profile_loaded.emit({})
		return

	var d = json.data
	d["player_id"] = pid
	player_profile_loaded.emit(d)

# =====================
# HELPERS
# =====================

func _generate_uuid() -> String:
	var chars = "0123456789abcdef"
	var parts = [8, 4, 4, 4, 12]
	var result = ""
	for i in parts.size():
		if i > 0:
			result += "-"
		for j in parts[i]:
			result += chars[randi() % 16]
	return result

func _random_name() -> String:
	return _ADJ[randi() % _ADJ.size()] + _PIECE[randi() % _PIECE.size()]

func _build_shop_hats() -> void:
	SHOP_HATS.clear()

	var dir := DirAccess.open(HATS_DIR)
	if dir == null:
		push_warning("Hats folder not found: " + HATS_DIR)
		return

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if !dir.current_is_dir() and file.to_lower().ends_with(".png"):
			var id := file.get_basename() # filename without extension
			var display_name := id.replace("_", " ").capitalize()

			SHOP_HATS[id] = {
				"name": display_name,
				"cost": HAT_PRICES.get(id, DEFAULT_HAT_COST),
				"desc": "Cosmetic hat",
				"tex": HATS_DIR + "/" + file
			}
		file = dir.get_next()
	dir.list_dir_end()
