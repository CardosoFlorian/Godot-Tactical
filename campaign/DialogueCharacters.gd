class_name DialogueCharacters
extends RefCounted
## Registers runtime Dialogic characters (with placeholder portraits) under
## simple name identifiers, using Dialogic's own runtime-registration API
## (DialogicCharacter.set_identifier) instead of hand-authored .dch files.
## This means "Aria: ..." lines in any timeline resolve to a real character
## with a portrait, with zero dependency on the editor having indexed the
## project yet (which only happens once the Dialogic editor tab is opened).

const PORTRAIT_DIR := "res://assets/placeholder/portraits/"

const ROSTER := [
	{"id": "Aria", "portrait": "aria.png"},
	{"id": "Doran", "portrait": "doran.png"},
	{"id": "Kessa", "portrait": "kessa.png"},
	{"id": "Vex", "portrait": "vex.png"},
	{"id": "Rurik", "portrait": "rurik.png"},
	{"id": "Ilsa", "portrait": "ilsa.png"},
]

static var _registered := false

static func register_all() -> void:
	if _registered:
		return
	for entry in ROSTER:
		var character := DialogicCharacter.new()
		character.display_name = entry["id"]
		character.add_portrait("default", PORTRAIT_DIR + entry["portrait"])
		character.default_portrait = "default"
		character.set_identifier(entry["id"])
	_registered = true
