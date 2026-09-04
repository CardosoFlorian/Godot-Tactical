class_name TargetingState
extends BattleState
## Highlights valid attack targets for the selected unit and resolves
## combat when one is clicked.

var valid_targets: Array[Unit] = []

func enter(_previous_state_name: String = "") -> void:
	valid_targets = battle.get_attackable_targets(battle.selected_unit)
	var weapon := battle.selected_unit.unit_data.get_equipped_weapon()
	var range_tiles := battle.grid.get_tiles_in_range(battle.selected_unit.grid_pos, weapon.min_range, weapon.max_range)
	battle.grid.clear_highlight()
	battle.grid.show_highlight(range_tiles, battle.grid.HIGHLIGHT_ATTACK)
	SignalBus.targeting_started.emit("attack", valid_targets)

func exit() -> void:
	battle.grid.clear_highlight()

func handle_unit_clicked(unit: Unit) -> void:
	if not valid_targets.has(unit):
		return
	var attacker := battle.selected_unit
	SignalBus.target_selected.emit(unit)
	battle.execute_attack(attacker, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
