class_name UnitData
extends Resource
## Data-driven unit definition: a specific character (template + persistent
## state). Instances live as .tres files in data/units/. Battle-only runtime
## state (grid position, has_acted...) is NOT here — it lives on the Unit
## scene node in battle/scenes, which holds a reference to a UnitData.

enum Team { PLAYER, ENEMY, ALLY }
enum AIBehavior { NONE, AGGRESSIVE, DEFENSIVE }

## Classic GBA Fire Emblem inventory cap. Not enforced anywhere yet — there's
## no code path that adds a weapon to `inventory` at runtime (no loot/shop
## system), so nothing can currently exceed it. Documented here now so
## whatever eventually adds items has a real constant to check against
## instead of a number invented on the spot later.
const MAX_INVENTORY_SIZE := 5

## No more class promotion resetting a character's level — see
## can_use_weapon/gain_exp below — so this covers a unit's whole arc.
const MAX_LEVEL := 30

## First-pass XP numbers, same "tune after seeing it in real play" spirit as
## every other combat formula in this project (weapon might/hit, debuff
## amounts...) — see gain_exp.
const EXP_TO_LEVEL := 100
const EXP_BASE := 20
const EXP_LEVEL_DIFF_MULT := 2
const EXP_MIN := 1
const EXP_MAX := 40
const EXP_KILL_BONUS := 20

@export var character_id: String = ""
@export var display_name: String = "Unit"
## Shared-template stats for a class of interchangeable units (regular
## enemies — Bandit, Soldat...). null means this unit carries its OWN stats
## instead (every playable character, and any future boss) — see the
## "Individual stats" group below and can_use_weapon/get_class_display_name,
## which both branch on this exact same null check.
@export var character_class: ClassData
@export var level: int = 1
@export var team: Team = Team.PLAYER
@export var permadeath: bool = true

@export_group("Individual stats (used when character_class is null)")
## Shown in the UI in place of character_class.display_name — see
## get_class_display_name. Purely cosmetic (e.g. "Mage"), no longer a real
## resource driving weapons/stats for these units.
@export var class_display_name: String = ""
@export var movement_type: ClassData.MovementType = ClassData.MovementType.INFANTRY
@export var usable_weapon_types: Array[WeaponData.WeaponType] = []
@export var exp: int = 0
@export var base_hp: int = 20
@export var base_str: int = 5
@export var base_mag: int = 0
@export var base_skl: int = 5
@export var base_spd: int = 5
@export var base_lck: int = 5
@export var base_def: int = 5
@export var base_res: int = 5
@export var base_con: int = 8
@export var base_mov: int = 5
## Still a %, but rolled RANDOMLY per level-up now (see gain_exp) — real
## Fire Emblem style, unlike ClassData's deterministic _growth_bonus formula
## (which enemies keep unchanged; they never show a level-up reveal).
@export var growth_hp: int = 70
@export var growth_str: int = 40
@export var growth_mag: int = 0
@export var growth_skl: int = 40
@export var growth_spd: int = 40
@export var growth_lck: int = 30
@export var growth_def: int = 30
@export var growth_res: int = 20
@export var growth_con: int = 0
## Engine-only for now — every playable character ships this empty. Which
## technique, for which character, at which level is real per-character
## creative design, not invented here. See TechniqueData and gain_exp.
@export var techniques: Array[TechniqueData] = []

## Max simultaneously-active conditional techniques — see
## TechniqueData.is_conditional and equipped_techniques below. First-pass
## number, same "tune after seeing it in play" spirit as everything else.
const MAX_EQUIPPED_TECHNIQUES := 3

## Subset of `techniques` (always already-learned and is_conditional() —
## see equip_technique) currently active. A conditional technique granted
## while a slot is free auto-equips itself (see _grant_technique_if_due) so
## it isn't dead on arrival before the user builds a real equip-swap UI;
## once full, a newly learned one stays merely learned until manually
## equipped. A non-conditional technique (permanent stat bump, weapon
## unlock, movement change) is never in this list at all — it doesn't need
## a slot, it's just always on.
@export var equipped_techniques: Array[TechniqueData] = []

