extends Node
## Autoload holding persistent state across scenes: the player roster,
## permadeath setting, and where the player is in the campaign flow.
## Battle scenes read/write this; Dialogic scenes and the main menu read it
## to know what to show next.

@export var permadeath_enabled: bool = true

var player_roster: Array[UnitData] = []
var campaign_step_index: int = 0

func add_unit(unit: UnitData) -> void:
	if not player_roster.has(unit):
		player_roster.append(unit)

func remove_unit(unit: UnitData) -> void:
	player_roster.erase(unit)

func on_unit_died(unit: UnitData) -> void:
	if unit.team != UnitData.Team.PLAYER:
		return
	if permadeath_enabled or unit.permadeath:
		remove_unit(unit)
	else:
		unit.set_current_hp(0)

func get_living_roster() -> Array[UnitData]:
	return player_roster.filter(func(u: UnitData) -> bool: return u.is_alive())

## Finds the persistent roster copy of a character by id, so battles spawn
## the same UnitData (with carried-over HP/death state) across a campaign
## instead of a fresh copy of the .tres template every time.
func get_roster_unit(character_id: String) -> UnitData:
	for unit in player_roster:
		if unit.character_id == character_id:
			return unit
	return null

func reset_for_new_battle() -> void:
	for unit in player_roster:
		unit.set_current_hp(unit.get_max_hp())
