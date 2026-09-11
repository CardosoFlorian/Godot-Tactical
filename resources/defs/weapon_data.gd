class_name WeaponData
extends Resource
## Data-driven weapon definition. Instances live as .tres files in data/weapons/.

enum WeaponType { SWORD, LANCE, AXE, BOW, TOME, SCYTHE, GAUNTLET }

## Which support effect a gauntlet applies to an enemy on use (see
## gauntlet_effect below). NONE means "not a support gauntlet" — the default
## for every existing weapon. Each individual gauntlet weapon has exactly one
## effect (e.g. a freezing gauntlet and a knockback gauntlet are two separate
## .tres resources, both WeaponType.GAUNTLET), same "one weapon, one job" as
## debuff_stat above rather than a weapon doing several things at once.
enum GauntletEffect { NONE, FREEZE, KNOCKBACK }

## Which stat a weapon's on-hit debuff (see debuff_amount below) lowers.
## NONE means "this weapon has no debuff" — the default for every existing
## weapon, so nothing changes for them.
enum DebuffStat { NONE, STR, MAG, SKL, SPD, LCK, DEF, RES }

## Indexed by DebuffStat — short French stat abbreviations, shared by
## anything that needs to display a debuff (EquipMenuRow's stat line,
## Battle._show_strike_message's floating combat notice) so there's one
## source of truth instead of two copies drifting apart.
const DEBUFF_STAT_LABELS: Array[String] = ["", "FOR", "MAG", "TEC", "VIT", "CHA", "DEF", "RES"]

## Indexed by WeaponType — French names, used wherever a weapon type needs to
## be named in full rather than as an icon (e.g. TechniqueData's hover
## tooltip describing a weapon-conditional technique).
const WEAPON_TYPE_LABELS: Array[String] = ["Épée", "Lance", "Hache", "Arc", "Tome", "Faux", "Gantelet"]

@export var display_name: String = "Weapon"
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var might: int = 5
@export var hit: int = 90
@export var crit: int = 0
@export var weight: int = 5
@export var min_range: int = 1
@export var max_range: int = 1
@export var uses: int = 40
@export var icon: Texture2D

## 0 = a normal weapon. Above 0, this weapon can also target an ally within
## range to restore this much HP instead of attacking — see
## Battle.has_healable_target / HealState. Independent of weapon_type: a
## healing weapon is still just a TOME (e.g. data/weapons/heal_tome.tres),
## not a separate weapon category — any class already allowed to use tomes
## can equip either one, no dedicated "healer" class needed.
@export var heal_amount: int = 0

## 0 = no debuff (default for every existing weapon). Above 0, a landed hit
## with this weapon also lowers the target's debuff_stat by this amount for
## debuff_duration "phase-ends" (see UnitData.apply_debuff / tick_debuffs,
## ticked from Battle._tick_all_status_effects on every phase change, both
## sides) — independent of weapon_type, same "a capability on the weapon,
## not a new class/rule" idea heal_amount already established. First use:
## data/weapons/scythe.tres.
@export_group("Debuff")
@export var debuff_stat: DebuffStat = DebuffStat.NONE
@export var debuff_amount: int = 0
@export var debuff_duration: int = 0

## Support-gauntlet fields — meaningless unless gauntlet_effect != NONE (see
## can_support). Like heal/debuff above, targets an ENEMY instead of an ally
## (see Battle.get_support_targets) and never rolls to hit — always lands,
## same as Heal. `freeze_duration`: turns of movement lock (see
## UnitData.apply_freeze) — the frozen unit can still act/attack from
## wherever it's standing, it just can't reach anywhere else that turn (see
## Battle.get_move_range). `knockback_distance`: tiles pushed directly away
## from the user, stopping early at the last free tile if something (a
## wall, another unit, the map edge) blocks the rest of the push — see
## Battle._apply_knockback.
@export_group("Gauntlet support")
@export var gauntlet_effect: GauntletEffect = GauntletEffect.NONE
@export var freeze_duration: int = 0
@export var knockback_distance: int = 0

func can_heal() -> bool:
	return heal_amount > 0

func can_debuff() -> bool:
	return debuff_stat != DebuffStat.NONE and debuff_amount > 0

func can_support() -> bool:
	return gauntlet_effect != GauntletEffect.NONE

## A support gauntlet is never a combat weapon (see Battle.get_attackable_
## targets_from) — everything else is fair game for Attack even if it also
## has a secondary capability (Scythe still attacks, a heal tome still
## attacks).
func can_attack() -> bool:
	return not can_support()

## Whether this weapon fits the named battle action — used by the weapon-
## picker flow (EquipMenu's for_action filter, WeaponPickerState) to grey
## out/reject inventory items that exist but don't do what the player is
## currently choosing a weapon FOR. Unrecognized/empty action = no filter
## (every weapon matches), same as not picking for any particular action.
func matches_action(action: String) -> bool:
	match action:
		"attack":
			return can_attack()
		"heal":
			return can_heal()
		"support":
			return can_support()
		_:
			return true
