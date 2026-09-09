class_name ImpactEffect
extends Node2D
## One-shot hit VFX: a small burst animation + a sound, both chosen by the
## weapon type that landed the blow, then frees itself. Purely cosmetic —
## callers (Battle.gd for melee, Projectile.gd for ranged) fire-and-forget
## this the moment a hit actually lands; a miss should never call it.
##
## Burst frames come from a user-supplied "RPG Effect" pack (each source
## PNG is a 9-color-variant x N-frame grid — see the memory doc for exactly
## which file/row this was cropped from): the white/grey row for physical
## hits, the orange row of an 11-frame star/pinwheel burst for magic
## (swapped 2026-09-08 for a brighter, more dynamic one — the first pick,
## a flat circular burst, read as too plain/monochrome). Cropped once into
## assets/vfx/impact_{magic,physical}/, no per-call recoloring.
##
## Critical hits (2026-09-09) get their own look, INDEPENDENT of weapon
## type — a red variant of a chunkier "explosion condensing" burst (same
## pack, red row instead of white/grey), used for every crit regardless of
## melee/bow/tome. Deliberately weapon-agnostic, same reasoning as the miss
## sound: the point of a crit effect is "instantly readable as a crit," not
## "a bigger version of this weapon's normal hit" — a per-weapon crit color
## would blur that signal exactly when it matters most. `is_crit` overrides
## weapon-type selection entirely when true.

## 2026-09-08: swapped from Kenney's realistic foley (impactMetal/Wood/Bell)
## to ElevenLabs-generated retro 8-bit/chiptune one-shots — the realistic
## recordings clashed with the pixel-art style. "Metallic" was dropped from
## the melee prompt after early tests came back sounding "bizarre"; the bow
## prompt's "dull wooden thwack" was swapped to "sharp punchy...strong and
## loud" after the first pass came back too quiet. All 4 generated sounds
## (this file's 3 impact ones plus MartinBattleSprite's cast_fire) came back
## exactly 1.0s — a fixed default duration for ElevenLabs' one-shot SFX
## mode, not something tuned per-sound.
const SOUND_MELEE := preload("res://assets/audio/sfx/hit_melee.mp3")
const SOUND_BOW := preload("res://assets/audio/sfx/hit_bow.mp3")
const SOUND_MAGIC := preload("res://assets/audio/sfx/hit_fire.mp3")
const SOUND_CRIT := preload("res://assets/audio/sfx/hit_crit.mp3")

const MAGIC_FRAME_DIR := "res://assets/vfx/impact_magic/"
const MAGIC_FRAME_PREFIX := "impact_magic"
const MAGIC_FRAME_COUNT := 11
const MAGIC_FPS := 22.0
const MAGIC_SCALE := 0.9  # bigger than physical — meant to read as more impressive

const PHYSICAL_FRAME_DIR := "res://assets/vfx/impact_physical/"
const PHYSICAL_FRAME_PREFIX := "impact_physical"
const PHYSICAL_FRAME_COUNT := 9
const PHYSICAL_FPS := 24.0
const PHYSICAL_SCALE := 0.6

const CRIT_FRAME_DIR := "res://assets/vfx/impact_crit/"
const CRIT_FRAME_PREFIX := "impact_crit"
const CRIT_FRAME_COUNT := 10
## Slower than physical/magic on purpose (10fps vs 22-24fps): this burst
## plays out mostly WHILE Battle._play_crit_hitstop has time_scale dipped,
## which shrinks its effective on-screen speed too (AnimatedSprite2D has no
## per-node way to ignore Engine.time_scale, unlike Tween). At 20fps (the
## first-pass value) it read as "barely visible, already over" — most of
## the animation played in the tiny sliver of real time the slowdown lasts,
## then the last couple frames snapped through at full speed once time_scale
## reset. 10fps roughly doubles the total frame-time budget, giving it a
## real chance to read during the freeze instead of racing through it.
const CRIT_FPS := 10.0
const CRIT_SCALE := 0.8  # biggest of the three but not by much — 1.1 (first pass) read as too big

@onready var _burst: AnimatedSprite2D = $BurstSprite
@onready var _sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

## `weapon` may be null (unarmed) — falls back to the metal/physical look
## rather than erroring, since a punch landing still deserves some feedback.
## `is_crit` overrides weapon-type selection entirely (see the class doc
## comment) — a crit always gets the red burst + crit sound, never the
## weapon-typed one, regardless of what `weapon` is.
func play(weapon: WeaponData, is_crit: bool = false) -> void:
	var weapon_type := weapon.weapon_type if weapon else WeaponData.WeaponType.SWORD
	var is_magic := weapon_type == WeaponData.WeaponType.TOME
	if is_crit:
		_sound.stream = SOUND_CRIT
	else:
		match weapon_type:
			WeaponData.WeaponType.TOME:
				_sound.stream = SOUND_MAGIC
			WeaponData.WeaponType.BOW:
				_sound.stream = SOUND_BOW
			_:
				_sound.stream = SOUND_MELEE
	_burst.scale = Vector2.ONE * (CRIT_SCALE if is_crit else (MAGIC_SCALE if is_magic else PHYSICAL_SCALE))
	_build_burst_frames(is_crit, is_magic)
	_sound.play()
	_burst.play("burst")
	await _burst.animation_finished
	# Hide the burst the instant its animation ends rather than waiting for
	# the sound too — every SOUND_* is a fixed 1.0s (see the const comments
	# above) but the burst animations are shorter (~0.5s for magic), so
	# without this the burst's last frame would sit frozen and visible for
	# the remaining gap (read as a stuck residue, not silence — the node was
	# still there, just not animating).
	_burst.visible = false
	if _sound.playing:
		await _sound.finished
	queue_free()

func _build_burst_frames(is_crit: bool, is_magic: bool) -> void:
	var dir := CRIT_FRAME_DIR if is_crit else (MAGIC_FRAME_DIR if is_magic else PHYSICAL_FRAME_DIR)
	var prefix := CRIT_FRAME_PREFIX if is_crit else (MAGIC_FRAME_PREFIX if is_magic else PHYSICAL_FRAME_PREFIX)
	var count := CRIT_FRAME_COUNT if is_crit else (MAGIC_FRAME_COUNT if is_magic else PHYSICAL_FRAME_COUNT)
	var fps := CRIT_FPS if is_crit else (MAGIC_FPS if is_magic else PHYSICAL_FPS)

	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_speed("burst", fps)
	frames.set_animation_loop("burst", false)
	for i in range(1, count + 1):
		var path := "%s%s_%02d.png" % [dir, prefix, i]
		frames.add_frame("burst", load(path))
	_burst.sprite_frames = frames
