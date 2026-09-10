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

@export var character_id: String = ""
@export var display_name: String = "Unit"
@export var character_class: ClassData
@export var level: int = 1
@export var team: Team = Team.PLAYER
@export var permadeath: bool = true

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

## Returns null (treated as unarmed) if the inventory is empty OR the
## equipped weapon isn't one this class is allowed to use — classes are
## locked old-school-Fire-Emblem style, so this is real enforcement, not
## just a data hint.
func get_equipped_weapon() -> WeaponData:
	if inventory.is_empty() or character_class == null:
		return null
	var weapon := inventory[clampi(equipped_index, 0, inventory.size() - 1)]
	if weapon and not character_class.can_use_weapon(weapon.weapon_type):
		push_warning("%s's class (%s) can't use %s — treating as unarmed." % [display_name, character_class.display_name, weapon.display_name])
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

func _growth_bonus(growth_percent: int) -> int:
	return int(float(growth_percent) / 100.0 * float(level - 1))

func get_max_hp() -> int:
	if character_class == null:
		return 1
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
	var base := character_class.base_str + _growth_bonus(character_class.growth_str) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.STR))

func get_mag() -> int:
	var base := character_class.base_mag + _growth_bonus(character_class.growth_mag) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.MAG))

func get_skl() -> int:
	var base := character_class.base_skl + _growth_bonus(character_class.growth_skl) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.SKL))

func get_spd() -> int:
	var base := character_class.base_spd + _growth_bonus(character_class.growth_spd) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.SPD))

func get_lck() -> int:
	var base := character_class.base_lck + _growth_bonus(character_class.growth_lck) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.LCK))

func get_def() -> int:
	var base := character_class.base_def + _growth_bonus(character_class.growth_def) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.DEF))

func get_res() -> int:
	var base := character_class.base_res + _growth_bonus(character_class.growth_res) if character_class else 0
	return maxi(0, base - get_debuff_total(WeaponData.DebuffStat.RES))

func get_con() -> int:
	return character_class.base_con + _growth_bonus(character_class.growth_con) if character_class else 0

func get_mov() -> int:
	return character_class.base_mov if character_class else 1

func get_movement_type() -> ClassData.MovementType:
	return character_class.movement_type if character_class else ClassData.MovementType.INFANTRY

## Old-school Fire Emblem promotion: fixed target class, no player choice.
## For now gated on level only (see ClassData.promotion_level) — a
## promotion item requirement is planned but there's no inventory/item
## system yet to hang it on.
func can_promote() -> bool:
	return character_class != null and character_class.promoted_class != null and level >= character_class.promotion_level

func promote() -> void:
	if not can_promote():
		return
	character_class = character_class.promoted_class
	level = 1
	current_hp = get_max_hp()
