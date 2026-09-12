class_name Projectile
extends Node2D
## Generic ranged-attack projectile: plays its own looping animation while
## tweening from one world position to another, then frees itself. Purely
## visual, fire-and-forget — the rig that spawns one (see
## MartinBattleSprite.play_attack) doesn't await `launch()`, since combat
## resolution is already timed off the caster's own attack animation, not
## the projectile's flight.
##
## Reusable for any future ranged unit (a bow's arrow, another tome's bolt)
## — `frame_dir`/`frame_prefix`/`frame_count`/`fps` are plain instance vars,
## not consts, so the spawning rig can set them right after instantiate()
## and before add_child() (which is when _ready() actually builds the
## SpriteFrames) to swap in a different look. Defaults match the original
## fireball so Martin's own spawn code (which never touches these) keeps
## working unchanged — see KessaBattleSprite._spawn_projectile for the
## first rig to actually override them (a single-frame arrow instead of a
## 12-frame animated flame).

var frame_dir := "res://assets/vfx/fireball/"
var frame_prefix := "fireball"
var frame_count := 12
var fps := 12.0
## pixels/sec. Deliberately low: the grid is only 32px/tile (see
## BattleGrid.CELL_SIZE) and attack range tops out at 2 tiles, so the actual
## flight distance is tiny (64px) regardless of the combat-scene camera
## zoom — at the previous 900, then 450, a 64px flight was over in well
## under a quarter second no matter what. 120 gives roughly half a second
## for a 2-tile shot, which should actually read as travel.
const SPEED := 120.0

const IMPACT_EFFECT_SCENE := preload("res://scenes/battle/effects/ImpactEffect.tscn")
## Same weapon-agnostic whoosh Battle._play_miss_sound uses for a melee miss
## — a miss sounds the same regardless of how it was thrown/cast.
const SOUND_MISS := preload("res://assets/audio/sfx/miss.mp3")

## Same global time_scale dip Battle._play_crit_hitstop uses for a melee
## crit (see there for why it's a bare Engine.time_scale multiplier, not the
## pause system) — duplicated here rather than reached-into on Battle since
## Projectile has no easy reference back to it (spawned under
## get_tree().root, not as Battle's child). No screen flash on a ranged
## crit yet, just the slowdown — not worth a shared singleton for that one
## missing piece on a first pass.
const HITSTOP_TIME_SCALE := 0.3
const HITSTOP_DURATION := 0.2

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", fps)
	frames.set_animation_loop("fly", true)
	for i in range(1, frame_count + 1):
		var path := "%s%s_%02d.png" % [frame_dir, frame_prefix, i]
		frames.add_frame("fly", load(path))
	_sprite.sprite_frames = frames
	_sprite.play("fly")

## Flies from `from` to `to` (world/global coordinates), then queue_frees
## itself. Points at ANY angle (up, down, diagonal), not just left/right —
## confirmed broken before: Martin hitting a target directly below him
## still showed the fireball facing left, since the old code only ever set
## `flip_h` off the X sign and never rotated at all.
##
## Plain `rotation = dir.angle()` would technically point the right way for
## every angle too, but for a leftward-pointing angle it gets there by
## rotating ~180°, which flips the sprite UPSIDE DOWN (mirrors X *and* Y) —
## wrong, since the art's flame-trail silhouette isn't top/bottom symmetric,
## and this would also change the already-tested-and-approved pure-left
## look. So: mirror (`flip_h`) instead of rotating past +/-90°, and only use
## `rotation` for the remaining up/down component. Derivation: with
## `front_local = Vector2(-1, 0)` (the sprite's forward direction once
## flip_h'd), solving `front_local.rotated(r) == dir.normalized()` gives
## `r = dir.angle() + PI` — NOT `PI - dir.angle()`, which looked plausible
## but points the vertical component the wrong way (verified by hand on a
## down-left case before shipping this).
## `did_hit`/`weapon`/`did_crit` control the impact effect on arrival: a hit
## spawns a weapon-typed ImpactEffect (or the weapon-agnostic red crit one if
## `did_crit` — see Battle._play_impact_effect for the melee equivalent), a
## miss plays SOUND_MISS instead — same "at the moment it would connect"
## timing as a landed hit's effect, not delayed to whenever the caster's own
## animation happens to finish.
func launch(from: Vector2, to: Vector2, did_hit: bool = true, weapon: WeaponData = null, did_crit: bool = false) -> void:
	global_position = from
	var dir := to - from
	if dir.x < 0:
		_sprite.flip_h = true
		rotation = dir.angle() + PI
	else:
		_sprite.flip_h = false
		rotation = dir.angle()
	var duration := from.distance_to(to) / SPEED
	var tween := create_tween()
	tween.tween_property(self, "global_position", to, duration)
	await tween.finished
	if did_hit:
		var effect: ImpactEffect = IMPACT_EFFECT_SCENE.instantiate()
		get_tree().root.add_child(effect)
		effect.global_position = global_position
		effect.play(weapon, did_crit)
		if did_crit:
			Engine.time_scale = HITSTOP_TIME_SCALE
			get_tree().create_timer(HITSTOP_DURATION, false, false, true).timeout.connect(
				func(): Engine.time_scale = 1.0)
	else:
		var miss_player := AudioStreamPlayer2D.new()
		get_tree().root.add_child(miss_player)
		miss_player.global_position = global_position
		miss_player.stream = SOUND_MISS
		miss_player.play()
		miss_player.finished.connect(miss_player.queue_free)
	queue_free()
