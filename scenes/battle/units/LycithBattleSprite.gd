class_name LycithBattleSprite
extends Node2D
## Lycith's battle sprite: straight flipbooks of drawn frames (no cutout
## rig), same pattern as AuroraBattleSprite. Idle loops from
## assets/units/lycith/idle/, attack plays once from
## assets/units/lycith/attack/. Only one of IdleSprite/AttackSprite is ever
## visible at a time.

const IDLE_FRAME_DIR := "res://assets/units/lycith/idle/"
const IDLE_FRAME_COUNT := 14
const IDLE_FPS := 8.0  # tune here if the loop reads as too fast/slow

const ATTACK_FRAME_DIR := "res://assets/units/lycith/attack/"
const ATTACK_FRAME_COUNT := 15  # one more frame than Aurora's attack — this sheet came back 15, not 14
const ATTACK_FPS := 14.0  # tune here if the thrust reads as too fast/slow

signal attack_finished

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

func _ready() -> void:
	_build_idle_frames()
	_build_attack_frames()
	play_idle()

func play_idle() -> void:
	_attack_sprite.visible = false
	_idle_sprite.visible = true
	if _idle_sprite.animation != "idle" or not _idle_sprite.is_playing():
		_idle_sprite.play("idle")

## Awaits the full thrust before returning, same contract AuroraBattleSprite
## has — callers that sequence combat resolution on this rely on it.
func play_attack() -> void:
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## Unit.gd's _apply_facing() reads this to know whether to flip. Confirmed
## by the user in-game (2026-09-07): the first guess (false, from reading
## frame 1's head-tilt as "facing left") was backwards — moving right made
## her look left and vice versa, the exact sign-flip pattern of getting this
## one boolean wrong. Her native pose actually reads as facing right once
## judged by body/weapon-arm orientation rather than head tilt alone.
func faces_right_by_default() -> bool:
	return true

func _build_idle_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", IDLE_FPS)
	frames.set_animation_loop("idle", true)
	for i in range(1, IDLE_FRAME_COUNT + 1):
		var path := "%sidle_%02d.png" % [IDLE_FRAME_DIR, i]
		frames.add_frame("idle", load(path))
	_idle_sprite.sprite_frames = frames

func _build_attack_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("attack")
	frames.set_animation_speed("attack", ATTACK_FPS)
	frames.set_animation_loop("attack", false)
	for i in range(1, ATTACK_FRAME_COUNT + 1):
		var path := "%sattack_%02d.png" % [ATTACK_FRAME_DIR, i]
		frames.add_frame("attack", load(path))
	_attack_sprite.sprite_frames = frames
