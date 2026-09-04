class_name UnitSelectState
extends BattleState
## Idle player-phase state: waits for the player to click one of their own
## un-acted units. Also the state re-entered after every action, so it's
## responsible for noticing "everyone's done" and ending the turn.

func enter(_previous_state_name: String = "") -> void:
	battle.selected_unit = null
	battle.grid.clear_highlight()
	SignalBus.unit_deselected.emit()
	if battle.all_player_units_acted():
		battle.end_player_turn()

func handle_unit_clicked(unit: Unit) -> void:
	if unit.unit_data.team != UnitData.Team.PLAYER or unit.has_acted:
		return
	battle.selected_unit = unit
	SignalBus.unit_selected.emit(unit)
	if unit.has_moved:
		state_machine.change_state("action_menu")
	else:
		state_machine.change_state("move")
