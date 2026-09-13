class_name BanditSwordBattleSprite
extends Node2D
## Bandit (sword) battle sprite — same flipbook pattern as Aurora/Lycith/
## Martin/Kessa/the axe Bandit. Idle loops from
## assets/units/bandit_sword/idle/ (12 frames), attack plays once from
## assets/units/bandit_sword/attack/ (14 frames — a forward lunging sword
## slash). Real idle+attack art replaced the original single-pose reference
## the same day it was integrated — scale/offset recalculated from scratch
## against the real frames, not reused from that first placeholder pose
## (same lesson every character's rig has taught). Generic, reused
## "Bandit" archetype like the axe one (see enemy_naming_convention memory)
## — no personal name anywhere, `character_id` is literally "bandit_sword".

const IDLE_FRAME_DIR := "res://assets/units/bandit_sword/idle/"
const IDLE_FRAME_COUNT := 12
const IDLE_FPS := 8.0

const ATTACK_FRAME_DIR := "res://assets/units/bandit_sword/attack/"
const ATTACK_FRAME_COUNT := 14
const ATTACK_FPS := 16.0  # tune here if the lunge reads as too fast/slow

## 0-based frame index where the blade actually connects — found by eye
## from a montage of all 14 frames: 0-2 is wind-up (sword pulled back),
## frame 3 is the swing itself (a motion-blur arc sweeping through the
## frame, body fully extended into the lunge — the blade is no longer
## separately drawn, this IS the contact moment, same signature as every
## other rig's own contact frame), 4-13 is recovery/follow-through with the
## sword held up in various settling positions.
const ATTACK_CONTACT_FRAME_INDEX := 3

signal attack_finished
signal attack_contact

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

var _contact_emitted_this_attack := false

## Shared across every sword Bandit on screen — same rebuild-cost rationale
## as every other rig's cache (see spriteframes_rebuild_perf_trap memory).
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
## crit cut-in before this ever plays, same as the axe Bandit's own).
func play_attack(_target_global_pos: Vector2 = Vector2.ZERO, _did_hit: bool = true, _weapon: WeaponData = null, _did_crit: bool = false) -> void:
	_contact_emitted_this_attack = false
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## UNCONFIRMED against a real in-game screenshot — see this file's earlier
## history in bandit_enemy_designs memory: the axe Bandit's equivalent
## guess (same "weapon/weight lean" reading method) was live-caught as
## backwards. Set to `true` here by direct analogy with that corrected
## value, not by re-guessing from the art. If he spawns facing the wrong
## way or doesn't turn on movement, flip this exactly like the axe one's was.
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
