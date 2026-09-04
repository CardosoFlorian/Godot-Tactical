class_name TerrainData
extends Resource
## Data-driven terrain type. Instances live as .tres files in data/terrain/.
## The logical grid (BattleGrid) stores a reference to one of these per tile;
## `atlas_coords` says which cell of the terrain TileSet renders it. Ground
## (BattleGrid.GROUND_ATLAS_COORDS, e.g. plain.tres) is always painted first
## on every tile; any other atlas_coords is drawn as a decoration on top of
## that ground on a separate layer, since Kenney-style tiles like a tree or
## a wall are transparent around the subject rather than including their
## own ground.

@export var display_name: String = "Terrain"
@export var move_cost: int = 1  # infantry cost; ignored when impassable is true
@export var impassable: bool = false  # blocks every movement type, flying included (walls/buildings, not open sky)
@export var defense_bonus: int = 0
@export var avoid_bonus: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO

@export_group("Movement type overrides")
## Mounted units pay extra crossing rough terrain (e.g. forest) — classic
## cavalry-avoids-the-woods rule. Defaults to move_cost (no penalty).
@export var mounted_move_cost: int = -1
## Flying units mostly ignore ground obstacles (forest, rivers once those
## exist) but still can't cross impassable tiles (walls/buildings). Defaults
## to 1 (ignores rough terrain) rather than move_cost.
@export var flying_move_cost: int = -1

func get_move_cost(movement_type: int) -> int:
	match movement_type:
		ClassData.MovementType.MOUNTED:
			return mounted_move_cost if mounted_move_cost >= 0 else move_cost
		ClassData.MovementType.FLYING:
			return flying_move_cost if flying_move_cost >= 0 else 1
		_:
			return move_cost
