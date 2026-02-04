extends Node
## HatPreloader — Ensures all hat textures are included in exports
## Add this as an Autoload (Project > Project Settings > Autoload)
## Name it "HatPreloader" and enable it
##
## This file uses preload() to guarantee textures are included in the PCK.
## Without this, dynamically loaded resources might not be exported.

# Preload all hat textures to ensure they're included in exports
var _preloaded_hats := {
	"hotdog": preload("res://assets/HatPack/hotdog.png"),
	"pinwheel": preload("res://assets/HatPack/pinwheel.png"),
	"birthday": preload("res://assets/HatPack/birthday.png"),
	"umbrella": preload("res://assets/HatPack/umbrella.png"),
	"sunhat": preload("res://assets/HatPack/sunhat.png"),
	"beanie": preload("res://assets/HatPack/beanie.png"),
	"beret": preload("res://assets/HatPack/beret.png"),
	"baseballCap": preload("res://assets/HatPack/baseballCap.png"),
	"bowlerHat": preload("res://assets/HatPack/bowlerHat.png"),
	"outback": preload("res://assets/HatPack/outback.png"),
	"redBonnet": preload("res://assets/HatPack/redBonnet.png"),
	"50sMilitary": preload("res://assets/HatPack/50sMilitary.png"),
	"50sNurse": preload("res://assets/HatPack/50sNurse.png"),
	"police": preload("res://assets/HatPack/police.png"),
	"hardHat": preload("res://assets/HatPack/hardHat.png"),
	"fireman": preload("res://assets/HatPack/fireman.png"),
	"lumberjack": preload("res://assets/HatPack/lumberjack.png"),
	"cowboy": preload("res://assets/HatPack/cowboy.png"),
	"bicorn": preload("res://assets/HatPack/bicorn.png"),
	"classicFedora": preload("res://assets/HatPack/classicFedora.png"),
	"tophat": preload("res://assets/HatPack/tophat.png"),
	"fez": preload("res://assets/HatPack/fez.png"),
	"leprechaun": preload("res://assets/HatPack/leprechaun.png"),
	"captains": preload("res://assets/HatPack/captains.png"),
	"graduation": preload("res://assets/HatPack/graduation.png"),
	"princess": preload("res://assets/HatPack/princess.png"),
	"wig": preload("res://assets/HatPack/wig.png"),
	"catEars": preload("res://assets/HatPack/catEars.png"),
	"bunny": preload("res://assets/HatPack/bunny.png"),
	"antlers": preload("res://assets/HatPack/antlers.png"),
	"viking": preload("res://assets/HatPack/viking.png"),
	"spartan": preload("res://assets/HatPack/spartan.png"),
	"shark": preload("res://assets/HatPack/shark.png"),
	"skeleton": preload("res://assets/HatPack/skeleton.png"),
	"horseHead": preload("res://assets/HatPack/horseHead.png"),
	"freakazoid": preload("res://assets/HatPack/freakazoid.png"),
	"crown": preload("res://assets/HatPack/crown.png"),
	"ww1German": preload("res://assets/HatPack/ww1German.png"),
}

## Get a preloaded hat texture by ID
## Returns null if not found
func get_hat_texture(hat_id: String) -> Texture2D:
	return _preloaded_hats.get(hat_id, null)

func _ready() -> void:
	print("[HatPreloader] Loaded ", _preloaded_hats.size(), " hat textures")
