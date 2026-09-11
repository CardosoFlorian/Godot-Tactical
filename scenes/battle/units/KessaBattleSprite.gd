class_name KessaBattleSprite
extends Node2D
## Kessa's battle sprite: straight flipbook of drawn frames (no cutout rig),
## same pattern as Aurora/Lycith/Martin. Idle loops from
## assets/units/kessa/idle/ (16 frames), attack plays once from
## assets/units/kessa/attack/ (13 frames — one big overhead axe swing).

const IDLE_FRAME_DIR := "res://assets/units/kessa/idle/"
const IDLE_FRAME_COUNT := 16
const IDLE_FPS := 8.0

const ATTACK_FRAME_DIR := "res://assets/units/kessa/attack/"
const ATTACK_FRAME_COUNT := 13
const ATTACK_FPS := 14.0  # tune here if the swing reads as too fast/slow

## 0-based AnimatedSprite2D frame index where the axe actually connects —
## found by eye from a montage of all 13 frames: 0-3 is wind-up (axe pulled
## back over her shoulder), 4 is the swing itself (a motion-blur arc, the
## axe head no longer drawn separately — this IS the contact moment), 5-12
## is recovery/follow-through with the axe settled low in front. Same
## frame-synced pattern as Aurora/Lycith's own ATTACK_CONTACT_FRAME_INDEX.
const ATTACK_CONTACT_FRAME_INDEX := 4

signal attack_finished
signal attack_contact

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite

var _contact_emitted_this_attack := false

## Built once per script (not per instance) and shared across every Kessa
## on screen — see AuroraBattleSprite's identical cache for why: rebuilding
## these from ~29 individual load() calls on EVERY instantiate() cost
## ~260ms per spawn, the real source of the "gros lag" on entering the prep
## camp AND again on pressing Combattre !.
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
## play_attack() has. Params are unused (melee, no projectile — Battle.gd
## plays the impact effect itself off the attack_contact signal) — accepted
## only so Unit.play_attack_animation() can call every rig uniformly.
func play_attack(_target_global_pos: Vector2 = Vector2.ZERO, _did_hit: bool = true, _weapon: WeaponData = null, _did_crit: bool = false) -> void:
	_contact_emitted_this_attack = false
	_idle_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## Judged by body/weapon-arm orientation (same method used to fix Lycith's
## facing bug — see lycith_battle_sprite_idle): her stance leans onto her
## right leg with the axe swung out to the right, reading as facing right.
## Not yet confirmed against a real in-game screenshot.
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
