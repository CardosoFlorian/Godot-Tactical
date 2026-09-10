class_name SupportTargetingState
extends BattleState
## Highlights valid support-gauntlet targets (enemies in range) for the
## selected unit and resolves the freeze/knockback effect when one is
## clicked. Mirrors HealState's shape closely — the real differences are the
## target pool (enemies, not allies, and no "not at full HP" filter: any
## enemy in range is a valid target) and the highlight color (reuses
## HIGHLIGHT_ATTACK, same as TargetingState, since this is enemy-facing too).

var valid_targets: Array[Unit] = []

func enter(_previous_state_name: String = "") -> void:
	valid_targets = battle.get_support_targets(battle.selected_unit)
	var weapon := battle.selected_unit.unit_data.get_equipped_weapon()
	var range_tiles := battle.grid.get_tiles_in_range(battle.selected_unit.grid_pos, weapon.min_range, weapon.max_range)
	battle.grid.clear_highlight()
	battle.grid.show_highlight(range_tiles, battle.grid.HIGHLIGHT_ATTACK)
	SignalBus.targeting_started.emit("support", valid_targets)
	# Same "only Cancel is clickable" panel TargetingState/HealState use
	# while picking a target — see either's own comment for why.
	battle.ui.show_move_menu()

func exit() -> void:
	battle.grid.clear_highlight()
	battle.ui.hide_action_menu()

func handle_unit_clicked(unit: Unit) -> void:
	if not valid_targets.has(unit):
		return
	var user := battle.selected_unit
	SignalBus.target_selected.emit(unit)
	battle.grid.clear_highlight()
	battle.ui.hide_action_menu()
	await battle.execute_support(user, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
