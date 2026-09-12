class_name LevelUpScreen
extends Control
## Classic Fire Emblem "stat up!" reveal — shown once per level actually
## gained (see UnitData.gain_exp, which returns one result dict per level;
## Battle.gd awaits this once per entry in sequence for a multi-level-up,
## rather than folding straight to the end result). Blocks battle input
## while up (default Control mouse_filter STOP on the dim background is
## deliberate here, unlike the informational panels elsewhere in this
## project that explicitly opt OUT of blocking — see
## combat_ui_click_blocking memory — this one is meant to be modal).
##
## 2026-09-10: staged into a real sequence rather than one instant reveal,
## per the user's own description of how real Fire Emblem plays it out:
## 1) a "LEVEL UP !" banner alone (now with a pop/flash, not just static
## text — user found the plain version "un peu triste"), 2) the panel
## appears with a NEUTRAL portrait and the character's OLD stats, 3) each
## stat that actually rolled up reveals one at a time in order (not all at
## once), 4) finally the portrait swaps to a happy/sad reaction (see
## GOOD_LEVEL_UP_THRESHOLD) with a per-CHARACTER quote line (not a generic
## one — see QUOTE_HAPPY/QUOTE_SAD), and only then does Continue appear.
##
## Stats shown are the unit's raw base_X fields, not get_str()/etc.'s
## debuff-adjusted numbers — a level-up is about permanent growth, showing
## a temporarily-debuffed value here would be misleading.

## Indexed by character_id, same "look up an expression PNG by id" pattern
## Battle.CRIT_PORTRAIT_DATA already established for the crit cut-in.
const PORTRAIT_NEUTRAL := {
	"aurora": "res://assets/placeholder/portraits/aurora/neutral.png",
	"lycith": "res://assets/placeholder/portraits/lycith/neutral.png",
	"kessa": "res://assets/placeholder/portraits/kessa/neutral.png",
	"martin": "res://assets/placeholder/portraits/martin/neutral.png",
}
const PORTRAIT_HAPPY := {
	"aurora": "res://assets/placeholder/portraits/aurora/happy.png",
	"lycith": "res://assets/placeholder/portraits/lycith/happy.png",
	"kessa": "res://assets/placeholder/portraits/kessa/happy.png",
	"martin": "res://assets/placeholder/portraits/martin/happy.png",
}
const PORTRAIT_SAD := {
	"aurora": "res://assets/placeholder/portraits/aurora/sad.png",
	"lycith": "res://assets/placeholder/portraits/lycith/sad.png",
	"kessa": "res://assets/placeholder/portraits/kessa/sad.png",
	"martin": "res://assets/placeholder/portraits/martin/sad.png",
}
## User's own rule: 4+ stats gained this level reads as "l'entrainement
## porte ses fruits" (happy), 3 or fewer as "j'aurais pu faire mieux" (sad).
const GOOD_LEVEL_UP_THRESHOLD := 4

## Per-character, matching each one's established voice (see their own
## _character_concept memories) rather than one generic line for everyone:
## Aurora reads as the composed, determined princess-protagonist; Lycith is
## calm/disciplined/understated, shows devotion through duty not words;
## Kessa is brash/competitive/blunt (Caulifla-modeled, default expression
## is a smirk); Martin is ultra-formal/scholarly, never drops the polite
## register even talking to himself. Falls back to a generic line for any
## character_id not listed (shouldn't come up for the 4 playables, but
## keeps this from ever showing a blank line if a future unit is added
## before getting real lines written).
const QUOTE_HAPPY := {
	"aurora": "Avec cette nouvelle force, je sauverai mon royaume.",
	"lycith": "Aurora sera un peu mieux protégée, désormais.",
	"kessa": "Ha ! Personne ne pourra plus me suivre, maintenant !",
	"martin": "Il semblerait que mes recherches portent enfin leurs fruits.",
}
const QUOTE_SAD := {
	"aurora": "Ce n'est pas encore assez pour reprendre mon trône.",
	"lycith": "Je ne suis pas encore à la hauteur de mon serment.",
	"kessa": "Pff... mon père aurait fait mieux que ça.",
	"martin": "Je crains de devoir consulter davantage d'ouvrages sur le sujet.",
}
const QUOTE_HAPPY_FALLBACK := "L'entraînement porte ses fruits !"
const QUOTE_SAD_FALLBACK := "J'aurais pu faire mieux..."

const BANNER_POP_DURATION := 0.3
const BANNER_HOLD_DURATION := 0.5
const BANNER_FADE_DURATION := 0.2
## Toned down after live feedback ("le flash jaune est trop violent, il me
## détruit les yeux") — was 0.6 alpha over 0.08s, basically a strobe.
const FLASH_IN_DURATION := 0.15
const FLASH_OUT_DURATION := 0.5
const FLASH_ALPHA := 0.16

const STAT_REVEAL_DELAY := 0.25
const RESULT_PAUSE := 0.3

