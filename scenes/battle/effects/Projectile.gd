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
## by swapping FRAME_DIR/FRAME_COUNT on a subclass or just editing the
## constants below if this project only ever needs the one look at a time.

const FRAME_DIR := "res://assets/vfx/fireball/"
const FRAME_COUNT := 12
const FPS := 12.0
## pixels/sec. Deliberately low: the grid is only 32px/tile (see
## BattleGrid.CELL_SIZE) and attack range tops out at 2 tiles, so the actual
## flight distance is tiny (64px) regardless of the combat-scene camera
## zoom — at the previous 900, then 450, a 64px flight was over in well
## under a quarter second no matter what. 120 gives roughly half a second
## for a 2-tile shot, which should actually read as travel.
const SPEED := 120.0

const IMPACT_EFFECT_SCENE := preload("res://scenes/battle/effects/ImpactEffect.tscn")

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("fly")
	frames.set_animation_speed("fly", FPS)
	frames.set_animation_loop("fly", true)
	for i in range(1, FRAME_COUNT + 1):
		var path := "%sfireball_%02d.png" % [FRAME_DIR, i]
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
## `did_hit`/`weapon` control the impact effect on arrival: a miss just
## vanishes quietly (no sound/particles), a hit spawns a weapon-typed
## ImpactEffect (see Battle._play_impact_effect for the melee equivalent).
func launch(from: Vector2, to: Vector2, did_hit: bool = true, weapon: WeaponData = null) -> void:
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
		effect.play(weapon)
	queue_free()
