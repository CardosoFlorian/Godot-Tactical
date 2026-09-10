class_name MoveState
extends BattleState
## Shows the selected unit's movement range and handles confirming a move.
## Range comes from BattleGrid.compute_move_range (Dijkstra flood-fill); the
## actual path walked comes from BattleGrid.find_path (native AStarGrid2D).
##
## Clicking an enemy that's within threat range (some tile in move_range
## puts it in weapon range) moves the unit to the cheapest such tile and
## attacks immediately, instead of requiring a separate move + Attack +
## re-click sequence.

func enter(_previous_state_name: String = "") -> void:
	var unit := battle.selected_unit
	# get_move_range (not grid.compute_move_range directly) — a frozen unit's
	# range is just its own tile, see Battle.get_move_range.
	battle.move_range = battle.get_move_range(unit)
	battle.grid.clear_highlight()
	battle.show_unit_range(unit, battle.move_range)
	SignalBus.move_range_shown.emit(battle.move_range)
	var weapon_can_heal := battle.weapon_can_heal(unit)
	var weapon_can_support := battle.weapon_can_support(unit)
	# Trailing `true` is can_wait — always available pre-move (see
	# ActionMenu.show_for_move's own doc comment for why every OTHER caller
	# of show_move_menu leaves it at its false default instead).
	battle.ui.show_move_menu(battle.has_attackable_target(unit), weapon_can_heal, weapon_can_heal and battle.has_healable_target(unit), weapon_can_support, weapon_can_support and battle.has_support_target(unit), battle.can_switch_weapon(unit), true)

func exit() -> void:
	battle.ui.hide_action_menu()

## Wait is always available here (skipping a unit's turn in place doesn't
## need a move); Attack/Heal only when ActionMenu.show_for_move actually
## enabled them — i.e. the selected unit can already hit/heal something
## from where it's standing. Either way this saves the "click my own tile
## to confirm not moving, THEN click Attack/Heal/Wait" detour: Wait just
## ends the unit's turn outright, and Attack/Heal confirm a no-op "move"
## onto its own tile (same mechanism handle_unit_clicked below uses when
## you click your own unit) so has_moved flips true, then jumps straight to
## targeting instead of bouncing through "action_menu" just to click again.
## Equip is a third case, but doesn't fit either pattern: opening the menu
## itself doesn't commit anything (has_moved stays false so far) — but if the
## player actually walks out with a DIFFERENT weapon than they started the
## turn with, EquipMenuState.handle_weapon_selected is what locks has_moved
## true and redirects straight to "action_menu" instead of back here, so the
## unit can still Attack/Heal/Wait from where it's standing but can no longer
## move — see the comment there for why.
func handle_action_chosen(action_name: String) -> void:
	var unit := battle.selected_unit
	match action_name:
		"wait":
			unit.has_acted = true
			state_machine.change_state("unit_select")
		"attack":
			if not battle.has_attackable_target(unit):
				return
			await _move_to(unit.grid_pos)
			battle.start_targeting(unit, "attack")
		"heal":
			if not battle.has_healable_target(unit):
				return
			await _move_to(unit.grid_pos)
			battle.start_targeting(unit, "heal")
		"support":
			if not battle.has_support_target(unit):
				return
			await _move_to(unit.grid_pos)
			battle.start_targeting(unit, "support")
		"equip":
			if not battle.can_switch_weapon(unit):
				return
			state_machine.change_state("equip_menu")

func handle_tile_clicked(pos: Vector2i) -> void:
	if not battle.move_range.has(pos):
		return
	await _move_to(pos)
	state_machine.change_state("action_menu")

func handle_unit_clicked(unit: Unit) -> void:
	var mover := battle.selected_unit
	if unit == mover:
		handle_tile_clicked(unit.grid_pos)
		return
	if unit.unit_data.team == mover.unit_data.team:
		return
	var attack_pos: Variant = _find_attack_position(unit)
	if attack_pos == null:
		return
	await _move_to(attack_pos)
	# _move_to already clears the move-range highlight, but not this panel —
	# same reasoning as TargetingState.handle_unit_clicked: this state
	# doesn't formally exit (and hide it) until the whole combat scene
	# finishes playing.
	battle.ui.hide_action_menu()
	await battle.execute_attack(mover, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	# Nothing's moved yet at this point, so no undo_move — but as a safety
	# net, revert any equip swap anyway. In practice equipped_index should
	# already equal selected_unit_start_equipped_index whenever we're back
	# in "move" (a real change redirects to "action_menu" instead, see
	# handle_action_chosen's "equip" case), so this is normally a no-op.
	battle.revert_equipped_weapon(battle.selected_unit)
	state_machine.change_state("unit_select")

## Walks the selected unit onto `pos` (must be in battle.move_range) and
## updates grid occupancy/unit state. Does not change state on its own.
func _move_to(pos: Vector2i) -> void:
	var unit := battle.selected_unit
	var old_pos := unit.grid_pos
	var path := battle.grid.find_path(old_pos, pos, unit.unit_data.team, unit.unit_data.get_movement_type())
	battle.grid.clear_occupant(old_pos)
	battle.grid.clear_highlight()
	if path.size() > 1:
		await unit.move_along_path(path, battle.grid)
	unit.grid_pos = pos
	unit.has_moved = true
	battle.grid.set_occupant(pos, unit)
	SignalBus.move_confirmed.emit(unit, path)

## Cheapest reachable tile (still within battle.move_range) from which the
## selected unit's weapon would hit `target`, or null if none exists.
func _find_attack_position(target: Unit) -> Variant:
	var mover := battle.selected_unit
	var weapon := mover.unit_data.get_equipped_weapon()
	if weapon == null:
		return null
	var best_pos: Variant = null
	var best_cost := INF
	for pos in battle.move_range:
		var dist := absi(pos.x - target.grid_pos.x) + absi(pos.y - target.grid_pos.y)
		if not CombatResolver.is_in_weapon_range(dist, weapon):
			continue
		var cost: int = battle.move_range[pos]
		if cost < best_cost:
			best_cost = cost
			best_pos = pos
	return best_pos
