class_name WeaponData
extends Resource
## Data-driven weapon definition. Instances live as .tres files in data/weapons/.

enum WeaponType { SWORD, LANCE, AXE, BOW, TOME, SCYTHE }

## Which stat a weapon's on-hit debuff (see debuff_amount below) lowers.
## NONE means "this weapon has no debuff" — the default for every existing
## weapon, so nothing changes for them.
enum DebuffStat { NONE, STR, MAG, SKL, SPD, LCK, DEF, RES }

## Indexed by DebuffStat — short French stat abbreviations, shared by
## anything that needs to display a debuff (EquipMenuRow's stat line,
## Battle._show_strike_message's floating combat notice) so there's one
## source of truth instead of two copies drifting apart.
const DEBUFF_STAT_LABELS: Array[String] = ["", "FOR", "MAG", "TEC", "VIT", "CHA", "DEF", "RES"]

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
## debuff_duration of the TARGET's own turns (see UnitData.apply_debuff /
## Unit.start_new_turn, where active debuffs tick down) — independent of
## weapon_type, same "a capability on the weapon, not a new class/rule" idea
## heal_amount already established. First use: data/weapons/scythe.tres.
@export_group("Debuff")
@export var debuff_stat: DebuffStat = DebuffStat.NONE
@export var debuff_amount: int = 0
@export var debuff_duration: int = 0

func can_heal() -> bool:
	return heal_amount > 0

func can_debuff() -> bool:
	return debuff_stat != DebuffStat.NONE and debuff_amount > 0
