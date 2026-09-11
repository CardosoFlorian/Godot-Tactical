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
## Enemy-only going forward — player positions come from the prep phase's
## deployment_zone/max_deployed below instead (see PrepPhase). Left as one
## array with no team filter for now since nothing actually adds a PLAYER
## entry here anymore; Battle._build_battle only reads ENEMY entries from it.
@export var spawns: Array[UnitSpawnData] = []
## Tiles the player is allowed to deploy onto during the prep phase — see
## PrepPhase. Replaces per-unit fixed spawn positions for the player side
## (unlike enemies, which still use the fixed spawns above).
@export var deployment_zone: Array[Vector2i] = []
## Max number of living roster units the player can bring to this battle —
## see PrepPhase/UnitsScreen. First-pass default of 4 matches "everyone
## always deploys," today's behavior, so existing maps don't get harder by
## default.
@export var max_deployed: int = 4
