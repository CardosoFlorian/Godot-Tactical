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
	battle.move_range = battle.grid.compute_move_range(unit.grid_pos, unit.unit_data.get_mov(), unit.unit_data.team, unit.unit_data.get_movement_type())
	battle.grid.clear_highlight()
	battle.show_unit_range(unit, battle.move_range)
	SignalBus.move_range_shown.emit(battle.move_range)
	battle.ui.show_cancel_move()

func exit() -> void:
	battle.ui.hide_cancel_move()

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
	battle.execute_attack(mover, unit)
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
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
