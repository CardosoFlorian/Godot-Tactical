class_name StartTurnState
extends BattleState
## Resets the acting side's units and routes into their phase. Player phase
## goes to unit_select (waits for input); enemy phase goes straight into
## enemy_phase (AI drives itself).
##
## Awaits the phase banner (BattleHUD.play_player/enemy_phase_banner) before
## changing state — the user's own call: neither side should be able to act
## while the "Phase Joueur"/"Phase Ennemie" banner is still playing. Staying
## in StartTurnState (whose handle_* hooks are all BattleState's no-op
## defaults) for that whole duration blocks player clicks for free; the
## enemy side is blocked the same way, just because EnemyPhaseState's own
## AI-driving enter() simply hasn't run yet.
func enter(_previous_state_name: String = "") -> void:
	if battle.current_phase == UnitData.Team.PLAYER:
		for unit in battle.player_units:
			unit.start_new_turn()
		SignalBus.player_phase_started.emit()
		await battle.ui.play_player_phase_banner()
		state_machine.change_state("unit_select")
	else:
		for unit in battle.enemy_units:
			unit.start_new_turn()
		SignalBus.enemy_phase_started.emit()
		await battle.ui.play_enemy_phase_banner()
		state_machine.change_state("enemy_phase")
