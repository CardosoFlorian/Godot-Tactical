class_name StartTurnState
extends BattleState
## Resets the acting side's units and routes into their phase. Player phase
## goes to unit_select (waits for input); enemy phase goes straight into
## enemy_phase (AI drives itself).

func enter(_previous_state_name: String = "") -> void:
	if battle.current_phase == UnitData.Team.PLAYER:
		for unit in battle.player_units:
			unit.start_new_turn()
		SignalBus.player_phase_started.emit()
		state_machine.change_state("unit_select")
	else:
		for unit in battle.enemy_units:
			unit.start_new_turn()
		SignalBus.enemy_phase_started.emit()
		state_machine.change_state("enemy_phase")
