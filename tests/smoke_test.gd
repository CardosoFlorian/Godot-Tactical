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

const MAX_WAIT_FRAMES := 1200  # ~20s at 60fps; bumped from 600 once StartTurnState started awaiting a real ~1s phase banner on every transition (see BattleHUD.play_player/enemy_phase_banner) — a bounded safety net, never an infinite hang.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== Tactical RPG smoke test ===")
	var ok := true
	ok = _test_battle_build() and ok
	ok = await _test_full_turn_flow() and ok
	ok = _test_combat_resolution() and ok
	ok = _test_prep_phase_build() and ok
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

	if battle.player_units.size() != 4:
		printerr("FAIL: expected 4 player units, got ", battle.player_units.size())
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

	# StartTurnState now awaits the Player Phase banner (BattleHUD.
	# play_player_phase_banner) before entering unit_select — real behavior,
	# not a bug (units must not be actionable while the banner is up), but
	# it means the state machine genuinely isn't in unit_select the instant
	# the battle is created anymore. Wait for it, bounded, same pattern the
	# enemy-phase-to-player-phase wait below already uses.
	var start_frames := 0
	while sm.current_state_name != "unit_select":
		await process_frame
		start_frames += 1
		if start_frames > MAX_WAIT_FRAMES:
			printerr("FAIL: timed out waiting for the initial Player Phase banner to finish")
			ok = false
			break

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

## PrepPhase (scenes/prep/PrepPhase.gd) is a camp-menu scene with several
## @onready node-path refs across PrepPhase/UnitsScreen/ConvoyScreen/
## RosterCard — per the standing headless-verification convention,
## --editor --quit alone won't catch a wrong $Path here (only real scene
## instantiation does). Seeds GameState.player_roster directly (rather than
## going through CampaignFlow.start_campaign, which also kicks off dialogue/
## battle steps this test has no interest in) with 2 duplicated units, then
## drives PrepPhase's auto-placement, its Unités/Inventaire subscreens, the
## squad-toggle round trip, and the final Combattre! confirm — all by
## calling the same internal handlers the UI buttons call.
##
## Looked up via root.get_node("GameState") rather than the bare GameState
## identifier — same reason locals aren't statically typed as Battle/UnitData
## elsewhere in this file (see the header comment): this entry script
## compiles before autoloads are registered as resolvable global
## identifiers, so a direct GameState reference fails to even compile, let
## alone run — Battle.gd itself can reference GameState by name fine since
## it's a different script, compiled later (once load() actually runs it).
func _test_prep_phase_build() -> bool:
	var ok := true
	var game_state = root.get_node("GameState")
	game_state.player_roster.clear()
	var aurora = load("res://data/units/aurora.tres").duplicate()
	var lycith = load("res://data/units/lycith.tres").duplicate()
	game_state.add_unit(aurora)
	game_state.add_unit(lycith)

	var prep_scene: PackedScene = load("res://scenes/prep/PrepPhase.tscn")
	var prep = prep_scene.instantiate()
	prep.map_data = load("res://data/maps/chapter1.tres")
	root.add_child(prep)

	# Both living units auto-join the squad (cap is 4) and get auto-placed
	# on the map immediately, matching the reference: units already
	# standing in camp, free to be picked up and moved.
	if prep._squad.size() != 2:
		printerr("FAIL: expected both units auto-added to the squad, got ", prep._squad.size())
		ok = false
	if prep._unit_nodes.size() != 2:
		printerr("FAIL: expected both units auto-placed, got ", prep._unit_nodes.size())
		ok = false

	# "Unités" opens the roster+detail screen with one card per living unit.
	prep._on_units_pressed()
	if not prep.units_screen.visible:
		printerr("FAIL: expected UnitsScreen to be visible after pressing Unités")
		ok = false
	if prep.units_screen.roster_list.get_child_count() != 2:
		printerr("FAIL: expected 2 roster cards, got ", prep.units_screen.roster_list.get_child_count())
		ok = false

	# Toggle Lycith out of the squad from there — PrepPhase should drop her
	# placement immediately.
	prep._on_squad_toggled(lycith, false)
	if prep._squad.size() != 1 or prep._squad.has(lycith):
		printerr("FAIL: expected Lycith removed from the squad")
		ok = false
	if prep._unit_nodes.has(lycith):
		printerr("FAIL: expected Lycith's placement cleared after squad removal")
		ok = false
	prep.units_screen.closed.emit()
	if prep.units_screen.visible:
		printerr("FAIL: expected UnitsScreen to close")
		ok = false

	# "Inventaire" opens the convoy screen.
	prep._on_inventory_pressed()
	if not prep.convoy_screen.visible:
		printerr("FAIL: expected ConvoyScreen to be visible after pressing Inventaire")
		ok = false
	prep.convoy_screen.closed.emit()

	# Enemies are pre-spawned on the camp map itself (see _spawn_enemies) so
	# "Observer" has something to hover before combat even starts.
	var enemy_zone_tile := Vector2i(8, 2)  # vex's chapter1.tres spawn position
	if prep.grid.get_occupant(enemy_zone_tile) == null:
		printerr("FAIL: expected an enemy pre-spawned on the camp map at ", enemy_zone_tile)
		ok = false

	# "Observer" hides the menu behind a Retour button and enables hover
	# stat previews for both allies and enemies (see PrepPhase._process).
	prep._on_observe_pressed()
	if not prep._observing or prep.menu_panel.visible or not prep.back_button.visible:
		printerr("FAIL: expected Observer mode to hide the menu and show Retour")
		ok = false
	prep._on_back_pressed()
	if prep._observing or not prep.menu_panel.visible or prep.back_button.visible:
		printerr("FAIL: expected Retour to restore the normal camp menu")
		ok = false

	# "Combattre !" emits the final placements for whoever's still in the squad.
	var got_deployment := [null]
	prep.prep_confirmed.connect(func(d): got_deployment[0] = d)
	prep._on_fight_pressed()

	if got_deployment[0] == null or got_deployment[0].size() != 1 or not got_deployment[0].has(aurora):
		printerr("FAIL: prep_confirmed didn't carry the expected single-unit placement")
		ok = false

	prep.queue_free()
	game_state.player_roster.clear()
	return ok
