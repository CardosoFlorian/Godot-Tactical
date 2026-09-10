class_name EquipMenuState
extends BattleState
## Shows the selected unit's inventory and lets the player switch equipped
## weapon — a FREE action (never sets has_acted, never touches grid_pos or
## has_moved), so it's reachable both before moving (MoveState's "equip"
## case, no move-confirmation trick needed since nothing is being committed)
## and after (ActionMenuState's "equip" case). Returns to whichever state
## opened it, via enter()'s own previous_state_name — no separate tracking
## needed since both callers only ever grant this from "move" or
## "action_menu", and both of those fully recompute their own menu state
## from the unit's live data on re-entry, so the new weapon's range/heal
## availability just falls out automatically.

var _return_state_name: String = "action_menu"

func enter(previous_state_name: String = "") -> void:
	_return_state_name = previous_state_name
	battle.ui.show_equip_menu(battle.selected_unit.unit_data)

func exit() -> void:
	battle.ui.hide_equip_menu()

func handle_weapon_selected(index: int) -> void:
	var unit := battle.selected_unit
	var unit_data := unit.unit_data
	if index < 0 or index >= unit_data.inventory.size():
		return
	unit_data.equipped_index = index
	# UnitInfoPanel only refreshes on this signal (see BattleHUD._on_unit_selected)
	# — without re-emitting it here, the panel keeps showing whichever weapon
	# was equipped when the unit was first selected, updating only on some
	# LATER unrelated event that happens to re-emit it.
	SignalBus.unit_selected.emit(unit)
	state_machine.change_state(_return_state_name)

## Unlike ActionMenuState.handle_cancel, nothing was moved to get here from
## either entry point — just bounce back to whichever menu opened this one,
## no undo_move.
func handle_cancel() -> void:
	state_machine.change_state(_return_state_name)
