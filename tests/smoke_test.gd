extends SceneTree
## Headless smoke test: `godot --headless --script res://tests/smoke_test.gd`
## Instantiates Battle.tscn directly (no editor, no rendering) and drives it
## through a real turn (state machine + AStarGrid2D + Dijkstra move-range +
## EnemyAI) to catch integration bugs before opening the editor.
##
## Deliberately avoids static-typing locals as Battle/Unit/UnitData: under
## `--script`, the entry script is compiled before autoloads are attached to
## the tree, and a static type annotation here would force Battle.gd (and
## its GameState-using code) to compile at that same early point and fail to
## resolve the GameState autoload. Untyped locals defer that compilation
## until _run(), which is called deferred, after autoloads exist. This is a
## quirk of this test harness only — the real game boots normally through
## Main.tscn and never hits this ordering issue.

const MAX_WAIT_FRAMES := 600  # ~10s at 60fps; a bounded safety net, never an infinite hang.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== Tactical RPG smoke test ===")
	var ok := true
	ok = _test_battle_build() and ok
	ok = await _test_full_turn_flow() and ok
	ok = _test_combat_resolution() and ok
	print("=== %s ===" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

func _make_battle():
	var battle_scene: PackedScene = load("res://scenes/battle/Battle.tscn")
	var battle = battle_scene.instantiate()
	root.add_child(battle)
	return battle

func _test_battle_build() -> bool:
	var ok := true
	var battle = _make_battle()

	if battle.player_units.size() != 3:
		printerr("FAIL: expected 3 player units, got ", battle.player_units.size())
		ok = false
	if battle.enemy_units.size() != 3:
		printerr("FAIL: expected 3 enemy units, got ", battle.enemy_units.size())
		ok = false

	if not battle.player_units.is_empty():
		var mover = battle.player_units[0]

		var move_range: Dictionary = battle.grid.compute_move_range(mover.grid_pos, mover.unit_data.get_mov(), mover.unit_data.team)
		if move_range.is_empty():
			printerr("FAIL: move range should not be empty")
			ok = false
		elif not move_range.has(mover.grid_pos):
			printerr("FAIL: move range should include the unit's own tile")
			ok = false

		var far_tile := Vector2i(9, 7)
		if battle.grid.is_in_bounds(far_tile):
			var path: Array = battle.grid.find_path(mover.grid_pos, far_tile, mover.unit_data.team)
			if path.is_empty():
				printerr("FAIL: expected AStarGrid2D to find a path toward ", far_tile)
				ok = false

	battle.queue_free()
	return ok

## Drives the real BattleStateMachine through a full player phase (each unit
## selected, moved onto its own tile, and told to wait) and into the enemy
## phase, waiting (bounded) for EnemyAI to finish and hand the turn back.
func _test_full_turn_flow() -> bool:
	var ok := true
	var battle = _make_battle()
	var sm = battle.state_machine

	for unit in battle.player_units.duplicate():
		if sm.current_state_name != "unit_select":
			printerr("FAIL: expected unit_select before selecting ", unit.unit_data.display_name, ", got ", sm.current_state_name)
			ok = false
			break
		sm.handle_unit_clicked(unit)
		if sm.current_state_name != "move":
			printerr("FAIL: expected move state after selecting a unit, got ", sm.current_state_name)
			ok = false
			break
		sm.handle_tile_clicked(unit.grid_pos)  # stay put
		if sm.current_state_name != "action_menu":
			printerr("FAIL: expected action_menu state after confirming move, got ", sm.current_state_name)
			ok = false
			break
		sm.handle_action_chosen("wait")

	# After the 3rd wait, unit_select notices everyone acted and ends the
	# player turn, which flows into enemy_phase (EnemyAI runs as a
	# coroutine). Wait for it to hand the turn back to the player.
	var frames := 0
	while not (battle.current_phase == UnitData.Team.PLAYER and sm.current_state_name == "unit_select"):
		await process_frame
		frames += 1
		if frames > MAX_WAIT_FRAMES:
			printerr("FAIL: timed out waiting for the enemy phase to finish")
			ok = false
			break

	battle.queue_free()
	return ok

## Exercises CombatResolver.resolve_combat end-to-end (weapon triangle,
## terrain bonuses, doubling, HP application) without going through the UI.
func _test_combat_resolution() -> bool:
	var ok := true
	var battle = _make_battle()

	if battle.player_units.is_empty() or battle.enemy_units.is_empty():
		battle.queue_free()
		return ok

	var attacker = battle.player_units[0].unit_data
	var defender = battle.enemy_units[0].unit_data
	var hp_before: int = defender.get_current_hp()

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var result: Dictionary = CombatResolver.resolve_combat(attacker, defender, 1, rng, {"def": 0, "avoid": 0}, {"def": 0, "avoid": 0})

	if not result.has("log") or result["log"].is_empty():
		printerr("FAIL: resolve_combat produced an empty log")
		ok = false
	if defender.get_current_hp() > hp_before:
		printerr("FAIL: defender HP increased from combat, should only decrease or stay the same")
		ok = false

	battle.queue_free()
	return ok
