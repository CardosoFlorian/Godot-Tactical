class_name BattleMapData
extends Resource
## Data-driven battle map: terrain layout + who spawns where. Instances
## live as .tres files in data/maps/. Keeping this as a Resource (instead of
## hardcoding maps in scenes/scripts) means new missions are new .tres
## files, not new code.

@export var width: int = 10
@export var height: int = 8
@export var default_terrain: TerrainData
@export var terrain_overrides: Dictionary = {}  # Vector2i -> TerrainData
@export var spawns: Array[UnitSpawnData] = []