@export_group("Equipment")
@export var inventory: Array[WeaponData] = []
## Custom setter keeps last_combat_equipped_index in sync automatically,
## from every source (EquipMenuState, Battle.revert_equipped_weapon,
## promote, .tres loading) without each call site needing to remember to —
## see last_combat_equipped_index below for why that index exists.
@export var equipped_index: int = 0:
	set(value):
		equipped_index = value
		if value >= 0 and value < inventory.size() and not inventory[value].can_support():
			last_combat_equipped_index = value

## Battle-only (like active_debuffs/frozen_turns_remaining below), not
## @export. Index into inventory of the last REAL attack weapon (one where
## can_support() is false) this unit had equipped. A pure support gauntlet
## can't fight back with — see get_combat_weapon() below and CombatResolver,
## which uses it instead of get_equipped_weapon() for counter-attacks, same
## as Fire Emblem Engage has a staff-user counter with their last real
## weapon instead of the staff. Defaults to 0 since every unit's starting
## inventory slot 0 is a real weapon; Unit.setup() re-derives it properly
## from the unit's actual starting equipped_index regardless, as a safety
## net against .tres property-load ordering.
var last_combat_equipped_index: int = 0

@export_group("Portraits & sprites")
@export var portrait: Texture2D
## Shown on the level-up screen (see LevelUpScreen) — null for a unit that
## never levels up on-screen (regular enemies).
@export var full_body: Texture2D
@export var battle_sprite: Texture2D
## Optional cutout-rig battle sprite (idle/attack animations). When set,
## Unit.gd instances this instead of drawing battle_sprite as a static
## Sprite2D. Most units don't have one yet and just fall back to the plain
## texture above.
@export var rigged_battle_sprite: PackedScene

@export_group("Enemy AI (ignored for player units)")
@export var ai_behavior: AIBehavior = AIBehavior.AGGRESSIVE
## How far (in tiles) an enemy will move to engage before giving up and holding position.
@export var ai_aggro_range: int = 99

var current_hp: int = -1  # -1 means "not initialized yet", see get_current_hp()

## Battle-only runtime state, deliberately NOT @export (unlike current_hp,
## which intentionally persists between battles — a debuff should not).
## Each entry: {"weapon": WeaponData, "turns_remaining": int} — keyed by the
## WEAPON RESOURCE itself (not the attacker) rather than storing a copy of
## stat/amount, so REFRESHING (see apply_debuff) can recognize "the same
## weapon hit again" regardless of which unit swung it: Godot caches one
## shared Resource instance per .tres path, so two different units with the
## same scythe.tres in their inventory really do reference the identical
## object, and `==` between them is true. Cleared on battle entry (see
## Unit.setup) as a safety net in case a unit somehow re-enters battle still
## carrying one.
var active_debuffs: Array[Dictionary] = []

## Refreshes (not stacks) if this exact weapon already has an active debuff
## here — reset the duration back to full rather than adding a second entry
## on top. Deliberately NOT keyed by stat alone: two DIFFERENT debuff
## weapons hitting the same stat are still two distinct threats and both
## apply, only genuinely the same weapon (e.g. a double-attack landing both
## hits, or two units who happen to share the same scythe) refreshes instead
## of stacking — user's own call, to stop a fast attacker's own double hit
## (or repeated counters over several turns) from snowballing a stat to
## -10+ with no cap. First use: data/weapons/scythe.tres via CombatResolver.
func apply_debuff(weapon: WeaponData) -> void:
	for debuff in active_debuffs:
		if debuff["weapon"] == weapon:
			debuff["turns_remaining"] = weapon.debuff_duration
			return
	active_debuffs.append({"weapon": weapon, "turns_remaining": weapon.debuff_duration})

## Decrements every active debuff by one turn and drops any that expire —
## called once per unit at the start of ITS OWN turn (see Unit.start_new_turn),
## same "ticks on the affected unit's own turn" convention real Fire Emblem
## status effects use.
func tick_debuffs() -> void:
	var remaining: Array[Dictionary] = []
	for debuff in active_debuffs:
		debuff["turns_remaining"] -= 1
		if debuff["turns_remaining"] > 0:
			remaining.append(debuff)
	active_debuffs = remaining

