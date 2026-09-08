class_name HealEffect
extends Node2D
## One-shot heal VFX: a green sparkle burst on the healed unit, played once
## the cast animation finishes and the HP change actually lands (see
## Battle.execute_heal) — the "proc" moment, distinct from the charge sound
## MartinBattleSprite.play_heal() already plays at the start of the cast.
## Same runtime-built-SpriteFrames pattern as ImpactEffect.
##
## Burst frames: assets/vfx/heal_effect/heal_effect_01..11.png, cropped from
## the same source sheet as ImpactEffect's magic burst (Free/Part 27/1348.png)
## but the green row instead of orange — same star/pinwheel burst shape,
## reads as the "same effect family, different element" rather than an
## unrelated look.
##
## Proc sound: a soft rising chime, ElevenLabs one-shot SFX mode, same
## pipeline as every other sound in this project — deliberately gentle/no
## bass, the opposite feel of a damage impact.
const SOUND_HEAL := preload("res://assets/audio/sfx/heal_proc.mp3")

const BURST_FRAME_DIR := "res://assets/vfx/heal_effect/"
const BURST_FRAME_PREFIX := "heal_effect"
const BURST_FRAME_COUNT := 11
const BURST_FPS := 22.0
const BURST_SCALE := 0.9

@onready var _burst: AnimatedSprite2D = $BurstSprite
@onready var _sound: AudioStreamPlayer2D = $AudioStreamPlayer2D

func play() -> void:
	_build_burst_frames()
	_burst.scale = Vector2.ONE * BURST_SCALE
	_sound.stream = SOUND_HEAL
	_sound.play()
	_burst.play("burst")
	await _burst.animation_finished
	# Same reasoning as ImpactEffect: hide the burst the instant its own
	# animation ends rather than waiting for the sound too, so a longer sound
	# doesn't leave a frozen last frame visible as residue.
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
