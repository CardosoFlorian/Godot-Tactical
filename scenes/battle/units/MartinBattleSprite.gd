class_name MartinBattleSprite
extends Node2D
## Martin's battle sprite: straight flipbook of drawn frames (no cutout
## rig), same pattern as Aurora/LycithBattleSprite. Idle loops from
## assets/units/martin/idle/, attack from assets/units/martin/attack/ — a
## spellcast where his OTHER hand (not the one holding the book) channels a
## fireball, peaking in a bright flash at frame 14. A Projectile (see
## scenes/battle/effects/Projectile.gd) is spawned right at that flash frame
## and flies to the target on its own timeline — the character animation
## itself never draws the fireball actually leaving his hand, by design (see
## the attack prompt), so there's no double-effect once the projectile takes
## over.
##
## heal (assets/units/martin/heal/) is a separate cast animation for
## data/weapons/heal_tome.tres — same OTHER-hand-channels-magic idea but a
## green-gold glow instead of fire, played in place with no projectile (the
## heal itself is a direct instant HP change, see Battle.execute_heal).

const PROJECTILE_SCENE := preload("res://scenes/battle/effects/Projectile.tscn")

## Plays the instant a cast begins (wind-up), not at the release flash — a
## separate "charging up" sound distinct from the impact/proc sound that
## plays later once the spell actually lands (ImpactEffect.SOUND_MAGIC for
## the fireball, HealEffect's own sound for heal). Shared by every magic
## cast regardless of spell (fire attack AND heal both play this same
## charge-up) — the user's call: no separate per-spell charge sound for now,
## only the landing effect differs.
const SOUND_CAST := preload("res://assets/audio/sfx/cast_fire.mp3")

const IDLE_FRAME_DIR := "res://assets/units/martin/idle/"
const IDLE_FRAME_COUNT := 12  # sheet came back 12 frames, not the requested 14
const IDLE_FPS := 8.0  # tune here if the loop reads as too fast/slow

const ATTACK_FRAME_DIR := "res://assets/units/martin/attack/"
const ATTACK_FRAME_COUNT := 16  # requested 14, sheet came back 16 (needed for a readable cast)
const ATTACK_FPS := 12.0  # tune here if the cast reads as too fast/slow

const HEAL_FRAME_DIR := "res://assets/units/martin/heal/"
const HEAL_FRAME_COUNT := 16
const HEAL_FPS := 12.0  # tune here if the cast reads as too fast/slow

## 0-based AnimatedSprite2D frame index of attack_14.png — the brightest
## peak-flash frame, and the moment the projectile departs his palm. Frames
## after this just show the fireball settling/held, not fading — the
## projectile spawning here is what visually "removes" it from his hand.
const ATTACK_RELEASE_FRAME_INDEX := 13

## Offset (local pixels, in the same space AttackSprite's own offset/scale
## already use) from his position to where the fireball actually sits on
## the release frame. Derived, not guessed: sampled the flash's core pixel
## in attack_14.png at roughly (510, 210) on the 640x640 canvas, then ran it
## through the same (offset + pixel - canvas_center) * scale transform the
## AnimatedSprite2D itself uses (canvas_center=320, offset=(-2,-31),
## scale=0.079 — see AttackSprite in the .tscn). A first guess of (20,-40)
## was wildly too big — bigger than his whole ~38px-tall on-map body — which
## is why the fireball spawned nowhere near his hand.
const HAND_OFFSET := Vector2(15, -11)

signal attack_finished
signal heal_finished

@onready var _idle_sprite: AnimatedSprite2D = $IdleSprite
@onready var _attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var _heal_sprite: AnimatedSprite2D = $HealSprite
@onready var _cast_sound: AudioStreamPlayer2D = $CastSound

var _pending_target: Vector2
var _pending_did_hit: bool = true
var _pending_weapon: WeaponData
var _pending_did_crit: bool = false
var _projectile_spawned_this_attack := false

