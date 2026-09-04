class_name MoveState
extends BattleState
## Shows the selected unit's movement range and handles confirming a move.
## Range comes from BattleGrid.compute_move_range (Dijkstra flood-fill); the
## actual path walked comes from BattleGrid.get_path (native AStarGrid2D).

func enter(_previous_state_name: String = "") -> void:
	var unit := battle.selected_unit
	battle.move_range = battle.grid.compute_move_range(unit.grid_pos, unit.unit_data.get_mov(), unit.unit_data.team)
	battle.grid.clear_highlight()
	var tiles: Array[Vector2i] = []
	tiles.assign(battle.move_range.keys())
	battle.grid.show_highlight(tiles, battle.grid.HIGHLIGHT_MOVE)
	SignalBus.move_range_shown.emit(battle.move_range)

func handle_tile_clicked(pos: Vector2i) -> void:
	if not battle.move_range.has(pos):
		return
	var unit := battle.selected_unit
	var old_pos := unit.grid_pos
	var path := battle.grid.find_path(old_pos, pos, unit.unit_data.team)
	battle.grid.clear_occupant(old_pos)
	battle.grid.clear_highlight()
	if path.size() > 1:
		await unit.move_along_path(path, battle.grid)
	unit.grid_pos = pos
	unit.has_moved = true
	battle.grid.set_occupant(pos, unit)
	SignalBus.move_confirmed.emit(unit, path)
	state_machine.change_state("action_menu")

func handle_unit_clicked(unit: Unit) -> void:
	if unit == battle.selected_unit:
		handle_tile_clicked(unit.grid_pos)

func handle_cancel() -> void:
	state_machine.change_state("unit_select")
