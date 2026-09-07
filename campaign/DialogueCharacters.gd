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
##
## Only Aurora's 3 real companions get named Dialogic characters. Regular
## enemies (Vex/Rurik/Ilsa/Skarn and future generic spawns) use class-based
## display names ("Bandit", "Chevalier", ...) instead of a person's name and
## never speak in dialogue, so they have no entry here — only named/boss
## enemies would ever need one.
##
## Doran removed 2026-09-05: replaced by Lycith (see LYCITH_PORTRAITS below)
## as one of Aurora's 3 companions in every timeline. Elyn removed 2026-09-07,
## same way: replaced by Martin (see MARTIN_PORTRAITS below).
const ROSTER := [
	{"id": "Kessa", "portrait": "kessa.png"},
]

## Lycith portrait name -> file, same AURORA_PORTRAITS pattern. Lives in its
## own subfolder (assets/placeholder/portraits/lycith/) — see AURORA_PORTRAITS
## below for why (2026-09-07 reorg, once there were 10 expressions per
## character and a flat folder got hard to search).
const LYCITH_PORTRAITS := {
	"neutral": "lycith/neutral.png",
	"happy": "lycith/happy.png",
	"sad": "lycith/sad.png",
	"mad": "lycith/mad.png",
	"shock": "lycith/shock.png",
	"laugh": "lycith/laugh.png",
	"stern": "lycith/stern.png",
	"talk": "lycith/talk.png",
	"embarrassed": "lycith/embarrassed.png",
	"pensive": "lycith/pensive.png",
}

## Both Aurora and Lycith switched from full-body action-pose art to bust
## (chest-up) portraits on 2026-09-06 — see AURORA_PORTRAIT_SCALE below for
## the shared reasoning on why bust art needs a much smaller character scale
## than the old full-body art did (and for the later retune when the source
## sheet's crop proportions changed again). Lycith's bust canvas matches
## Aurora's proportions (both cropped from the same 5x2 ChatGPT expression
## sheet layout), so the same base scale applies — just nudged down below
## Aurora's (2026-09-07) so she reads as "a bit smaller than Aurora" per
## [[lycith_character_concept]], same ~0.85x ratio the old full-body scales
## used (0.85/1.0) before the bust-portrait switch.
const LYCITH_PORTRAIT_SCALE := 0.55

## Portrait name -> file, for Aurora specifically. Pick one per line with
## Dialogic's "Name (portrait): text" syntax, e.g. "Aurora (mad): Kessa...".
## Lives in its own subfolder (assets/placeholder/portraits/aurora/) rather
## than flat in PORTRAIT_DIR — 2026-09-07 reorg, requested once there were 10
## expressions per character (20 files total between her and Lycith) making
## the flat portraits folder hard to search. Only the two named characters
## with real per-expression art got subfolders; ROSTER's single-portrait
## characters (Kessa, Elyn, enemies) stay flat in PORTRAIT_DIR — a single
## file per character isn't the thing that was hard to find.
const AURORA_PORTRAITS := {
	"neutral": "aurora/neutral.png",
	"happy": "aurora/happy.png",
	"sad": "aurora/sad.png",
	"mad": "aurora/mad.png",
	"shock": "aurora/shock.png",
	"laugh": "aurora/laugh.png",
	"stern": "aurora/stern.png",
	"talk": "aurora/talk.png",
	"embarrassed": "aurora/embarrassed.png",
	"pensive": "aurora/pensive.png",
}

## Martin portrait name -> file, same pattern as AURORA_PORTRAITS/
## LYCITH_PORTRAITS. Cropped 2026-09-07 from a 5x2 ChatGPT expression sheet
## that had no black divider bars (unlike Aurora/Lycith's later sheets) — the
## gaps between panels were still wide/clean enough for a precise pixel-scan
## crop (confirmed no bleed on any of the 10 expressions before shipping).
const MARTIN_PORTRAITS := {
	"neutral": "martin/neutral.png",
	"happy": "martin/happy.png",
	"sad": "martin/sad.png",
	"mad": "martin/mad.png",
	"shock": "martin/shock.png",
	"laugh": "martin/laugh.png",
	"stern": "martin/stern.png",
	"talk": "martin/talk.png",
	"embarrassed": "martin/embarrassed.png",
	"pensive": "martin/pensive.png",
}

## 2026-09-08: briefly bumped to 1.0 as a diagnostic (confirmed scale DOES
## apply correctly — he visibly got bigger). Real bug found separately: his
## 5 bottom-row expression files each had ~8-9 rows of near-invisible
## (alpha≈10/255) ghost pixels below the real content — invisible to the eye
## but very much "real content" to a naive alpha>0 bbox crop, so Dialogic's
## bottom-anchor (which uses the whole file's own canvas, not a re-cropped
## bbox) was anchoring off empty dead space instead of his actual hand/book.
## The 5 top-row files had zero such ghosting. Recropped all 10 with an
## alpha<30 cutoff before computing the bbox. Back to 0.65 now that the real
## fix is in — retest before assuming this exact number is final.
const MARTIN_PORTRAIT_SCALE := 0.65

