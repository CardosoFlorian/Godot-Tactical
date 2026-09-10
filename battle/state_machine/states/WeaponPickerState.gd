class_name WeaponPickerState
extends BattleState
## Weapon-choice screen shown right before Attack/Heal/Support targeting —
## classic Fire Emblem "pick which weapon, THEN pick your target" flow.
## Only ever reached via Battle.start_targeting (which decides there's an
## actual choice to make), for whichever action is recorded in
## battle.pending_weapon_picker_action. Picking a weapon here both equips
## it (permanently, same as the Equip menu) AND jumps straight into the
## matching targeting state — replacing the old "open Equip, switch weapon,
## back out, click the action again" round-trip.
##
## No return-state tracking the way EquipMenuState has one: start_targeting
## is only ever called after the unit's move is already committed (a real
## move, or a pre-move quick-action's no-op move onto its own tile), so
## Cancel always goes back to "action_menu" — same as TargetingState/
## HealState/SupportTargetingState's own Cancel already does.

const TARGET_STATE := {
	"attack": "targeting",
	"heal": "heal_targeting",
	"support": "support_targeting",
}

func enter(_previous_state_name: String = "") -> void:
	battle.ui.show_equip_menu(battle.selected_unit.unit_data, battle.pending_weapon_picker_action)

func exit() -> void:
	battle.ui.hide_equip_menu()

func handle_weapon_selected(index: int) -> void:
	var unit := battle.selected_unit
	var unit_data := unit.unit_data
	if index < 0 or index >= unit_data.inventory.size():
		return
	var weapon := unit_data.inventory[index]
	var action := battle.pending_weapon_picker_action
	# Belt-and-suspenders, same convention EquipMenuState already uses: a
	# disabled EquipMenuRow never fires row_selected for these, but check
	# again anyway rather than trusting the UI alone.
	if not unit_data.can_use_weapon(weapon.weapon_type):
		return
	if not weapon.matches_action(action):
		return
	unit_data.equipped_index = index
	SignalBus.unit_selected.emit(unit)
	state_machine.change_state(TARGET_STATE[action])

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
