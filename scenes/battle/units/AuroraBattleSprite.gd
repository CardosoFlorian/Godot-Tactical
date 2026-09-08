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

## 0-based AnimatedSprite2D frame index where the blade actually connects —
## found by eye from a montage of all 14 frames: 0-6 is wind-up (sword
## raising), 7-8 is the actual downward slash (motion-blur arc), 9-13 is
## follow-through/recovery. Battle.gd listens for `attack_contact` (emitted
## here) to play the hit VFX/SFX right as the blade lands, instead of only
## after the whole swing — including recovery — has finished playing.
const ATTACK_CONTACT_FRAME_INDEX := 7

signal attack_finished
signal attack_contact

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

var _contact_emitted_this_attack := false

func _ready() -> void:
	_build_idle_frames()
	_build_attack_frames()
	_attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	play_idle()

func _on_attack_frame_changed() -> void:
	if _contact_emitted_this_attack or not _attack_sprite.visible:
		return
	if _attack_sprite.frame >= ATTACK_CONTACT_FRAME_INDEX:
		_contact_emitted_this_attack = true
		attack_contact.emit()

func play_idle() -> void:
	_attack_sprite.visible = false
	_idle_sprite.visible = true
	if _idle_sprite.animation != "idle" or not _idle_sprite.is_playing():
		_idle_sprite.play("idle")

## Unlike Lycith's art, this sprite's native pose faces right — Unit.gd's
## _apply_facing() reads this to know whether to flip.
func faces_right_by_default() -> bool:
	return true

## Awaits the full swing before returning, same contract the old cutout-rig
## version had — callers that sequence combat resolution on this rely on it.
## Params are unused (melee, no projectile, Battle.gd plays the impact
## effect itself for a melee hit) — accepted only so
## Unit.play_attack_animation() can call every rig's play_attack() uniformly.
func play_attack(_target_global_pos: Vector2 = Vector2.ZERO, _did_hit: bool = true, _weapon: WeaponData = null) -> void:
	_contact_emitted_this_attack = false
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
