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
##
## Real pacing bug caught live: this state is entered IMMEDIATELY after the
## previous phase's very last action finishes — including that action's own
## EXP bar fill — so the new phase's banner used to start the instant the
## EXP bar disappeared, with zero breathing room. User: "après le dernier
## combat d'une phase quand l'exp est gagné la prochaine [phase] commence
## directement et c'est trop rapide." PHASE_TRANSITION_PAUSE gives a short
## beat before the banner starts, purely for pacing/feel — not gating input,
## which the existing "stay in this no-op state" mechanism above already
## handles on its own.
const PHASE_TRANSITION_PAUSE := 0.4

func enter(_previous_state_name: String = "") -> void:
	await battle.get_tree().create_timer(PHASE_TRANSITION_PAUSE, false, false, true).timeout
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
