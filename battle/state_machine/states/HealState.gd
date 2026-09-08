class_name HealState
extends BattleState
## Highlights valid heal targets (allies in range, not at full HP — self
## included) in green for the selected unit and resolves the heal when one
## is clicked. Mirrors TargetingState's shape closely; kept as its own
## state rather than folding into TargetingState since the target pool
## (allies, not opponents), highlight color, and resolution (a flat HP
## restore, no hit/crit/counter) are all different enough that sharing one
## state would mean branching on "attack or heal" throughout it.

var valid_targets: Array[Unit] = []

func enter(_previous_state_name: String = "") -> void:
	valid_targets = battle.get_healable_targets(battle.selected_unit)
	var weapon := battle.selected_unit.unit_data.get_equipped_weapon()
	var range_tiles := battle.grid.get_tiles_in_range(battle.selected_unit.grid_pos, weapon.min_range, weapon.max_range)
	battle.grid.clear_highlight()
	battle.grid.show_highlight(range_tiles, battle.grid.HIGHLIGHT_HEAL)
	SignalBus.targeting_started.emit("heal", valid_targets)
	# Same "only Cancel is clickable" panel TargetingState uses while picking
	# an attack target — see its own comment for why.
	battle.ui.show_move_menu()

func exit() -> void:
	battle.grid.clear_highlight()
	battle.ui.hide_action_menu()

func handle_unit_clicked(unit: Unit) -> void:
	if not valid_targets.has(unit):
		return
	var healer := battle.selected_unit
	SignalBus.target_selected.emit(unit)
	battle.grid.clear_highlight()
	battle.ui.hide_action_menu()
	await battle.execute_heal(healer, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
