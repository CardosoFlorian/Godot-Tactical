class_name KessaBattleSprite
extends Node2D
## Kessa's battle sprite: straight flipbook of drawn frames (no cutout rig),
## same pattern as Aurora/Lycith/Martin. Idle loops from
## assets/units/kessa/idle/ (16 frames), attack plays once from
## assets/units/kessa/attack/ (13 frames — one big overhead axe swing).
##
## Bow pose (added once Maîtrise Arc unlocked the weapon type — see
## upcoming_level_up_stats_system memory, "she'll swing her axe even with a
## bow equipped until a real animation is made") now has real idle AND
## attack animations (assets/units/kessa/bow/idle_01..16.png,
## assets/units/kessa/bow/attack/attack_01..16.png). The attack animation
## deliberately never draws the arrow leaving the bow — it just shows the
## arrow vanish at the release frame (BOW_ATTACK_CONTACT_FRAME_INDEX) — a
## real Projectile (see scenes/battle/effects/Projectile.gd, generalized
## from Martin's fireball-only version) is spawned right then and flies to
## the target on its own timeline, same "no double-effect" design as
## MartinBattleSprite. `set_unit_data()` gives this rig the one piece of
## external context it needs (which weapon is actually equipped) that
## Unit.gd doesn't otherwise pass into any rig — see `_wielding_bow()`.

const IDLE_FRAME_DIR := "res://assets/units/kessa/idle/"
const IDLE_FRAME_COUNT := 16
const IDLE_FPS := 8.0

const ATTACK_FRAME_DIR := "res://assets/units/kessa/attack/"
const ATTACK_FRAME_COUNT := 13
const ATTACK_FPS := 14.0  # tune here if the swing reads as too fast/slow

const BOW_IDLE_FRAME_DIR := "res://assets/units/kessa/bow/"
const BOW_IDLE_FRAME_COUNT := 16
const BOW_IDLE_FPS := 8.0

const BOW_ATTACK_FRAME_DIR := "res://assets/units/kessa/bow/attack/"
const BOW_ATTACK_FRAME_COUNT := 16
const BOW_ATTACK_FPS := 12.0  # tune here if the draw+release reads as too fast/slow

const PROJECTILE_SCENE := preload("res://scenes/battle/effects/Projectile.tscn")
const ARROW_FRAME_DIR := "res://assets/vfx/arrow/"
const ARROW_FRAME_PREFIX := "arrow"
const ARROW_FRAME_COUNT := 1  # single static sprite, no flame-trail-style loop needed

## Plays at the exact release frame, alongside the projectile spawn — the
## bowstring/shot sound, distinct from ImpactEffect's SOUND_BOW (which plays
## on the arrow's ARRIVAL instead, see Projectile.launch).
const SOUND_BOW_SHOOT := preload("res://assets/audio/sfx/bow_shoot.mp3")

## 0-based AnimatedSprite2D frame index where the arrow actually vanishes
## from the string (the release) — found the same "eyeball a frame montage"
## way as every other rig's contact/release frame: frames 0-9 hold the full
## draw with the arrow visible, frame 10 is the first one where it's gone
## (string mid-release, bow limbs starting to relax), 11-15 are
## recovery/follow-through with an empty bow.
const BOW_ATTACK_CONTACT_FRAME_INDEX := 10

## Offset (local pixels, same space AttackSprite's own offset/scale use)
## from her position to the arrow's nock point on the release frame — the
## REAL point the animation shows the shot leaving from. X and Y both
## derived exactly like Martin's HAND_OFFSET: sampled the arrowhead's pixel
## position in attack_10.png (~558, 231 on the 640x640 canvas, one frame
## before it vanishes) and ran it through the same
## (offset + pixel - canvas_center) * scale transform BowAttackSprite's own
## offset=(-17,-19)/scale=0.057 use.
##
## Two wrong attempts before landing here, both caught live by the user —
## neither touched this constant's value, they broke the SEPARATE question
## of what height to aim AT (see _spawn_projectile's own doc):
## 1. First aimed straight at Unit.get_impact_point() (chest height, a
##    DIFFERENT convention than this spawn point) — a same-ROW shot then
##    launched from a different height than it aimed at, picking up a real
##    upward tilt (~9°) purely from that mismatch, not from this offset
##    being wrong.
## 2. "Fixed" by flattening the FLIGHT itself instead (forcing the
##    destination's Y to always match the spawn's Y, ignoring the target's
##    real position) — broke vertical/diagonal shots instead: for an enemy
##    directly above/below, the target's X is ~equal to the spawn's X, so a
##    forced-flat line degenerates into a near-zero or wrong-sign
##    horizontal vector, which is what made the arrow snap back toward her
##    on an up/down attack instead of flying at the enemy.
## Real fix: keep this offset as the true measured spawn point, and instead
## re-derive the AIM point in _spawn_projectile using this SAME offset
## applied to the enemy's own tile center (not Unit.IMPACT_POINT_OFFSET,
## a different convention) — see there for the exact math. Same-row now
## comes out level because both ends share the SAME real offset, and a
## genuinely different-row shot still angles correctly toward where the
## enemy really is, including straight up/down.
const ARROW_SPAWN_OFFSET := Vector2(13, -6)

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
@onready var _bow_sprite: AnimatedSprite2D = $BowSprite
@onready var _bow_attack_sprite: AnimatedSprite2D = $BowAttackSprite
@onready var _bow_shoot_sound: AudioStreamPlayer2D = $BowShootSound

