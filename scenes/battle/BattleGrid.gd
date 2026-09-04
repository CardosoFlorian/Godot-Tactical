class_name BattleGrid
extends Node2D
## Owns the logical battle grid: a Dictionary[Vector2i, TileState] separate
## from the visual TileMapLayer. Wraps AStarGrid2D for point-to-point
## pathfinding (movement confirmation) and exposes a Dijkstra flood-fill for
## movement-range queries, since AStarGrid2D has no native "reachable under
## budget" query (see plan notes).

const CELL_SIZE := Vector2i(32, 32)
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer
@onready var highlight_layer: TileMapLayer = $HighlightLayer

## Highlight tile atlas coords in the highlight TileSet.
const HIGHLIGHT_MOVE := Vector2i(0, 0)
const HIGHLIGHT_ATTACK := Vector2i(1, 0)

## Ground tile atlas coords in the terrain TileSet (always painted on
## terrain_layer, everywhere). Anything else (tree, wall...) goes on
## decoration_layer instead, since those source tiles are transparent
## around the decoration and are meant to sit on top of ground, not replace
## it — see TerrainData.atlas_coords doc.
const GROUND_ATLAS_COORDS := Vector2i(0, 0)

var _size: Vector2i = Vector2i.ZERO
var _tiles: Dictionary = {}  # Vector2i -> {"terrain": TerrainData, "occupant": Unit}
var _astar := AStarGrid2D.new()

func setup(size: Vector2i, terrain_map: Dictionary, default_terrain: TerrainData) -> void:
	_size = size
	_tiles.clear()
	terrain_layer.clear()
	decoration_layer.clear()
	for y in size.y:
		for x in size.x:
			var pos := Vector2i(x, y)
			var terrain: TerrainData = terrain_map.get(pos, default_terrain)
			_tiles[pos] = {"terrain": terrain, "occupant": null}
			terrain_layer.set_cell(pos, 0, GROUND_ATLAS_COORDS)
			if terrain.atlas_coords != GROUND_ATLAS_COORDS:
				decoration_layer.set_cell(pos, 0, terrain.atlas_coords)
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2(CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	# Solids and weights depend on the mover's team and movement type, so
	# they're (re)configured per-query in _refresh_astar_for, not here.

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _size.x and pos.y < _size.y

func get_terrain(pos: Vector2i) -> TerrainData:
	return _tiles.get(pos, {}).get("terrain")

## Combat-relevant terrain bonuses for the tile at `pos`, in the shape
## CombatResolver.resolve_combat/predict_expected_damage expect.
func get_terrain_combat_bonus(pos: Vector2i) -> Dictionary:
	var terrain := get_terrain(pos)
	if terrain == null:
		return {"def": 0, "avoid": 0}
	return {"def": terrain.defense_bonus, "avoid": terrain.avoid_bonus}

func get_occupant(pos: Vector2i) -> Unit:
	return _tiles.get(pos, {}).get("occupant")

func is_occupied(pos: Vector2i) -> bool:
	return get_occupant(pos) != null

func set_occupant(pos: Vector2i, unit: Unit) -> void:
	if _tiles.has(pos):
		_tiles[pos]["occupant"] = unit

func clear_occupant(pos: Vector2i) -> void:
	set_occupant(pos, null)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / Vector2(CELL_SIZE)).floor())

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos * CELL_SIZE) + Vector2(CELL_SIZE) / 2.0

## Rebuilds AStarGrid2D solidity AND per-tile weights from the current
## occupants/terrain, from the point of view of `mover_team` and
## `movement_type`: tiles occupied by the opposing side block movement
## (allies/the mover's own tile don't), and weights come from
## TerrainData.get_move_cost(movement_type) since a forest costs a mounted
## unit more and a flier less than it costs infantry.
func _refresh_astar_for(mover_team: int, movement_type: int) -> void:
	for pos in _tiles:
		var terrain: TerrainData = _tiles[pos]["terrain"]
		var occupant: Unit = _tiles[pos]["occupant"]
		var blocked_by_unit := occupant != null and occupant.unit_data.team != mover_team
		_astar.set_point_solid(pos, terrain.impassable or blocked_by_unit)
		_astar.set_point_weight_scale(pos, maxf(1.0, float(terrain.get_move_cost(movement_type))))

## Dijkstra flood-fill of tiles reachable within `move_points`, respecting
## per-tile move cost (by movement type) and blocking by the opposing team.
## Returns Dictionary[Vector2i, int] mapping reachable tile -> cost spent.
func compute_move_range(start: Vector2i, move_points: int, mover_team: int, movement_type: int = ClassData.MovementType.INFANTRY) -> Dictionary:
	var costs := {start: 0}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = costs[current]
		for dir in DIRECTIONS:
			var neighbor: Vector2i = current + dir
			if not is_in_bounds(neighbor) or not _tiles.has(neighbor):
				continue
			var terrain: TerrainData = _tiles[neighbor]["terrain"]
			if terrain.impassable:
				continue
			var occupant: Unit = _tiles[neighbor]["occupant"]
			if occupant != null and occupant.unit_data.team != mover_team and neighbor != start:
				continue  # can't move through/onto an enemy-occupied tile
			var new_cost := current_cost + terrain.get_move_cost(movement_type)
			if new_cost > move_points:
				continue
			if not costs.has(neighbor) or new_cost < costs[neighbor]:
				costs[neighbor] = new_cost
				frontier.append(neighbor)
	# A unit can never end its move on a tile occupied by anyone else, even
	# an ally it passed through — filter those out of the final range, but
	# keep the start tile itself (staying put is always valid).
	var result := {}
	for pos in costs:
		var occupant: Unit = _tiles.get(pos, {}).get("occupant")
		if pos == start or occupant == null:
			result[pos] = costs[pos]
	return result

## Returns the tile path (native AStarGrid2D, no homemade pathfinding) from
## `start` to `end`, treating opposing-team-occupied tiles as solid and
## weighting by `movement_type`.
func find_path(start: Vector2i, end: Vector2i, mover_team: int, movement_type: int = ClassData.MovementType.INFANTRY) -> Array[Vector2i]:
	_refresh_astar_for(mover_team, movement_type)
	var path := _astar.get_id_path(start, end)
	var result: Array[Vector2i] = []
	for p in path:
		result.append(p)
	return result

func get_tiles_in_range(center: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(-max_range, max_range + 1):
		for x in range(-max_range, max_range + 1):
			var offset := Vector2i(x, y)
			var dist := absi(x) + absi(y)
			if dist < min_range or dist > max_range:
				continue
			var pos := center + offset
			if is_in_bounds(pos):
				result.append(pos)
	return result

func show_highlight(tiles: Array[Vector2i], atlas_coords: Vector2i) -> void:
	for pos in tiles:
		highlight_layer.set_cell(pos, 0, atlas_coords)

func clear_highlight() -> void:
	highlight_layer.clear()
