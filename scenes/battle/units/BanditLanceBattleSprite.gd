class_name BanditLanceBattleSprite
extends Node2D
## Bandit (lance) battle sprite — third Bandit variant, deliberately given a
## different silhouette/build from the axe brute and sword duelist (a lean,
## agile fighter, not heavily muscled — user's own call). Idle loops from
## assets/units/bandit_lance/idle/ (12 frames, braid/scarf motion), attack
## plays once from assets/units/bandit_lance/attack/ (14 frames — a lunging
## spear thrust). Shipped as delivered per the user's own call ("elle est
## très bien comme ça") even though the mid-swing frames read a bit more
## like an empty-hand reach than a clean weapon thrust — see
## bandit_enemy_designs memory for the two failed prompt rewrites attempted
## before this; not revisited further since the user is happy with the
## result.

const IDLE_FRAME_DIR := "res://assets/units/bandit_lance/idle/"
const IDLE_FRAME_COUNT := 12
const IDLE_FPS := 8.0

const ATTACK_FRAME_DIR := "res://assets/units/bandit_lance/attack/"
const ATTACK_FRAME_COUNT := 14
const ATTACK_FPS := 16.0  # tune here if the thrust reads as too fast/slow

## 0-based frame index where the spear actually connects — found by eye
## from a montage of all 14 frames: 0-7 is wind-up (spear drawn back over
## her shoulder), 8-11 is an odd reach where the weapon momentarily trails
## behind her extended hand, 12 is the real payoff — spear gripped
## two-handed and driven fully forward, tip extending off-frame, unlike any
## other frame. 13 is recovery back to the ready stance.
const ATTACK_CONTACT_FRAME_INDEX := 12

signal attack_finished
signal attack_contact

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

var _contact_emitted_this_attack := false

## Shared across every lance Bandit on screen — same rebuild-cost
## rationale as every other rig's cache (see spriteframes_rebuild_perf_trap
## memory).
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
## crit cut-in before this ever plays, same as the other two Bandits).
func play_attack(_target_global_pos: Vector2 = Vector2.ZERO, _did_hit: bool = true, _weapon: WeaponData = null, _did_crit: bool = false) -> void:
	_contact_emitted_this_attack = false
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## UNCONFIRMED against a real in-game screenshot — see bandit_enemy_designs
## memory: the axe Bandit's equivalent guess (same "weapon/weight lean"
## reading method) was live-caught as backwards. Set to `true` here by
## direct analogy with both other Bandits' corrected value, not by
## re-guessing from the art. If she spawns facing the wrong way or doesn't
## turn on movement, flip this exactly like the other two's were.
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
