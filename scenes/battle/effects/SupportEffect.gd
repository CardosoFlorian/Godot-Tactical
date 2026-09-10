class_name SupportEffect
extends Node2D
## One-shot gauntlet-support VFX: reuses ImpactEffect's white/grey physical
## burst (assets/vfx/impact_physical/) rather than commissioning new art —
## it's a clean grayscale sheet, so a modulate tint recolors it cleanly.
## Freeze gets a cold blue tint (same color as the "Gelé" floating combat
## text — see Battle.execute_support); Knockback gets a warm sandy/tan
## "impact dust" tint. Both deliberately different from the untinted white
## this same sheet already plays for an ordinary landed hit, AND from
## impact_crit's baked-in red (that sheet's frames are red pixels, not
## grayscale-plus-tint, so reusing them here would have just looked like a
## crit — a real mistake caught before it shipped).
## 2026-09-10: Knockback originally reused this sheet completely untinted,
## which then looked pixel-identical to an ordinary hit — user's own catch
## ("l'effet du gant de repousse et de degat est le meme").
## Same runtime-built-SpriteFrames pattern as ImpactEffect/HealEffect.

const SOUND_FREEZE := preload("res://assets/audio/sfx/gauntlet_freeze.mp3")
const SOUND_KNOCKBACK := preload("res://assets/audio/sfx/gauntlet_knockback.mp3")

const FREEZE_TINT := Color(0.55, 0.85, 1.0)
const KNOCKBACK_TINT := Color(1.0, 0.75, 0.4)

const BURST_FRAME_DIR := "res://assets/vfx/impact_physical/"
const BURST_FRAME_PREFIX := "impact_physical"
const BURST_FRAME_COUNT := 9
const BURST_FPS := 24.0
const BURST_SCALE := 0.6

@onready var _burst: AnimatedSprite2D = $BurstSprite
@onready var _sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func play(effect: WeaponData.GauntletEffect) -> void:
	var is_freeze := effect == WeaponData.GauntletEffect.FREEZE
	_build_burst_frames()
	_burst.scale = Vector2.ONE * BURST_SCALE
	_burst.modulate = FREEZE_TINT if is_freeze else KNOCKBACK_TINT
	_sound.stream = SOUND_FREEZE if is_freeze else SOUND_KNOCKBACK
	_sound.play()
	_burst.play("burst")
	await _burst.animation_finished
	# Same reasoning as ImpactEffect/HealEffect: hide the burst the instant
	# its own animation ends rather than waiting for the sound too.
	_burst.visible = false
	if _sound.playing:
		await _sound.finished
	queue_free()

func _build_burst_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("burst")
	frames.set_animation_speed("burst", BURST_FPS)
	frames.set_animation_loop("burst", false)
	for i in range(1, BURST_FRAME_COUNT + 1):
		var path := "%s%s_%02d.png" % [BURST_FRAME_DIR, BURST_FRAME_PREFIX, i]
		frames.add_frame("burst", load(path))
	_burst.sprite_frames = frames
