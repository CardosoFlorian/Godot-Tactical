class_name AuroraBattleSprite
extends Node2D
## Aurora's battle sprite: straight flipbooks of drawn frames (no cutout
## rig) — idle loops from assets/units/aurora/idle/, attack plays once from
## assets/units/aurora/attack/. Only one of IdleSprite/AttackSprite is ever
## visible at a time.

const IDLE_FRAME_DIR := "res://assets/units/aurora/idle/"
const IDLE_FRAME_COUNT := 14
const IDLE_FPS := 8.0  # tune here if the loop reads as too fast/slow

const ATTACK_FRAME_DIR := "res://assets/units/aurora/attack/"
const ATTACK_FRAME_COUNT := 14
const ATTACK_FPS := 14.0  # tune here if the swing reads as too fast/slow

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

## Awaits the full swing before returning, same contract the old cutout-rig
## version had — callers that sequence combat resolution on this rely on it.
func play_attack() -> void:
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

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
