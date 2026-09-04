class_name EnemyPhaseState
extends BattleState
## Runs the utility-based EnemyAI for each enemy unit in turn, then hands
## the turn back to the player.

func enter(_previous_state_name: String = "") -> void:
	_run_enemy_turn()

func _run_enemy_turn() -> void:
	for unit in battle.enemy_units.duplicate():
		if not is_instance_valid(unit) or unit.has_acted:
			continue
		await EnemyAI.take_turn(unit, battle)
		if battle.check_battle_end():
			state_machine.change_state("game_over")
			return
	battle.end_enemy_turn()
