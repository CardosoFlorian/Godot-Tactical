class_name EnemyAI
extends RefCounted
## Utility-based enemy AI: for the acting unit, scores every
## (reachable tile, attackable target) pair by predicted damage dealt minus
## predicted damage taken (with a kill bonus), and executes the best one.
## Falls back to closing distance on the nearest player unit if no attack
## is available. Intentionally simple — the brief calls for refining this
## later rather than starting complex.

const RISK_WEIGHT := 0.6
const KILL_BONUS := 30.0

static func take_turn(unit: Unit, battle: Battle) -> void:
	var data := unit.unit_data
	var reachable: Dictionary = battle.grid.compute_move_range(unit.grid_pos, data.get_mov(), data.team, data.get_movement_type())

	var best_tile: Vector2i = unit.grid_pos
	var best_target: Unit = null
	var best_score := -INF

	for tile in reachable.keys():
		var targets := battle.get_attackable_targets_from(tile, unit)
		for target in targets:
			var target_terrain := battle.grid.get_terrain_combat_bonus(target.grid_pos)
			var expected_dealt := CombatResolver.predict_expected_damage(data, target.unit_data, target_terrain["def"], target_terrain["avoid"])
			var distance := absi(tile.x - target.grid_pos.x) + absi(tile.y - target.grid_pos.y)
			var expected_taken := 0.0
			if CombatResolver.is_in_weapon_range(distance, target.unit_data.get_equipped_weapon()):
				var my_terrain := battle.grid.get_terrain_combat_bonus(tile)
				expected_taken = CombatResolver.predict_expected_damage(target.unit_data, data, my_terrain["def"], my_terrain["avoid"])
			var score := expected_dealt - expected_taken * RISK_WEIGHT
			if expected_dealt >= target.unit_data.get_current_hp():
				score += KILL_BONUS
			if score > best_score:
				best_score = score
				best_tile = tile
				best_target = target

	if best_target != null:
		await _move_unit(unit, battle, best_tile)
		if not is_instance_valid(unit) or not unit.unit_data.is_alive():
			return
		await _attack(unit, best_target, battle)
	else:
		var approach_tile := _pick_approach_tile(unit, battle, reachable)
		await _move_unit(unit, battle, approach_tile)

	unit.has_moved = true
	unit.has_acted = true

static func _move_unit(unit: Unit, battle: Battle, target_tile: Vector2i) -> void:
	if target_tile == unit.grid_pos:
		return
	var old_pos := unit.grid_pos
	var path := battle.grid.find_path(old_pos, target_tile, unit.unit_data.team, unit.unit_data.get_movement_type())
	battle.grid.clear_occupant(old_pos)
	if path.size() > 1:
		await unit.move_along_path(path, battle.grid)
	unit.grid_pos = target_tile
	battle.grid.set_occupant(target_tile, unit)

## Goes through Battle.execute_attack (rather than calling CombatResolver
## directly, as this used to) so enemy-initiated fights get the same
## combat scene — camera, approach, strike animations — as player ones.
static func _attack(attacker: Unit, target: Unit, battle: Battle) -> void:
	await battle.execute_attack(attacker, target)

## Picks the reachable tile that gets closest to the nearest living player
## unit, without exceeding the unit's aggro range from its starting tile.
static func _pick_approach_tile(unit: Unit, battle: Battle, reachable: Dictionary) -> Vector2i:
	if battle.player_units.is_empty():
		return unit.grid_pos
	var nearest: Unit = battle.player_units[0]
	var nearest_dist := INF
	for player_unit in battle.player_units:
		var d := absi(unit.grid_pos.x - player_unit.grid_pos.x) + absi(unit.grid_pos.y - player_unit.grid_pos.y)
		if d < nearest_dist:
			nearest_dist = d
			nearest = player_unit
	if nearest_dist > unit.unit_data.ai_aggro_range:
		return unit.grid_pos

	var best_tile := unit.grid_pos
	var best_dist: float = nearest_dist
	for tile in reachable.keys():
		var d := absi(tile.x - nearest.grid_pos.x) + absi(tile.y - nearest.grid_pos.y)
		if d < best_dist:
			best_dist = d
			best_tile = tile
	return best_tile
