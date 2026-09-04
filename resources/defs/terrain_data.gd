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
@export var move_cost: int = 1  # ignored when impassable is true
@export var impassable: bool = false
@export var defense_bonus: int = 0
@export var avoid_bonus: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