## First code path that actually moves an item between inventories at
## runtime (see MAX_INVENTORY_SIZE above) — used by the prep phase's convoy
## screen. Returns false (no-op) if `target` is already full. Only appends
## to target (doesn't auto-equip it — handing off gear shouldn't silently
## change what the receiving unit fights with); re-clamps THIS unit's own
## equipped_index through its setter (so last_combat_equipped_index stays in
## sync, same as every other equip-changing call site) since the source
## array just shrank and the old index may no longer be valid.
func transfer_weapon_to(target: UnitData, index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	if target.inventory.size() >= MAX_INVENTORY_SIZE:
		return false
	var weapon: WeaponData = inventory[index]
	inventory.remove_at(index)
	target.inventory.append(weapon)
	if equipped_index >= inventory.size():
		equipped_index = maxi(0, inventory.size() - 1)
	return true

## Public (not the usual leading-underscore "internal" convention) since
## UnitInfoPanel needs this too, to show a debuffed stat in red.
func get_debuff_total(stat: WeaponData.DebuffStat) -> int:
	var total := 0
	for debuff in active_debuffs:
		var weapon: WeaponData = debuff["weapon"]
		if weapon.debuff_stat == stat:
			total += weapon.debuff_amount
	return total

## Battle-only, like active_debuffs above (cleared on battle entry, not
## @export). Boolean in effect — reapplying just resets the clock rather
## than stacking duration, same refresh idea active_debuffs uses, just
## simpler since there's no magnitude to track per-source, only "frozen or
## not". Blocks movement only (see Battle.get_move_range) — a frozen unit
## can still attack from wherever it's standing, per the user's own call.
var frozen_turns_remaining: int = 0

func apply_freeze(duration: int) -> void:
	frozen_turns_remaining = duration

func tick_freeze() -> void:
	frozen_turns_remaining = maxi(0, frozen_turns_remaining - 1)

func is_frozen() -> bool:
	return frozen_turns_remaining > 0

## Whether this unit is allowed to equip `weapon_type` — delegates to the
## shared class for a template unit, or this unit's OWN list otherwise. The
## single chokepoint every weapon-usability check in the project should call
## (Battle.gd, EquipMenu, UnitInfoPanel, WeaponPickerState...) instead of
## reaching into character_class directly, now that there are two different
## sources of truth depending on the unit.
func can_use_weapon(weapon_type: WeaponData.WeaponType) -> bool:
	return character_class.can_use_weapon(weapon_type) if character_class else usable_weapon_types.has(weapon_type)

## "Mage", "Brigand"... — character_class's own display_name for a template
## unit, or this unit's cosmetic class_display_name otherwise (no longer a
## real resource for these, see the "Individual stats" export group).
func get_class_display_name() -> String:
	return character_class.display_name if character_class else class_display_name

## Returns null (treated as unarmed) if the inventory is empty OR the
## equipped weapon isn't one this unit is allowed to use — classes are
## locked old-school-Fire-Emblem style, so this is real enforcement, not
## just a data hint.
func get_equipped_weapon() -> WeaponData:
	if inventory.is_empty():
		return null
	var weapon := inventory[clampi(equipped_index, 0, inventory.size() - 1)]
	if weapon and not can_use_weapon(weapon.weapon_type):
		push_warning("%s's class (%s) can't use %s — treating as unarmed." % [display_name, get_class_display_name(), weapon.display_name])
		return null
	return weapon

## What this unit actually fights with — the equipped weapon normally, but
## the last REAL attack weapon (see last_combat_equipped_index) if what's
## currently equipped is a non-combat support gauntlet. CombatResolver uses
## this instead of get_equipped_weapon() everywhere, so a unit caught
## defending with a gauntlet equipped still counters with whatever it last
## had in hand instead of being unable to fight back at all (or "attacking"
## with a 0-might glove).
func get_combat_weapon() -> WeaponData:
	var weapon := get_equipped_weapon()
	if weapon == null or not weapon.can_support():
		return weapon
	if last_combat_equipped_index < 0 or last_combat_equipped_index >= inventory.size():
		return null
	return inventory[last_combat_equipped_index]

## Deterministic growth curve — ONLY for a character_class != null unit
## (regular enemies). A character_class == null unit's stats are rolled
## randomly per level-up instead (see gain_exp) and read straight off its
## own base_X fields, no formula involved.
func _growth_bonus(growth_percent: int) -> int:
	return int(float(growth_percent) / 100.0 * float(level - 1))

func get_max_hp() -> int:
	if character_class == null:
		return base_hp
	return character_class.base_hp + _growth_bonus(character_class.growth_hp)

func get_current_hp() -> int:
	if current_hp < 0:
		current_hp = get_max_hp()
	return current_hp

func set_current_hp(value: int) -> void:
	current_hp = clampi(value, 0, get_max_hp())

func is_alive() -> bool:
	return get_current_hp() > 0

func get_str() -> int:
	var base := character_class.base_str + _growth_bonus(character_class.growth_str) if character_class else base_str
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.STR))

