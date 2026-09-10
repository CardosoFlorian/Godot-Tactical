class_name EquipMenuState
extends BattleState
## Shows the selected unit's inventory and lets the player switch equipped
## weapon — reachable both before moving (MoveState's "equip" case) and
## after (ActionMenuState's "equip" case). Returns to whichever state opened
## it, via enter()'s own previous_state_name — no separate tracking needed
## since both callers only ever grant this from "move" or "action_menu", and
## both of those fully recompute their own menu state from the unit's live
## data on re-entry, so the new weapon's range/heal availability just falls
## out automatically. NOT a fully free action though — see
## handle_weapon_selected: switching weapon while still pre-move can cost
## the unit its move, same as real Fire Emblem never lets you re-equip and
## then still walk somewhere with the new loadout.

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
	var switched_weapon := index != battle.selected_unit_start_equipped_index
	unit_data.equipped_index = index
	# UnitInfoPanel only refreshes on this signal (see BattleHUD._on_unit_selected)
	# — without re-emitting it here, the panel keeps showing whichever weapon
	# was equipped when the unit was first selected, updating only on some
	# LATER unrelated event that happens to re-emit it.
	SignalBus.unit_selected.emit(unit)
	# Equipping something other than what the unit started its turn with,
	# while still in the pre-move menu, spends the unit's move — same rule
	# as clicking Attack/Heal from the pre-move quick menu (MoveState),
	# just redirecting straight to "action_menu" instead of "targeting"
	# since there's no attack/heal to resolve here. Picking the SAME weapon
	# back (index == start) doesn't lock anything — nothing actually
	# changed. Once already past "move" (returning to "action_menu"), the
	# move is spent either way, so this only matters coming from "move".
	if _return_state_name == "move" and switched_weapon:
		unit.has_moved = true
		battle.grid.clear_highlight()
		state_machine.change_state("action_menu")
	else:
		state_machine.change_state(_return_state_name)

## Unlike ActionMenuState.handle_cancel, nothing was moved to get here from
## either entry point — just bounce back to whichever menu opened this one,
## no undo_move.
func handle_cancel() -> void:
	state_machine.change_state(_return_state_name)
