class_name Unit
extends Node2D
## Visual/runtime representation of a unit on the battlefield. Holds a
## reference to its UnitData (persistent character data) plus battle-only
## state (grid position, whether it has acted this turn).

const MOVE_SPEED := 220.0  # pixels/sec along the confirmed path

@export var unit_data: UnitData

var grid_pos: Vector2i = Vector2i.ZERO
var has_moved: bool = false
var has_acted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_ring: Node2D = $SelectionRing

func _ready() -> void:
	selection_ring.visible = false
	_refresh_sprite()

func setup(data: UnitData, start_pos: Vector2i, grid: BattleGrid) -> void:
	unit_data = data
	grid_pos = start_pos
	position = grid.grid_to_world(start_pos)
	_refresh_sprite()

func _refresh_sprite() -> void:
	if not is_inside_tree() or unit_data == null:
		return
	if unit_data.battle_sprite:
		sprite.texture = unit_data.battle_sprite
	sprite.modulate = Color.WHITE if unit_data.team == UnitData.Team.PLAYER else Color(1.0, 0.75, 0.75)

func set_selected(selected: bool) -> void:
	selection_ring.visible = selected

func start_new_turn() -> void:
	has_moved = false
	has_acted = false

func move_along_path(path: Array[Vector2i], grid: BattleGrid) -> void:
	if path.is_empty():
		return
	var tween := create_tween()
	for step in path:
		var world_pos := grid.grid_to_world(step)
		var dist := position.distance_to(world_pos)
		tween.tween_property(self, "position", world_pos, dist / MOVE_SPEED)
	grid_pos = path[-1]
	await tween.finished
