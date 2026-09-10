class_name Unit
extends Node2D
## Visual/runtime representation of a unit on the battlefield. Holds a
## reference to its UnitData (persistent character data) plus battle-only
## state (grid position, whether it has acted this turn).

const MOVE_SPEED := 220.0  # pixels/sec along the confirmed path

## global_position sits at the unit's feet (tile-center, per
## BattleGrid.grid_to_world) — roughly chest-height above that instead, so
## anything aimed "at" this unit (impact VFX, a projectile's destination)
## reads as centered on their body instead of landing down at their feet.
## First-pass guess, same as every other scale/offset in this project's art
## pipeline — retune once seen against a real screenshot.
const IMPACT_POINT_OFFSET := Vector2(0, -18)

@export var unit_data: UnitData

var grid_pos: Vector2i = Vector2i.ZERO
var has_moved: bool = false
var has_acted: bool = false:
	set(value):
		has_acted = value
		_refresh_sprite()

## Left/right only — this is a top-down grid, so vertical moves never change
## facing. Source art (both the rig and the placeholder icons) is drawn
## facing left, hence the default.
var facing_left: bool = true:
	set(value):
		facing_left = value
		_apply_facing()

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_ring: Node2D = $SelectionRing

## Forwarded from the rig's own `attack_contact` (Aurora/Lycith-style melee
## rigs only — see AuroraBattleSprite.ATTACK_CONTACT_FRAME_INDEX) so
## Battle.gd can time the hit VFX/SFX off the actual blade-lands frame
## instead of the swing's full finish. Never fires for a rig that doesn't
## have this signal (Martin's ranged rig plays its own impact effect via
## Projectile on arrival instead).
signal attack_contact

# Set once, lazily, if unit_data.rigged_battle_sprite is present — see
# _refresh_sprite. Most units don't have one and just use `sprite` above.
var _rig: Node2D = null

func _ready() -> void:
	selection_ring.visible = false
	_refresh_sprite()

func setup(data: UnitData, start_pos: Vector2i, grid: BattleGrid) -> void:
	unit_data = data
	grid_pos = start_pos
	position = grid.grid_to_world(start_pos)
	# Debuffs/freeze are battle-only (unlike current_hp, which intentionally
	# persists) — a safety net in case a unit's UnitData somehow still
	# carries one in from a previous fight.
	unit_data.active_debuffs.clear()
	unit_data.frozen_turns_remaining = 0
	# Re-derive from the unit's actual starting loadout, regardless of
	# whatever order .tres properties happened to deserialize in — see
	# UnitData.last_combat_equipped_index.
	unit_data.equipped_index = unit_data.equipped_index
	_refresh_sprite()

## Acted units are visibly dimmed so it's never ambiguous whether they can
## still be given an order this turn.
func _refresh_sprite() -> void:
	if not is_inside_tree() or unit_data == null:
		return
	if unit_data.rigged_battle_sprite and _rig == null:
		_rig = unit_data.rigged_battle_sprite.instantiate()
		add_child(_rig)
		sprite.visible = false
	elif unit_data.battle_sprite:
		sprite.texture = unit_data.battle_sprite
	var team_tint := Color.WHITE if unit_data.team == UnitData.Team.PLAYER else Color(1.0, 0.75, 0.75)
	var tint := team_tint.darkened(0.25) if has_acted else team_tint
	if _rig:
		_rig.modulate = tint
	else:
		sprite.modulate = tint
	_apply_facing()

func _apply_facing() -> void:
	if not is_inside_tree():
		return
	if _rig:
		# Different rigs face different ways natively (Aurora's art faces
		# right, Lycith's faces left) — each rig script reports its own via
		# faces_right_by_default() rather than this code hardcoding one.
		var faces_right: bool = _rig.faces_right_by_default() if _rig.has_method("faces_right_by_default") else true
		var s := absf(_rig.scale.x)
		_rig.scale.x = -s if facing_left == faces_right else s
	else:
		sprite.flip_h = not facing_left

## See IMPACT_POINT_OFFSET — the point anything aimed at this unit (impact
## VFX, a projectile's destination) should target, instead of raw
## global_position which sits down at their feet.
func get_impact_point() -> Vector2:
	return global_position + IMPACT_POINT_OFFSET

## Whether this unit's rig can tell Battle.gd exactly when a swing "lands"
## (AuroraBattleSprite/LycithBattleSprite-style, frame-synced attack_contact
## — see ATTACK_CONTACT_FRAME_INDEX on either). False for a plain sprite
## (every current enemy, and Kessa, who don't have a rigged_battle_sprite
## yet) — Battle.gd falls back to playing the hit VFX/SFX at the bump-lunge
## peak instead, since there's no real swing animation to sync to.
func supports_attack_contact() -> bool:
	return _rig != null and _rig.has_signal("attack_contact")

## No-op if this unit has no rigged battle sprite (plain static sprite).
## `target_global_pos` is only meaningful to a ranged rig (e.g. Martin's
## fireball needs to know where to fly); `did_hit`/`weapon`/`did_crit` are
## only meaningful to a rig that plays its own impact effect on arrival (a
## projectile) rather than Battle.gd playing one directly for a melee swing
## — melee rigs accept and ignore all four.
func play_attack_animation(target_global_pos: Vector2 = Vector2.ZERO, did_hit: bool = true, weapon: WeaponData = null, did_crit: bool = false) -> void:
	if _rig and _rig.has_method("play_attack"):
		if _rig.has_signal("attack_contact") and not _rig.attack_contact.is_connected(attack_contact.emit):
			_rig.attack_contact.connect(attack_contact.emit)
		await _rig.play_attack(target_global_pos, did_hit, weapon, did_crit)

## No-op if this unit's rig doesn't have a heal cast (every current unit
## except Martin — see MartinBattleSprite.play_heal). Battle.execute_heal
## awaits this before applying the HP change, same "animation plays, then
## the actual game-state change lands" ordering play_attack_animation uses.
func play_heal_animation() -> void:
	if _rig and _rig.has_method("play_heal"):
		await _rig.play_heal()

func set_selected(selected: bool) -> void:
	selection_ring.visible = selected

func start_new_turn() -> void:
	has_moved = false
	has_acted = false

func move_along_path(path: Array[Vector2i], grid: BattleGrid) -> void:
	if path.is_empty():
		return
	var tween := create_tween()
	var previous_pos := position
	var previous_grid := grid_pos
	for step in path:
		if step.x != previous_grid.x:
			facing_left = step.x < previous_grid.x
		var world_pos := grid.grid_to_world(step)
		var dist := previous_pos.distance_to(world_pos)
		tween.tween_property(self, "position", world_pos, dist / MOVE_SPEED)
		previous_pos = world_pos
		previous_grid = step
	grid_pos = path[-1]
	await tween.finished
