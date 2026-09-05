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
	# So the hover preview (Battle._update_targeting_hover) doesn't stay
	# stale/hidden if the mouse happens to already be resting on a unit that
	# was also a valid target last time this state was entered.
	battle._clear_combat_preview()
	# Same "only Cancel is clickable" panel as the move phase — otherwise
	# there'd be no visible way to back out of targeting once you've clicked
	# Attack but decide you don't want to (right-click/Escape still work but
	# aren't discoverable on their own).
	battle.ui.show_move_menu()

func exit() -> void:
	battle.grid.clear_highlight()
	battle._clear_combat_preview()
	battle.ui.hide_action_menu()

func handle_unit_clicked(unit: Unit) -> void:
	if not valid_targets.has(unit):
		return
	var attacker := battle.selected_unit
	SignalBus.target_selected.emit(unit)
	# Clear these now rather than waiting for exit(): this state doesn't
	# formally change until execute_attack's whole combat scene finishes
	# playing, and the attack-range highlight + Attack/Wait/Cancel panel
	# have no business still showing during that.
	battle.grid.clear_highlight()
	battle.ui.hide_action_menu()
	await battle.execute_attack(attacker, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
