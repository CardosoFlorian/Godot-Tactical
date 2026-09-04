class_name TerrainData
extends Resource
## Data-driven terrain type. Instances live as .tres files in data/terrain/.
## The logical grid (BattleGrid) stores a reference to one of these per tile;
## `atlas_coords` says which cell of the terrain TileSet renders it, so the
## visual and logical layers stay in sync from data alone.

@export var display_name: String = "Terrain"
@export var move_cost: int = 1  # ignored when impassable is true
@export var impassable: bool = false
@export var defense_bonus: int = 0
@export var avoid_bonus: int = 0
@export var atlas_coords: Vector2i = Vector2i.ZERO