## Built once per script (not per instance) and shared across every Martin
## on screen — see AuroraBattleSprite's identical cache for why: rebuilding
## these from ~44 individual load() calls (idle+attack+heal combined) on
## EVERY instantiate() cost ~370ms per spawn, the real source of the "gros
## lag" on entering the prep camp AND again on pressing Combattre !.
static var _idle_frames_cache: SpriteFrames
static var _attack_frames_cache: SpriteFrames
static var _heal_frames_cache: SpriteFrames

func _ready() -> void:
	_build_idle_frames()
	_build_attack_frames()
	_build_heal_frames()
	_attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	play_idle()

func play_idle() -> void:
	_attack_sprite.visible = false
	_heal_sprite.visible = false
	_idle_sprite.visible = true
	if _idle_sprite.animation != "idle" or not _idle_sprite.is_playing():
		_idle_sprite.play("idle")

## Awaits the full cast before returning, same contract Aurora/Lycith's
## melee swings have — callers that sequence combat resolution rely on it.
## The projectile itself is fire-and-forget (see _on_attack_frame_changed),
## not part of what's being awaited here.
func play_attack(target_global_pos: Vector2 = Vector2.ZERO, did_hit: bool = true, weapon: WeaponData = null, did_crit: bool = false) -> void:
	_pending_target = target_global_pos
	_pending_did_hit = did_hit
	_pending_weapon = weapon
	_pending_did_crit = did_crit
	_projectile_spawned_this_attack = false
	_idle_sprite.visible = false
	_heal_sprite.visible = false
	_attack_sprite.visible = true
	_cast_sound.stream = SOUND_CAST
	_cast_sound.play()
	_attack_sprite.play("attack")
	await _attack_sprite.animation_finished
	attack_finished.emit()
	play_idle()

## Plays the heal cast in place (no target position, no projectile — the
## heal is applied directly by Battle.execute_heal once this returns, same
## "no combat-scene staging" first pass the heal action itself uses).
## Awaits the full cast, same contract play_attack() has.
func play_heal() -> void:
	_idle_sprite.visible = false
	_attack_sprite.visible = false
	_heal_sprite.visible = true
	_cast_sound.stream = SOUND_CAST
	_cast_sound.play()
	_heal_sprite.play("heal")
	await _heal_sprite.animation_finished
	heal_finished.emit()
	play_idle()

func _on_attack_frame_changed() -> void:
	if _projectile_spawned_this_attack or not _attack_sprite.visible:
		return
	if _attack_sprite.frame >= ATTACK_RELEASE_FRAME_INDEX:
		_projectile_spawned_this_attack = true
		_spawn_projectile()

func _spawn_projectile() -> void:
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	# Added at the SceneTree root rather than get_tree().current_scene:
	# Battle isn't swapped in via change_scene_to_*, it's instanced as a
	# child of the CampaignFlow autoload (see CampaignFlow._start_battle-ish
	# flow), so current_scene still points at Main, not Battle. The root is
	# valid regardless of that scene-graph shape, and 2D rendering only
	# cares about the active Camera2D, not which ancestor a node has.
	get_tree().root.add_child(projectile)
	var offset := HAND_OFFSET
	offset.x *= signf(scale.x)  # mirror the hand offset when facing left
	projectile.launch(global_position + offset, _pending_target, _pending_did_hit, _pending_weapon, _pending_did_crit)

## Same front-facing-by-design pose as his VN portraits/full-body art —
## unlike Aurora/Lycith's side-on battle art, his default pose doesn't read
## as clearly left/right-facing. Guessed true (matches Aurora/Lycith's own
## convention) — verify in-game once he's actually placed on the map and
## flip this if moving right makes him look left, same check that caught
## Lycith's facing bug.
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

func _build_heal_frames() -> void:
	if _heal_frames_cache == null:
		_heal_frames_cache = SpriteFrames.new()
		_heal_frames_cache.add_animation("heal")
		_heal_frames_cache.set_animation_speed("heal", HEAL_FPS)
		_heal_frames_cache.set_animation_loop("heal", false)
		for i in range(1, HEAL_FRAME_COUNT + 1):
			var path := "%sheal_%02d.png" % [HEAL_FRAME_DIR, i]
			_heal_frames_cache.add_frame("heal", load(path))
	_heal_sprite.sprite_frames = _heal_frames_cache