## Fixed reveal order — top-to-bottom of the stat grid.
const STAT_ORDER := ["hp", "str", "mag", "skl", "spd", "lck", "def", "res", "con"]
const STAT_PREFIXES := {
	"hp": "PV", "str": "Force", "mag": "Magie", "skl": "Technique",
	"spd": "Vitesse", "lck": "Chance", "def": "Defense", "res": "Resist.", "con": "Constit.",
}

const GAIN_COLOR := Color(0.4, 1.0, 0.4)
const NORMAL_COLOR := Color.WHITE

const SOUND_STAT_GAIN := preload("res://assets/audio/sfx/stat_point_gain.mp3")
const SOUND_BANNER := preload("res://assets/audio/sfx/level_up_jingle.mp3")

signal continue_pressed

@onready var stat_gain_sound: AudioStreamPlayer = $StatGainSound
@onready var banner_sound: AudioStreamPlayer = $BannerSound
@onready var banner_flash: ColorRect = $BannerFlash
@onready var banner: Label = $LevelUpBanner
@onready var center: CenterContainer = $Center
@onready var portrait_rect: TextureRect = $Center/Panel/Margin/VBox/HBox/PortraitRect
@onready var quote_label: Label = $Center/Panel/Margin/VBox/QuoteBox/QuoteMargin/QuoteLabel
@onready var name_level_label: Label = $Center/Panel/Margin/VBox/NameLevelLabel
@onready var stat_labels: Dictionary = {
	"hp": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatHp,
	"str": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatStr,
	"mag": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatMag,
	"skl": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatSkl,
	"spd": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatSpd,
	"lck": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatLck,
	"def": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatDef,
	"res": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatRes,
	"con": $Center/Panel/Margin/VBox/HBox/StatsVBox/Grid/StatCon,
}
@onready var continue_hint: Label = $Center/Panel/Margin/VBox/ContinueHint
@onready var technique_popup_center: CenterContainer = $TechniquePopupCenter
@onready var technique_name_label: Label = $TechniquePopupCenter/TechniquePopup/TechniqueMargin/TechniqueVBox/TechniqueNameLabel
@onready var technique_effect_label: Label = $TechniquePopupCenter/TechniquePopup/TechniqueMargin/TechniqueVBox/TechniqueEffectLabel

## Set true only during the final "waiting for the player" stage — a click
## anywhere on screen advances (replaced the old Continue button per the
## user's own call: "on peut faire simple et juste enlever le bouton et
## faire que c'est un clic sur l'écran qui fait continuer"). False the rest
## of the time so clicking during the staged reveal doesn't skip it early —
## that was never asked for, just the end-of-sequence wait.
var _accepting_continue_click := false

func _ready() -> void:
	hide()
	# Real bug caught in review while wiring the jingle: stat_gain_sound was
	# already calling .play() in stage 3 but never had its .stream assigned
	# anywhere, so it was firing silently this whole time. Both streams are
	# fixed constants, so a one-time assignment here is enough for either.
	stat_gain_sound.stream = SOUND_STAT_GAIN
	banner_sound.stream = SOUND_BANNER

## Every OTHER Control in this scene (.tscn) is explicitly `mouse_filter =
## IGNORE` — real bug caught live: Godot Controls default to STOP, so
## without this a click landing on the panel/portrait/any label never
## reached this root at all (only clicks on the empty dim background did).
## IGNORE on everything else lets every click fall through to here.
func _gui_input(event: InputEvent) -> void:
	if not _accepting_continue_click:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		continue_pressed.emit()