var _contact_emitted_this_attack := false
var _unit_data: UnitData

## Set by play_attack() right before playing the bow attack animation, read
## by _spawn_projectile() once the release frame is reached — same
## "_pending_*" pattern MartinBattleSprite uses for its own fireball.
var _pending_target: Vector2
var _pending_did_hit: bool = true
var _pending_weapon: WeaponData
var _pending_did_crit: bool = false
var _projectile_spawned_this_attack := false

## Built once per script (not per instance) and shared across every Kessa
## on screen — see AuroraBattleSprite's identical cache for why: rebuilding
## these from ~29 individual load() calls on EVERY instantiate() cost
## ~260ms per spawn, the real source of the "gros lag" on entering the prep
## camp AND again on pressing Combattre !.
static var _idle_frames_cache: SpriteFrames
static var _attack_frames_cache: SpriteFrames
static var _bow_idle_frames_cache: SpriteFrames
static var _bow_attack_frames_cache: SpriteFrames

func _ready() -> void:
	_build_idle_frames()
	_build_attack_frames()
	_build_bow_idle_frames()
	_build_bow_attack_frames()
	_bow_shoot_sound.stream = SOUND_BOW_SHOOT
	_attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	_bow_attack_sprite.frame_changed.connect(_on_bow_attack_frame_changed)
	play_idle()

## Only Unit.gd calls this (guarded by has_method, since no other rig needs
## it) — the one piece of external context this rig needs that the shared
## rig interface doesn't otherwise provide: which weapon is actually
## equipped, to pick the axe or bow pose. See _wielding_bow().
func set_unit_data(data: UnitData) -> void:
	_unit_data = data
	# _ready() already ran play_idle() once by the time Unit.gd calls this
	# (add_child triggers _ready synchronously), always defaulting to the
	# axe pose since _unit_data was still null then — re-run it now that the
	# real equipped weapon is known.
	play_idle()

func _wielding_bow() -> bool:
	if _unit_data == null:
		return false
	var weapon := _unit_data.get_equipped_weapon()
	return weapon != null and weapon.weapon_type == WeaponData.WeaponType.BOW

func _on_attack_frame_changed() -> void:
	if _contact_emitted_this_attack or not _attack_sprite.visible:
		return
	if _attack_sprite.frame >= ATTACK_CONTACT_FRAME_INDEX:
		_contact_emitted_this_attack = true
		attack_contact.emit()

func _on_bow_attack_frame_changed() -> void:
	if _projectile_spawned_this_attack or not _bow_attack_sprite.visible:
		return
	if _bow_attack_sprite.frame >= BOW_ATTACK_CONTACT_FRAME_INDEX:
		_projectile_spawned_this_attack = true
		_bow_shoot_sound.play()
		_spawn_projectile()

func play_idle() -> void:
	_attack_sprite.visible = false
	_bow_attack_sprite.visible = false
	if _wielding_bow():
		_idle_sprite.visible = false
		_bow_sprite.visible = true
		if _bow_sprite.animation != "bow_idle" or not _bow_sprite.is_playing():
			_bow_sprite.play("bow_idle")
		return
	_bow_sprite.visible = false
	_idle_sprite.visible = true
	if _idle_sprite.animation != "idle" or not _idle_sprite.is_playing():
		_idle_sprite.play("idle")

