class_name CombatResolver
extends RefCounted
## Pure combat math (GBA Fire Emblem-inspired formulas) + full combat
## resolution. Kept side-effect free (aside from applying HP changes to the
## UnitData passed in) so the same functions serve both real combat
## resolution and enemy AI prediction/scoring.

const DOUBLE_ATTACK_SPD_THRESHOLD := 4
const CRIT_DAMAGE_MULTIPLIER := 3

static func _triangle_mods(attacker: UnitData, defender: UnitData) -> Dictionary:
	var atk_weapon := attacker.get_equipped_weapon()
	var def_weapon := defender.get_equipped_weapon()
	if atk_weapon == null or def_weapon == null:
		return {"hit": 0, "might": 0}
	return WeaponTriangle.get_modifiers(atk_weapon.weapon_type, def_weapon.weapon_type)

static func get_hit_chance(attacker: UnitData, defender: UnitData, terrain_avoid_bonus: int = 0) -> int:
	var weapon := attacker.get_equipped_weapon()
	if weapon == null:
		return 0
	var mods := _triangle_mods(attacker, defender)
	var attack_hit := weapon.hit + attacker.get_skl() * 2 + attacker.get_lck() / 2 + int(mods["hit"])
	var avoid := defender.get_spd() * 2 + defender.get_lck() + terrain_avoid_bonus
	return clampi(attack_hit - avoid, 0, 100)

static func get_crit_chance(attacker: UnitData, defender: UnitData) -> int:
	var weapon := attacker.get_equipped_weapon()
	if weapon == null:
		return 0
	var crit := weapon.crit + attacker.get_skl() / 2 - defender.get_lck()
	return clampi(crit, 0, 100)

static func get_damage(attacker: UnitData, defender: UnitData, terrain_def_bonus: int = 0) -> int:
	var weapon := attacker.get_equipped_weapon()
	if weapon == null:
		return 0
	var mods := _triangle_mods(attacker, defender)
	var attack_power := attacker.get_str() + weapon.might + int(mods["might"])
	var defense := defender.get_def() + terrain_def_bonus
	return maxi(0, attack_power - defense)

static func can_double(attacker: UnitData, defender: UnitData) -> bool:
	return attacker.get_spd() >= defender.get_spd() + DOUBLE_ATTACK_SPD_THRESHOLD

static func is_in_weapon_range(distance: int, weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	return distance >= weapon.min_range and distance <= weapon.max_range

## Expected-value prediction used by the enemy AI to score actions without
## rolling any RNG: expected_damage accounts for hit% and crit%, and for a
## potential follow-up hit if the attacker doubles.
static func predict_expected_damage(attacker: UnitData, defender: UnitData, terrain_def_bonus: int = 0, terrain_avoid_bonus: int = 0) -> float:
	if attacker.get_equipped_weapon() == null:
		return 0.0
	var hit := get_hit_chance(attacker, defender, terrain_avoid_bonus) / 100.0
	var crit := get_crit_chance(attacker, defender) / 100.0
	var base_dmg := get_damage(attacker, defender, terrain_def_bonus)
	var crit_dmg := base_dmg * CRIT_DAMAGE_MULTIPLIER
	var expected_per_hit := hit * (crit * crit_dmg + (1.0 - crit) * base_dmg)
	var hits := 2.0 if can_double(attacker, defender) else 1.0
	return expected_per_hit * hits

## Resolves a full combat exchange (attacker strike(s), then defender
## counter-strike(s) if alive and in range), applying HP changes directly to
## the UnitData resources. `attacker_terrain`/`defender_terrain` are
## {"def": int, "avoid": int} bonuses from the tile each unit is standing on
## (see BattleGrid/TerrainData) applied whenever that unit is the one being
## struck. Returns a log of individual strikes for UI/replay.
static func resolve_combat(attacker: UnitData, defender: UnitData, distance: int, rng: RandomNumberGenerator, attacker_terrain: Dictionary = {}, defender_terrain: Dictionary = {}) -> Dictionary:
	var log: Array[Dictionary] = []
	var defender_weapon := defender.get_equipped_weapon()
	var defender_can_counter := is_in_weapon_range(distance, defender_weapon)

	var order: Array[Dictionary] = []
	var attacker_hits := 2 if can_double(attacker, defender) else 1
	for i in attacker_hits:
		order.append({"source": attacker, "target": defender, "terrain": defender_terrain})
	if defender_can_counter:
		var defender_hits := 2 if can_double(defender, attacker) else 1
		for i in defender_hits:
			order.append({"source": defender, "target": attacker, "terrain": attacker_terrain})

	for strike in order:
		var source: UnitData = strike["source"]
		var target: UnitData = strike["target"]
		var terrain: Dictionary = strike["terrain"]
		var terrain_def: int = terrain.get("def", 0)
		var terrain_avoid: int = terrain.get("avoid", 0)
		if not source.is_alive() or not target.is_alive():
			continue
		if source.get_equipped_weapon() == null:
			continue
		var hit_chance := get_hit_chance(source, target, terrain_avoid)
		var roll := rng.randi_range(1, 100)
		var did_hit := roll <= hit_chance
		var did_crit := false
		var damage := 0
		if did_hit:
			var crit_chance := get_crit_chance(source, target)
			did_crit = rng.randi_range(1, 100) <= crit_chance
			damage = get_damage(source, target, terrain_def)
			if did_crit:
				damage *= CRIT_DAMAGE_MULTIPLIER
			target.set_current_hp(target.get_current_hp() - damage)
		log.append({
			"source": source,
			"target": target,
			"hit": did_hit,
			"crit": did_crit,
			"damage": damage,
			"target_hp_after": target.get_current_hp(),
		})
		if not target.is_alive():
			break

	return {
		"log": log,
		"attacker_survived": attacker.is_alive(),
		"defender_survived": defender.is_alive(),
	}
