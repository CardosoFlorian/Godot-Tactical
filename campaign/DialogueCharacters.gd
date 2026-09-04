class_name DialogueCharacters
extends RefCounted
## Registers runtime Dialogic characters (with placeholder portraits) under
## simple name identifiers, so "Aria: ..." lines in any timeline resolve to
## a real character with a portrait, with zero dependency on the editor
## having indexed the project yet (which only happens once the Dialogic
## editor tab is opened) or on hand-authored .dch files.
##
## Deliberately does NOT use DialogicCharacter.set_identifier() /
## DialogicResourceUtil.register_runtime_resource(): both end up in
## DialogicResourceUtil.set_directory(), which — whenever this code runs
## with Engine.is_editor_hint() true (which happens for autoloads any time
## the project is opened in the editor, not just on Play) — permanently
## writes these runtime-only characters into project.godot's
## [dialogic] directories/dch_directory setting, embedding a script UID
## reference that can end up stale and make project.godot fail to parse
## entirely on the next launch. Writing straight to the Engine metadata
## cache below gets the same runtime lookup behavior without ever touching
## ProjectSettings.

const PORTRAIT_DIR := "res://assets/placeholder/portraits/"

const ROSTER := [
	{"id": "Aria", "portrait": "aria.png"},
	{"id": "Doran", "portrait": "doran.png"},
	{"id": "Kessa", "portrait": "kessa.png"},
	{"id": "Vex", "portrait": "vex.png"},
	{"id": "Rurik", "portrait": "rurik.png"},
	{"id": "Ilsa", "portrait": "ilsa.png"},
]

## All names render in black now that the name label has its own readable
## panel behind it (Kenney ui-pack-pixel-adventure), rather than one color
## per character.
const NAME_COLOR := Color(0, 0, 0, 1)

static var _registered := false

static func register_all() -> void:
	if _registered:
		return
	var directory: Dictionary = DialogicResourceUtil.get_directory("dch")
	for entry in ROSTER:
		var character := DialogicCharacter.new()
		character.display_name = entry["id"]
		character.color = NAME_COLOR
		character.add_portrait("default", PORTRAIT_DIR + entry["portrait"])
		character.default_portrait = "default"
		directory[entry["id"]] = character
	Engine.set_meta("dch_directory", directory)
	_registered = true