func get_mag() -> int:
	var base := character_class.base_mag + _growth_bonus(character_class.growth_mag) if character_class else base_mag
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.MAG))

func get_skl() -> int:
	var base := character_class.base_skl + _growth_bonus(character_class.growth_skl) if character_class else base_skl
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.SKL))

func get_spd() -> int:
	var base := character_class.base_spd + _growth_bonus(character_class.growth_spd) if character_class else base_spd
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.SPD))

func get_lck() -> int:
	var base := character_class.base_lck + _growth_bonus(character_class.growth_lck) if character_class else base_lck
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.LCK))

func get_def() -> int:
	var base := character_class.base_def + _growth_bonus(character_class.growth_def) if character_class else base_def
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.DEF))

func get_res() -> int:
	var base := character_class.base_res + _growth_bonus(character_class.growth_res) if character_class else base_res
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.RES))

func get_con() -> int:
	return character_class.base_con + _growth_bonus(character_class.growth_con) if character_class else base_con

func get_mov() -> int:
	return character_class.base_mov if character_class else base_mov

func get_movement_type() -> ClassData.MovementType:
	return character_class.movement_type if character_class else movement_type

## Adds `amount` XP, resolving any level-ups that cross EXP_TO_LEVEL. No-op
## (empty return) for a character_class != null unit — regular enemies keep
## their deterministic growth and never level up mid-battle — or once
## MAX_LEVEL is already reached. Returns one result dict per level actually
## gained: {"level": int, "stat_gains": Dictionary[String, int] (only stats
## that rolled up are present, value always 1), "technique": TechniqueData
## or null} — a big XP grant crossing 2 thresholds yields 2 entries, so
## Battle.gd can show the level-up screen once per level in sequence, same
## as a real multi-level-up plays out one reveal at a time rather than
## folding straight to the end result.
func gain_exp(amount: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if character_class != null:
		return results
	exp += amount
	while exp >= EXP_TO_LEVEL and level < MAX_LEVEL:
		exp -= EXP_TO_LEVEL
		level += 1
		var stat_gains := _roll_level_up_stats()
		var technique := _grant_technique_if_due()
		results.append({"level": level, "stat_gains": stat_gains, "technique": technique})
	if level >= MAX_LEVEL:
		exp = 0
	return results

## Real Fire Emblem style: each growth_X is a genuine per-stat coin-flip
## rolled fresh this level (unlike _growth_bonus's deterministic curve,
## which stays untouched for character_class != null units) — the whole
## reason a level-up screen exists is to reveal this roll. A HP gain also
## heals current_hp by the same amount (real FE behavior: leveling up isn't
## just a bigger max, it restores the difference too), guarded on
## current_hp already being initialized so this can't create a negative
## "phantom heal" before the unit's first get_current_hp() call.
func _roll_level_up_stats() -> Dictionary:
	var gains := {}
	if randf() * 100.0 < growth_hp:
		base_hp += 1
		if current_hp >= 0:
			current_hp += 1
		gains["hp"] = 1
	if randf() * 100.0 < growth_str:
		base_str += 1
		gains["str"] = 1
	if randf() * 100.0 < growth_mag:
		base_mag += 1
		gains["mag"] = 1
	if randf() * 100.0 < growth_skl:
		base_skl += 1
		gains["skl"] = 1
	if randf() * 100.0 < growth_spd:
		base_spd += 1
		gains["spd"] = 1
	if randf() * 100.0 < growth_lck:
		base_lck += 1
		gains["lck"] = 1
	if randf() * 100.0 < growth_def:
		base_def += 1
		gains["def"] = 1
	if randf() * 100.0 < growth_res:
		base_res += 1
		gains["res"] = 1
	if randf() * 100.0 < growth_con:
		base_con += 1
		gains["con"] = 1
	return gains

## Applies whichever technique (if any) in `techniques` requires exactly
## this unit's new `level` — see TechniqueData. At most one per level;
## multiple techniques sharing a level_required would only ever grant the
## first found, not expected to come up given the ~5-level cadence but not
## enforced here either.
func _grant_technique_if_due() -> TechniqueData:
	for technique in techniques:
		if technique.level_required != level:
			continue
		match technique.type:
			TechniqueData.TechniqueType.STAT_BUFF:
				_apply_stat_buff(technique.stat, technique.stat_amount)
				if technique.stat2 != WeaponData.DebuffStat.NONE:
					_apply_stat_buff(technique.stat2, technique.stat2_amount)
				if technique.hp_bonus != 0:
					base_hp += technique.hp_bonus
					if current_hp >= 0:
						current_hp += technique.hp_bonus
			TechniqueData.TechniqueType.WEAPON_UNLOCK:
				if not usable_weapon_types.has(technique.weapon_type):
					usable_weapon_types.append(technique.weapon_type)
			TechniqueData.TechniqueType.MOVEMENT_CHANGE:
				movement_type = technique.new_movement_type
			TechniqueData.TechniqueType.PASSIVE:
				pass  # data placeholder only — see TechniqueData
			TechniqueData.TechniqueType.COMBAT_BONUS:
				pass  # nothing to apply at grant time — checked live by CombatResolver instead, see TechniqueData
		# Auto-equip a freshly-learned conditional technique into any open
		# slot — see equipped_techniques doc. A STAT_BUFF like Cœur de
		# Souveraine still reaches here (is_conditional() checks its OWN
		# post_combat_heal_percent_of_max, not `type`) even though its HP+3
		# was already applied unconditionally above.
		if technique.is_conditional() and equipped_techniques.size() < MAX_EQUIPPED_TECHNIQUES:
			equipped_techniques.append(technique)
		return technique
	return null

## Whether `technique` is currently equipped (one of this unit's active
## conditional techniques) — see equipped_techniques doc. Meaningless (and
## always false) for a non-conditional technique, which is never in the list.
func is_technique_equipped(technique: TechniqueData) -> bool:
	return equipped_techniques.has(technique)

## Equips `technique` — must already be learned (in `techniques`, its
## level_required already reached) and conditional (see
## TechniqueData.is_conditional; a permanent technique has no slot to
## occupy). `replacing`, if given, is unequipped first so a UI swap is one
## call instead of unequip-then-equip. Returns false (no-op) if `technique`
## isn't eligible, or the cap is already full and no `replacing` was given.
func equip_technique(technique: TechniqueData, replacing: TechniqueData = null) -> bool:
	if not technique.is_conditional() or not techniques.has(technique) or technique.level_required > level:
		return false
	if equipped_techniques.has(technique):
		return true
	if replacing != null:
		equipped_techniques.erase(replacing)
	if equipped_techniques.size() >= MAX_EQUIPPED_TECHNIQUES:
		return false
	equipped_techniques.append(technique)
	return true

func unequip_technique(technique: TechniqueData) -> void:
	equipped_techniques.erase(technique)

func _apply_stat_buff(stat: WeaponData.DebuffStat, amount: int) -> void:
	match stat:
		WeaponData.DebuffStat.STR:
			base_str += amount
		WeaponData.DebuffStat.MAG:
			base_mag += amount
		WeaponData.DebuffStat.SKL:
			base_skl += amount
		WeaponData.DebuffStat.SPD:
			base_spd += amount
		WeaponData.DebuffStat.LCK:
			base_lck += amount
		WeaponData.DebuffStat.DEF:
			base_def += amount
		WeaponData.DebuffStat.RES:
			base_res += amount
