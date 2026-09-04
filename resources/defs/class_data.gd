class_name ClassData
extends Resource
## Data-driven unit class definition (base stats + growths). Instances live
## as .tres files in data/classes/.

enum MovementType { INFANTRY, MOUNTED, FLYING }

@export var display_name: String = "Class"
@export var class_icon: Texture2D
@export var movement_type: MovementType = MovementType.INFANTRY

@export_group("Base stats")
@export var base_hp: int = 20
@export var base_str: int = 5
@export var base_mag: int = 0
@export var base_skl: int = 5
@export var base_spd: int = 5
@export var base_lck: int = 5
@export var base_def: int = 5
@export var base_res: int = 5
@export var base_mov: int = 5
@export var base_con: int = 8

@export_group("Growth rates (%)")
@export var growth_hp: int = 70
@export var growth_str: int = 40
@export var growth_mag: int = 0
@export var growth_skl: int = 40
@export var growth_spd: int = 40
@export var growth_lck: int = 30
@export var growth_def: int = 30
@export var growth_res: int = 20
@export var growth_con: int = 0

@export_group("Weapon proficiency")
## Weapons a unit of this class is allowed to equip. Enforced in
## UnitData.get_equipped_weapon() — a weapon outside this list is treated as
## unequipped rather than silently used.
@export var usable_weapon_types: Array[WeaponData.WeaponType] = [WeaponData.WeaponType.SWORD]

@export_group("Promotion")
## Old-school Fire Emblem style: each class has at most ONE fixed promotion
## target (no player choice, no reclassing), so a character's sprite/weapon
## type never mismatches its class. Null means this class can't promote
## (either a base class with none defined yet, or already a promoted class).
@export var promoted_class: ClassData
@export var promotion_level: int = 10

func can_use_weapon(weapon_type: WeaponData.WeaponType) -> bool:
	return usable_weapon_types.has(weapon_type)