## All names render in black now that the name label has its own readable
## panel behind it (Kenney ui-pack-pixel-adventure), rather than one color
## per character.
const NAME_COLOR := Color(0, 0, 0, 1)

## The ROSTER portraits are 32x32 battle-map tokens, never meant to be
## blown up to fill a VN portrait's full container height (which is what
## happens at scale 1.0 — a blocky giant circle). Aurora has real portrait
## art so she keeps the default 1.0.
const PLACEHOLDER_PORTRAIT_SCALE := 0.35

## Dialogic's VN portrait containers scale-to-fit the container HEIGHT
## (FIT_SCALE_HEIGHT mode): rendered_height = container_height * character
## scale, with width following the source image's aspect ratio. Container
## height is the full 720px viewport height, so the old full-body art
## (1024x1536, content ~93% of canvas) needed scale 1.0 just to read as
## normal human proportions on screen (720px tall = the full screen height),
## rendering ~480-540px wide — wide enough that "center"'s slot had to be
## widened to 640px (see vn_portrait_layer_tactical.tscn) to keep her out of
## her neighbors' slots.
##
## 2026-09-06: switched to bust (chest-up) portraits (324x486 canvas, cropped
## from a ChatGPT-generated 5x2 expression sheet) — a full-screen-height bust
## would be absurd (a giant floating face), so this needs a much smaller
## scale than the old full-body 1.0. Went through several corrections against
## real screenshots (this sandbox can't launch the game itself — `--headless`
## only has the dummy renderer, null viewport texture; a real/windowed
## display driver segfaults, no window station available here) before
## landing on the real fix:
## 1) 0.62 (Python mock, no screenshot yet) read as "way too low" in-engine.
## 2) Recalibrated to 0.85 against a real screenshot's textbox-top — better
##    filled, but then: too big, AND "on vois pas en dessous des épaules"
##    (chest/armor hidden behind the textbox) despite visible spare room
##    above. Root cause: both portrait containers are bottom-anchored to the
##    FULL 720px container height, same as the textbox's own bottom, so the
##    bottom ~28% of every bust (all the chest/emblem detail) rendered
##    *behind* the opaque textbox by construction. Scale alone can only trade
##    "hidden chest" for "empty headroom," never fix both.
## 3) Tried `origin_offset = Vector2(0, -147)` on the containers to shift the
##    bottom-anchor point up — verified this deserializes correctly in
##    isolation, but the *live* game still showed offset=(0,0) (confirmed via
##    a temporary debug dump of the actual runtime node — see git history).
##    Root cause: Dialogic creates a fresh per-character container for each
##    joined character by copying the template's settings
##    (`subsystem_containers.gd`'s `copy_container_setup()`) — and that
##    function copies `anchor_*`/`offset_*`/`size_mode`/`origin_anchor` but
##    NOT `origin_offset`. Setting it on the template scene is silently
##    thrown away for every actual joined character. This looks like a real
##    gap in the Dialogic addon, not something fixable from project code.
## Real fix: set `offset_bottom = -147.0` on the "left"/"center" containers
## instead (alongside the existing `anchor_bottom = 1.0`) — `offset_bottom`
## IS in `copy_container_setup()`'s copied list, confirmed by simulating that
## exact copy in an isolated script. This shrinks the container's own height
## to 720-147=573 (bottom edge pinned at the textbox's top, per
## `box_size`/`box_margin_bottom` in tactical_vn_style.tres: 150px box +
## 0 margin = textbox top at 720-150=570, matching the ~573-581 measured
## across several screenshots), so `FIT_SCALE_HEIGHT`'s formula becomes
## `rendered_height = 573 * character_scale` instead of `720 * character_scale`.
##
## 2026-09-06 (again): the source sheets got regenerated a second time with
## visible black divider bars between cells (so slicing could go by the
## divider instead of guessing where hair ends), which fixed real
## bleed/misalignment bugs — but also changed the canvas from a tall
## 324x486 crop (6-15% empty headroom above the hair on most expressions) to
## a much squarer, fully tight 378x371 one (0% padding on every side, every
## expression's content now touches all 4 edges). Since `rendered_height`
## only depends on container height and scale (not the source image's own
## proportions), the OLD scale (0.90, picked against the 324x486 canvas)
## produced the same 515px render height as before — but because the new
## canvas is proportionally much wider relative to its height, that same
## height now maps to a much wider render (~524px, versus ~344px before),
## overflowing badly past Lycith's 384px-wide "left" container and crowding
## Aurora's 563px "center" one. Width (not height) is the binding constraint
## now, so this was retuned against the container WIDTHS instead: at 0.65,
## rendered width comes out to ~380px for both (same aspect ratio canvas),
## which clears Lycith's tighter 384px container with a little margin and
## sits comfortably inside Aurora's — verified with the same Python mock
## technique (paste the actual shipped PNGs into a to-scale 1280x720 layout)
## since this sandbox still can't launch the real game to check directly.
## If the source art changes crop proportions again, re-derive from the
## container width, not just the old height-based number — the two stopped
## agreeing once the canvas aspect ratio changed this much.
const AURORA_PORTRAIT_SCALE := 0.65

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

	var lycith := DialogicCharacter.new()
	lycith.display_name = "Lycith"
	lycith.color = NAME_COLOR
	lycith.scale = LYCITH_PORTRAIT_SCALE
	# She always joins at "left" (see every .dtl timeline) — mirrored so she
	# faces right/inward toward whoever's in "center", instead of the source
	# art's default left-facing pose (which would have her looking away from
	# the conversation). Tried `mirrored = true` on the container node first,
	# but that hits the exact same bug as origin_offset (see
	# AURORA_PORTRAIT_SCALE's comment): copy_container_setup() doesn't copy
	# it either, so it's silently lost for real joined characters. `mirror`
	# on the DialogicCharacter resource itself isn't subject to that bug —
	# it's read directly off the character, not off a duplicated container.
	# If she ever joins somewhere other than "left" this would need revisiting.
	lycith.mirror = true
	for portrait_name in LYCITH_PORTRAITS:
		lycith.add_portrait(portrait_name, PORTRAIT_DIR + LYCITH_PORTRAITS[portrait_name])
	lycith.default_portrait = "neutral"
	directory["Lycith"] = lycith

	var martin := DialogicCharacter.new()
	martin.display_name = "Martin"
	martin.color = NAME_COLOR
	martin.scale = MARTIN_PORTRAIT_SCALE
	# No mirror needed regardless of which side he ends up joining — unlike
	# Aurora/Lycith's side-on art, his portrait is front-facing by design
	# (see martin_character_concept), so there's no "looking the wrong way"
	# to correct for.
	for portrait_name in MARTIN_PORTRAITS:
		martin.add_portrait(portrait_name, PORTRAIT_DIR + MARTIN_PORTRAITS[portrait_name])
	martin.default_portrait = "neutral"
	directory["Martin"] = martin

	Engine.set_meta("dch_directory", directory)
	_registered = true

