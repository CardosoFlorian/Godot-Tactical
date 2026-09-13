class_name VexBattleSprite
extends Node2D
## Bandit (axe) battle sprite — same flipbook pattern as Aurora/Lycith/
## Martin/Kessa. Idle loops from assets/units/vex/idle/ (13 frames), attack
## plays once from assets/units/vex/attack/ (14 frames — one big overhead
## axe chop). Real idle+attack art replaced the original single-pose
## reference the same day it was integrated — see bandit_enemy_designs
## memory for why the scale/offset numbers below don't match that first,
## now-obsolete single-pose version.

const IDLE_FRAME_DIR := "res://assets/units/vex/idle/"
const IDLE_FRAME_COUNT := 13
const IDLE_FPS := 8.0

const ATTACK_FRAME_DIR := "res://assets/units/vex/attack/"
const ATTACK_FRAME_COUNT := 14
const ATTACK_FPS := 14.0  # tune here if the chop reads as too fast/slow

## 0-based frame index where the axe actually connects — found by eye from
## a montage of all 14 frames: 0-3 is wind-up (axe raised higher each
## frame), 4-5 continue the downswing, 6 is the swing itself (a motion-blur
## arc, the axe head no longer drawn separately — this IS the contact
## moment, same signature as every other rig's own contact frame), 7-13 is
## recovery/follow-through settling back toward the ready stance.
const ATTACK_CONTACT_FRAME_INDEX := 6

signal attack_finished
signal attack_contact

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

var _contact_emitted_this_attack := false

## Shared across every Bandit on screen — same rebuild-cost rationale as
## every other rig's cache (see spriteframes_rebuild_perf_trap memory).
static var _idle_frames_cache: SpriteFrames
static var _attack_frames_cache: SpriteFrames

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

## Awaits the full swing before returning, same contract every other rig's
## play_attack() has. Accepts and ignores target_global_pos/did_hit/weapon/
## did_crit — a melee swing has no projectile and no separate crit
## presentation of its own (Battle._play_crit_portrait already handles the
## crit cut-in before this ever plays, same as Aurora/Lycith/Kessa's axe).
func play_attack(_target_global_pos: Vector2 = Vector2.ZERO, _did_hit: bool = true, _weapon: WeaponData = null, _did_crit: bool = false) -> void:
	_contact_emitted_this_attack = false
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## FIXED 2026-09-12: originally guessed `false` (axe-arm/weight lean read as
## facing left) purely from eyeballing the reference art — wrong. Real bug
## caught live in an actual playtest: he faced right by default (should be
## left, Unit.gd's universal spawn convention) AND never visibly turned
## when moving left (facing_left's default is already `true`, so if this
## flag disagrees with the art's true native direction, the flip math
## silently cancels out for THAT one direction and only turning the other
## way ever does anything — exactly what "regarde à droite de base et
## quand il se déplace à gauche il regarde encore à droite" describes).
## Confirmed by working the flip formula backwards from the observed
## behavior rather than re-eyeballing the art again: this must report
## `true` (art faces right) for facing_left's default of `true` to
## correctly mirror him to LEFT at spawn, matching every other unit.
func faces_right_by_default() -> bool:
	return true

func _build_idle_frames() -> void:
	if _idle_frames_cache == null:
		_idle_frames_cache = SpriteFrames.new()
		_idle_frames_cache.add_animation("idle")
		_idle_frames_cache.set_animation_speed("idle", IDLE_FPS)
		_idle_frames_cache.set_animation_loop("idle", true)
		for i in range(1, IDLE_FRAME_COUNT + 1):
			var path := "%sidle_%02d.png" % [IDLE_FRAME_DIR, i]
			_idle_frames_cache.add_frame("idle", load(path))
	_idle_sprite.sprite_frames = _idle_frames_cache

func _build_attack_frames() -> void:
	if _attack_frames_cache == null:
		_attack_frames_cache = SpriteFrames.new()
		_attack_frames_cache.add_animation("attack")
		_attack_frames_cache.set_animation_speed("attack", ATTACK_FPS)
		_attack_frames_cache.set_animation_loop("attack", false)
		for i in range(1, ATTACK_FRAME_COUNT + 1):
			var path := "%sattack_%02d.png" % [ATTACK_FRAME_DIR, i]
			_attack_frames_cache.add_frame("attack", load(path))
	_attack_sprite.sprite_frames = _attack_frames_cache
