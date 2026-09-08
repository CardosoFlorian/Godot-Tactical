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

@onready var _burst: AnimatedSprite2D = $BurstSprite
@onready var _sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

## `weapon` may be null (unarmed) — falls back to the metal/physical look
## rather than erroring, since a punch landing still deserves some feedback.
func play(weapon: WeaponData) -> void:
	var weapon_type := weapon.weapon_type if weapon else WeaponData.WeaponType.SWORD
	var is_magic := weapon_type == WeaponData.WeaponType.TOME
	match weapon_type:
		WeaponData.WeaponType.TOME:
			_sound.stream = SOUND_MAGIC
		WeaponData.WeaponType.BOW:
			_sound.stream = SOUND_BOW
		_:
			_sound.stream = SOUND_MELEE
	_burst.scale = Vector2.ONE * (MAGIC_SCALE if is_magic else PHYSICAL_SCALE)
	_build_burst_frames(is_magic)
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

func _build_burst_frames(is_magic: bool) -> void:
	var dir := MAGIC_FRAME_DIR if is_magic else PHYSICAL_FRAME_DIR
	var prefix := MAGIC_FRAME_PREFIX if is_magic else PHYSICAL_FRAME_PREFIX
	var count := MAGIC_FRAME_COUNT if is_magic else PHYSICAL_FRAME_COUNT
	var fps := MAGIC_FPS if is_magic else PHYSICAL_FPS

	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_speed("burst", fps)
	frames.set_animation_loop("burst", false)
	for i in range(1, count + 1):
		var path := "%s%s_%02d.png" % [dir, prefix, i]
		frames.add_frame("burst", load(path))
	_burst.sprite_frames = frames