## Awaits the full swing/shot before returning, same contract every other
## rig's play_attack() has. `weapon` picks the axe swing or the bow shot —
## see _wielding_bow()/branch below. Battle.gd never listens for
## attack_contact on a ranged attack (see Battle._is_ranged's branch in
## _play_combat_scene) — the spawned Projectile's own arrival is what times
## the hit VFX/SFX instead, exactly like MartinBattleSprite's fireball, so
## the bow branch never emits attack_contact at all.
func play_attack(target_global_pos: Vector2 = Vector2.ZERO, did_hit: bool = true, weapon: WeaponData = null, did_crit: bool = false) -> void:
	_contact_emitted_this_attack = false
	if weapon != null and weapon.weapon_type == WeaponData.WeaponType.BOW:
		_pending_target = target_global_pos
		_pending_did_hit = did_hit
		_pending_weapon = weapon
		_pending_did_crit = did_crit
		_projectile_spawned_this_attack = false
		_idle_sprite.visible = false
		_attack_sprite.visible = false
		_bow_sprite.visible = false
		_bow_attack_sprite.visible = true
		_bow_attack_sprite.play("bow_attack")
		await _bow_attack_sprite.animation_finished
		attack_finished.emit()
		play_idle()
		return
	_idle_sprite.visible = false
	_bow_sprite.visible = false
	_attack_sprite.visible = true
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## Fire-and-forget, same shape as MartinBattleSprite._spawn_projectile —
## not awaited, since combat resolution is already timed off her own attack
## animation (play_attack's own await above), not the arrow's flight.
func _spawn_projectile() -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.frame_dir = ARROW_FRAME_DIR
	projectile.frame_prefix = ARROW_FRAME_PREFIX
	projectile.frame_count = ARROW_FRAME_COUNT
	# Added at the SceneTree root, not get_tree().current_scene — see
	# MartinBattleSprite._spawn_projectile's identical comment for why.
	get_tree().root.add_child(projectile)
	var offset := ARROW_SPAWN_OFFSET
	offset.x *= signf(scale.x)  # mirror the spawn point when facing left
	var from := global_position + offset
	# Aim at the enemy's own tile center shifted by the SAME ARROW_SPAWN_OFFSET.y
	# this rig's own spawn point uses — NOT _pending_target directly (that's
	# Unit.get_impact_point(), a DIFFERENT height convention, chest-height —
	# using it made a same-row shot launch and aim at two different heights,
	# a real tilt) and NOT a flattened line either (that broke vertical
	# shots — see ARROW_SPAWN_OFFSET's own doc for both wrong attempts).
	# _pending_target already has Unit.IMPACT_POINT_OFFSET.y baked in, so
	# subtracting it back out recovers the enemy's raw tile-center Y before
	# reapplying this rig's own offset.
	var enemy_tile_center_y := _pending_target.y - Unit.IMPACT_POINT_OFFSET.y
	var to := Vector2(_pending_target.x, enemy_tile_center_y + ARROW_SPAWN_OFFSET.y)
	projectile.launch(from, to, _pending_did_hit, _pending_weapon, _pending_did_crit)

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

func _build_bow_idle_frames() -> void:
	if _bow_idle_frames_cache == null:
		_bow_idle_frames_cache = SpriteFrames.new()
		_bow_idle_frames_cache.add_animation("bow_idle")
		_bow_idle_frames_cache.set_animation_speed("bow_idle", BOW_IDLE_FPS)
		_bow_idle_frames_cache.set_animation_loop("bow_idle", true)
		for i in range(1, BOW_IDLE_FRAME_COUNT + 1):
			var path := "%sidle_%02d.png" % [BOW_IDLE_FRAME_DIR, i]
			_bow_idle_frames_cache.add_frame("bow_idle", load(path))
	_bow_sprite.sprite_frames = _bow_idle_frames_cache

func _build_bow_attack_frames() -> void:
	if _bow_attack_frames_cache == null:
		_bow_attack_frames_cache = SpriteFrames.new()
		_bow_attack_frames_cache.add_animation("bow_attack")
		_bow_attack_frames_cache.set_animation_speed("bow_attack", BOW_ATTACK_FPS)
		_bow_attack_frames_cache.set_animation_loop("bow_attack", false)
		for i in range(1, BOW_ATTACK_FRAME_COUNT + 1):
			var path := "%sattack_%02d.png" % [BOW_ATTACK_FRAME_DIR, i]
			_bow_attack_frames_cache.add_frame("bow_attack", load(path))
	_bow_attack_sprite.sprite_frames = _bow_attack_frames_cache
