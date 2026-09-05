class_name DialogueCharacters
extends RefCounted
## Registers runtime Dialogic characters (with placeholder portraits) under
## simple name identifiers, so "Aurora: ..." lines in any timeline resolve to
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

## Everyone but Aurora still gets a single "default" portrait. Aurora has
## real expression art — see AURORA_PORTRAITS below — so she's built
## separately in register_all() instead of through this flat list.
const ROSTER := [
	{"id": "Doran", "portrait": "doran.png"},
	{"id": "Kessa", "portrait": "kessa.png"},
	{"id": "Elyn", "portrait": "elyn.png"},
	{"id": "Vex", "portrait": "vex.png"},
	{"id": "Rurik", "portrait": "rurik.png"},
	{"id": "Ilsa", "portrait": "ilsa.png"},
	{"id": "Skarn", "portrait": "skarn.png"},
]

## Portrait name -> file, for Aurora specifically. Pick one per line with
## Dialogic's "Name (portrait): text" syntax, e.g. "Aurora (mad): Kessa...".
const AURORA_PORTRAITS := {
	"neutral": "aurora_neutral.png",
	"happy": "aurora_happy.png",
	"sad": "aurora_sad.png",
	"mad": "aurora_mad.png",
	"shock": "aurora_shock.png",
}

## All names render in black now that the name label has its own readable
## panel behind it (Kenney ui-pack-pixel-adventure), rather than one color
## per character.
const NAME_COLOR := Color(0, 0, 0, 1)

## The ROSTER portraits are 32x32 battle-map tokens, never meant to be
## blown up to fill a VN portrait's full container height (which is what
## happens at scale 1.0 — a blocky giant circle). Aurora has real portrait
## art so she keeps the default 1.0.
const PLACEHOLDER_PORTRAIT_SCALE := 0.35

## Dialogic's VN portrait containers only scale-to-fit the container HEIGHT
## and let width overflow into neighboring slots uncropped (FIT_SCALE_HEIGHT
## mode). Aurora's art is a wide action pose (long flowing cape/ponytail),
## content bounding box ~93% of a 1024x1536 canvas, so at scale 1.0 she
## renders ~480-540px wide. The "center" position's default 256px-wide slot
## (1280 screen width / 5 equal positions) was nowhere near enough — her
## overflow bled into whichever neighbor joined next to her (Doran on
## intro/victory's "left", Kessa on "right") and got drawn over by that
## neighbor's own portrait, visually chewing into her hair/cape on that
## side. Fixed at the layout level instead of by shrinking her: "leftmost"
## and "rightmost" (see vn_portrait_layer_tactical.tscn, used by
## tactical_vn_style.tres) are unused by every timeline in this project, so
## that reclaimed space now widens "center" to 640px — comfortably wider
## than her ~540px worst case — while "left"/"right" (Doran/Kessa) keep
## their original 256px width untouched. Scale 1.0 now fits with margin.
const AURORA_PORTRAIT_SCALE := 1.0

## How a non-speaking joined character is dimmed/shrunk relative to the one
## currently talking — the classic "other characters fade into the
## background" VN convention. Neither Dialogic's stock VN portrait layer nor
## its SPEAKER container mode does this automatically, so _on_speaker_updated
## drives it by hand.
const SPEAKING_MODULATE := Color.WHITE
const SPEAKING_SCALE := 1.0
const NOT_SPEAKING_MODULATE := Color(0.55, 0.55, 0.6, 1.0)
const NOT_SPEAKING_SCALE := 0.92
const SPEAKER_DIM_DURATION := 0.2

static var _registered := false
static var _dimming_connected := false

static func register_all() -> void:
	if _registered:
		return
	var directory: Dictionary = DialogicResourceUtil.get_directory("dch")

	var aurora := DialogicCharacter.new()
	aurora.display_name = "Aurora"
	aurora.color = NAME_COLOR
	aurora.scale = AURORA_PORTRAIT_SCALE
	for portrait_name in AURORA_PORTRAITS:
		aurora.add_portrait(portrait_name, PORTRAIT_DIR + AURORA_PORTRAITS[portrait_name])
	aurora.default_portrait = "neutral"
	directory["Aurora"] = aurora

	for entry in ROSTER:
		var character := DialogicCharacter.new()
		character.display_name = entry["id"]
		character.color = NAME_COLOR
		character.scale = PLACEHOLDER_PORTRAIT_SCALE
		character.add_portrait("default", PORTRAIT_DIR + entry["portrait"])
		character.default_portrait = "default"
		directory[entry["id"]] = character

	Engine.set_meta("dch_directory", directory)
	_registered = true

## Safe to call repeatedly (e.g. once per CampaignFlow._play_dialogue) —
## only actually connects once. Must be called after Dialogic itself has
## initialized (its subsystems aren't ready yet during autoload _ready(),
## since CampaignFlow is registered before Dialogic in project.godot), so
## this is called lazily from CampaignFlow right before a timeline starts
## rather than from register_all().
static func connect_speaker_dimming() -> void:
	if _dimming_connected:
		return
	Dialogic.Text.speaker_updated.connect(_on_speaker_updated)
	_dimming_connected = true

static func _on_speaker_updated(speaker: DialogicCharacter) -> void:
	for character in Dialogic.Portraits.get_joined_characters():
		var node := Dialogic.Portraits.get_character_node(character)
		if not is_instance_valid(node):
			continue
		var speaking := character == speaker
		var tween := node.create_tween().set_parallel(true)
		tween.tween_property(node, "modulate", SPEAKING_MODULATE if speaking else NOT_SPEAKING_MODULATE, SPEAKER_DIM_DURATION)
		tween.tween_property(node, "scale", Vector2.ONE * (SPEAKING_SCALE if speaking else NOT_SPEAKING_SCALE), SPEAKER_DIM_DURATION)