## How long a character's first-ever appearance fade-in takes. Longer than
## SPEAKER_DIM_DURATION (the ongoing speaking/not-speaking dim tween) since
## this is a one-time "entrance," not a quick per-line highlight change.
const APPEARANCE_FADE_DURATION := 0.4

## Characters (by Dialogic identifier) that have already done their
## first-appearance fade-in this timeline. Reset per timeline via
## reset_appearance_tracking() — each new .dtl starts everyone hidden again,
## since `join` in a timeline always follows a `leave --All--` that cleared
## the previous scene's portraits.
static var _appeared: Dictionary = {}

## Call once before Dialogic.start() for each new timeline (CampaignFlow
## does this in _play_dialogue) so newly-joined characters fade in on their
## first line again, rather than staying "already seen" from a previous
## timeline in the same playthrough.
static func reset_appearance_tracking() -> void:
	_appeared.clear()

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
	# `join_default` is "Instant In" (project.godot) — characters would
	# otherwise appear immediately at full opacity the moment they join,
	# before they've said anything. Hiding them here and fading in on their
	# first line (below) is what makes "fade in when they enter the
	# conversation" mean "when they first speak," not "when the join event
	# in the timeline happens to run" — those aren't the same moment
	# whenever a scene joins several characters up front before anyone talks
	# (every .dtl in this project does exactly that).
	Dialogic.Portraits.character_joined.connect(_on_character_joined)
	_dimming_connected = true

static func _on_character_joined(info: Dictionary) -> void:
	var character: DialogicCharacter = info.get("character")
	if character == null or _appeared.get(character.get_identifier(), false):
		return
	var node := Dialogic.Portraits.get_character_node(character)
	if is_instance_valid(node):
		node.modulate.a = 0.0

static func _on_speaker_updated(speaker: DialogicCharacter) -> void:
	for character in Dialogic.Portraits.get_joined_characters():
		var node := Dialogic.Portraits.get_character_node(character)
		if not is_instance_valid(node):
			continue
		var speaking := character == speaker
		var has_appeared: bool = _appeared.get(character.get_identifier(), false)
		if not speaking and not has_appeared:
			# Joined but hasn't spoken yet — stays hidden (set to alpha 0 by
			# _on_character_joined) rather than being dimmed-but-visible.
			continue
		var first_appearance := speaking and not has_appeared
		if first_appearance:
			_appeared[character.get_identifier()] = true
		var target_modulate := SPEAKING_MODULATE if speaking else NOT_SPEAKING_MODULATE
		var target_scale := SPEAKING_SCALE if speaking else NOT_SPEAKING_SCALE
		var duration := APPEARANCE_FADE_DURATION if first_appearance else SPEAKER_DIM_DURATION
		var tween := node.create_tween().set_parallel(true)
		tween.tween_property(node, "modulate", target_modulate, duration)
		tween.tween_property(node, "scale", Vector2.ONE * target_scale, duration)