## `entry` is one of the dicts UnitData.gain_exp returns:
## {"level": int, "stat_gains": Dictionary[String,int], "technique": TechniqueData or null,
## "stat_values": Dictionary[String,int]}.
func show_level_up(unit_data: UnitData, entry: Dictionary) -> void:
	var stat_gains: Dictionary = entry["stat_gains"]
	# `entry["stat_values"]` — a snapshot taken AT THIS LEVEL, inside
	# gain_exp's own loop — NOT unit_data.base_X read live here, which would
	# already be sitting at the FINAL value of a multi-level grant by the
	# time this runs (see gain_exp's own doc for the real bug this fixed).
	var final_values: Dictionary = entry["stat_values"]

	# Stage 1: banner alone — panel/continue not shown yet. quote_label and
	# technique_label keep their fixed-size boxes reserved from the start
	# (see .tscn) with empty text, rather than toggling .visible, so the
	# portrait/stat columns never reflow/shift once real text lands there
	# (real bug caught live: they used to jump when a hidden sibling
	# suddenly took up layout space inside a SHRINK_CENTER container).
	continue_hint.text = ""
	_accepting_continue_click = false
	quote_label.text = ""
	technique_popup_center.visible = false
	technique_popup_center.modulate = Color(1, 1, 1, 1)
	center.visible = false
	show()
	await _play_banner()

	# Stage 2: panel appears — neutral portrait, OLD (pre-level) stat values.
	portrait_rect.texture = _load_portrait(PORTRAIT_NEUTRAL, unit_data.character_id)
	name_level_label.text = "%s — Niveau %d" % [unit_data.display_name, entry["level"]]
	for stat_key in STAT_ORDER:
		var old_value: int = final_values[stat_key] - (1 if stat_gains.has(stat_key) else 0)
		_set_stat_label(stat_key, old_value, false)
	center.visible = true

	# Stage 3: reveal each stat that actually rolled up, one at a time, in
	# order — only stats WITH a gain get a beat; the rest were already
	# showing their (unchanged) final value from stage 2.
	for stat_key in STAT_ORDER:
		if not stat_gains.has(stat_key):
			continue
		await get_tree().create_timer(STAT_REVEAL_DELAY).timeout
		_set_stat_label(stat_key, final_values[stat_key], true)
		stat_gain_sound.play()

	# Stage 4: technique popup (if any) — name + its real mechanical effect
	# (TechniqueData.get_effect_description(), the same auto-generated text
	# UnitsScreen's hover tooltip already uses), held until the player
	# clicks past it — a real gap the user flagged: a bare "Nouvelle
	# technique : X" line buried in the stat grid didn't say what it DOES,
	# and didn't feel like the distinct moment learning a technique should
	# be. Reuses the same click-anywhere/_accepting_continue_click gate the
	# final stage below uses — awaiting the same signal twice in one
	# coroutine is fine, each await resolves independently.
	var technique: TechniqueData = entry.get("technique")
	if technique:
		await get_tree().create_timer(STAT_REVEAL_DELAY).timeout
		technique_name_label.text = technique.display_name
		technique_effect_label.text = technique.get_effect_description()
		technique_popup_center.modulate = Color(1, 1, 1, 0)
		technique_popup_center.visible = true
		var popup_in := create_tween()
		popup_in.tween_property(technique_popup_center, "modulate:a", 1.0, 0.2)
		await popup_in.finished
		_accepting_continue_click = true
		await continue_pressed
		_accepting_continue_click = false
		var popup_out := create_tween()
		popup_out.tween_property(technique_popup_center, "modulate:a", 0.0, 0.15)
		await popup_out.finished
		technique_popup_center.visible = false

	# Then the reaction — portrait swaps to happy/sad and the character
	# "says" a line matching the outcome.
	await get_tree().create_timer(RESULT_PAUSE).timeout
	var is_good := stat_gains.size() >= GOOD_LEVEL_UP_THRESHOLD
	portrait_rect.texture = _load_portrait(PORTRAIT_HAPPY if is_good else PORTRAIT_SAD, unit_data.character_id)
	var quote_map := QUOTE_HAPPY if is_good else QUOTE_SAD
	var fallback := QUOTE_HAPPY_FALLBACK if is_good else QUOTE_SAD_FALLBACK
	quote_label.text = quote_map.get(unit_data.character_id, fallback)
	continue_hint.text = "Cliquez pour continuer"
	_accepting_continue_click = true

	await continue_pressed
	_accepting_continue_click = false
	hide()

## Punchy pop-in instead of the plain static text this had at first (user:
## "essaye d'étoffer un peu le screen 'level up!' c'est un peu triste là")
## — a quick bright flash behind the text, and the text itself scales in
## with an overshoot/bounce (TRANS_BACK) rather than just appearing.
func _play_banner() -> void:
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.4, 0.4)
	banner.pivot_offset = banner.size / 2.0
	banner.show()
	banner_sound.play()

	var flash_tween := create_tween()
	flash_tween.tween_property(banner_flash, "color:a", FLASH_ALPHA, FLASH_IN_DURATION)
	flash_tween.tween_property(banner_flash, "color:a", 0.0, FLASH_OUT_DURATION)

	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(banner, "scale", Vector2.ONE, BANNER_POP_DURATION)
	pop_tween.parallel().tween_property(banner, "modulate:a", 1.0, BANNER_POP_DURATION * 0.5)
	await pop_tween.finished

	await get_tree().create_timer(BANNER_HOLD_DURATION).timeout

	var out_tween := create_tween()
	out_tween.tween_property(banner, "modulate:a", 0.0, BANNER_FADE_DURATION)
	await out_tween.finished
	banner.hide()
	banner.scale = Vector2.ONE
	banner.modulate = Color(1, 1, 1, 1)

func _set_stat_label(stat_key: String, value: int, gained: bool) -> void:
	var label: Label = stat_labels[stat_key]
	label.text = "%s %d%s" % [STAT_PREFIXES[stat_key], value, " +1" if gained else ""]
	label.add_theme_color_override("font_color", GAIN_COLOR if gained else NORMAL_COLOR)

func _load_portrait(portrait_map: Dictionary, character_id: String) -> Texture2D:
	var path: String = portrait_map.get(character_id, "")
	return load(path) if path != "" else null
