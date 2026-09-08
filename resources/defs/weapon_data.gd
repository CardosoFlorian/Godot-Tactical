class_name WeaponData
extends Resource
## Data-driven weapon definition. Instances live as .tres files in data/weapons/.

enum WeaponType { SWORD, LANCE, AXE, BOW, TOME }

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

func can_heal() -> bool:
	return heal_amount > 0
