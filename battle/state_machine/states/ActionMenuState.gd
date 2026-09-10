class_name ActionMenuState
extends BattleState
## Shows the Attack/Heal/Wait menu for a unit that has finished (or
## skipped) moving. Cancelling here undoes the move (Battle.undo_move) and
## goes back to "move" so the player can pick a different tile — any action
## is undoable up until Wait or a resolved Attack/Heal actually commits it
## (has_acted = true), per the rule the whole cancel chain follows.

func enter(_previous_state_name: String = "") -> void:
	var unit := battle.selected_unit
	var can_attack := battle.has_attackable_target(unit)
	# Heal is hidden entirely (not just disabled) unless the equipped weapon
	# can heal at all — see ActionMenu.show_for_action — since most units
	# never carry a healing weapon and a permanently-greyed-out button would
	# just be clutter for them.
	var weapon_can_heal := battle.weapon_can_heal(unit)
	var can_heal := weapon_can_heal and battle.has_healable_target(unit)
	# Support (freeze/knockback gauntlets) follows the exact same
	# hidden-unless-equipped, disabled-unless-a-target's-in-range split as
	# Heal above.
	var weapon_can_support := battle.weapon_can_support(unit)
	var can_support := weapon_can_support and battle.has_support_target(unit)
	SignalBus.action_menu_opened.emit(unit)
	battle.ui.show_action_menu(unit, can_attack, weapon_can_heal, can_heal, weapon_can_support, can_support, battle.can_switch_weapon(unit))

func exit() -> void:
	battle.ui.hide_action_menu()

func handle_action_chosen(action_name: String) -> void:
	var unit := battle.selected_unit
	match action_name:
		"attack":
			battle.start_targeting(unit, "attack")
		"heal":
			battle.start_targeting(unit, "heal")
		"support":
			battle.start_targeting(unit, "support")
		"wait":
			unit.has_acted = true
			state_machine.change_state("unit_select")
		"equip":
			if not battle.can_switch_weapon(unit):
				return
			state_machine.change_state("equip_menu")

func handle_cancel() -> void:
	battle.undo_move(battle.selected_unit)
	state_machine.change_state("move")
