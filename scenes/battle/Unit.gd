class_name Unit
extends Node2D
## Visual/runtime representation of a unit on the battlefield. Holds a
## reference to its UnitData (persistent character data) plus battle-only
## state (grid position, whether it has acted this turn).

const MOVE_SPEED := 220.0  # pixels/sec along the confirmed path

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
		# Aurora's rigged art faces right unflipped (unlike the plain
		# placeholder sprite below), so this condition is the mirror image
		# of the flip_h one.
		var s := absf(_rig.scale.x)
		_rig.scale.x = -s if facing_left else s
	else:
		sprite.flip_h = not facing_left

## No-op if this unit has no rigged battle sprite (plain static sprite).
func play_attack_animation() -> void:
	if _rig and _rig.has_method("play_attack"):
		await _rig.play_attack()

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
