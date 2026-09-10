class_name ExpGainOverlay
extends Control
## Big centered EXP bar that plays the actual fill animation after combat/
## heal/support XP is granted — replaces UnitInfoPanel's corner bar as the
## animation site (2026-09-10: user preferred the moving bar be center-
## screen and blue, not tucked in the small corner panel; the corner bar
## still exists as a static reference, just doesn't animate anymore).
##
## No dismiss button — this auto-plays and Battle.gd hides it once done
## (or right before handing off to LevelUpScreen for the stat reveal, on a
## level-up). Mirrors CombatStatsPanel.set_hp's tween_method-driven fill
## pattern.

const FILL_DURATION := 0.6

## User picked "Exp 2" out of 3 ElevenLabs candidates (2026-09-10).
const SOUND_FILL := preload("res://assets/audio/sfx/exp_bar_fill.mp3")

@onready var name_label: Label = $Center/Panel/VBox/NameLabel
@onready var bar: ProgressBar = $Center/Panel/VBox/Bar
@onready var bar_label: Label = $Center/Panel/VBox/Bar/BarLabel
@onready var fill_sound: AudioStreamPlayer = $FillSound

func _ready() -> void:
	hide()
	fill_sound.stream = SOUND_FILL

## Battle.gd calls this once per "segment" of a possibly-multi-level XP
## grant (see Battle._grant_exp_and_show_level_ups): fill toward 100, snap
## to 0 via set_immediate between levels, repeat, then one final fill for
## whatever's left after the last level. Sound plays once per segment,
## not synced frame-for-frame to the tween — same "not precisely
## synchronized, close enough" convention every other one-shot SFX in this
## project already follows.
func animate_fill(unit_data: UnitData, from_value: int, to_value: int) -> void:
	name_label.text = unit_data.display_name
	_set_display(from_value)
	show()
	if to_value > from_value:
		fill_sound.play()
	var tween := create_tween()
	tween.tween_method(_set_display, from_value, to_value, FILL_DURATION)
	await tween.finished

## Instant, no tween — the bar visually "resets" the instant it fills on a
## level-up, not a reverse drain.
func set_immediate(value: int) -> void:
	_set_display(value)

func hide_overlay() -> void:
	hide()

func _set_display(value: float) -> void:
	bar.value = value
	bar_label.text = "XP %d / 100" % roundi(value)
