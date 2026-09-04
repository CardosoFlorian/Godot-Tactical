class_name ActionMenuState
extends BattleState
## Shows the Attack/Wait menu for a unit that has finished (or skipped)
## moving. The MVP doesn't support undoing a move, so cancelling out of the
## menu just ends the unit's turn as a Wait rather than soft-locking on
## undo logic the game doesn't have yet.

func enter(_previous_state_name: String = "") -> void:
	var unit := battle.selected_unit
	var can_attack := battle.has_attackable_target(unit)
	SignalBus.action_menu_opened.emit(unit)
	battle.ui.show_action_menu(unit, can_attack)

func exit() -> void:
	battle.ui.hide_action_menu()

func handle_action_chosen(action_name: String) -> void:
	var unit := battle.selected_unit
	match action_name:
		"attack":
			state_machine.change_state("targeting")
		"wait":
			unit.has_acted = true
			state_machine.change_state("unit_select")

func handle_cancel() -> void:
	handle_action_chosen("wait")
