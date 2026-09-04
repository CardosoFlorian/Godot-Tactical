class_name ClassData
extends Resource
## Data-driven unit class definition (base stats + growths). Instances live
## as .tres files in data/classes/.

@export var display_name: String = "Class"
@export var class_icon: Texture2D

@export_group("Base stats")
@export var base_hp: int = 20
@export var base_str: int = 5
@export var base_skl: int = 5
@export var base_spd: int = 5
@export var base_lck: int = 5
@export var base_def: int = 5
@export var base_res: int = 5
@export var base_mov: int = 5

@export_group("Growth rates (%)")
@export var growth_hp: int = 70
@export var growth_str: int = 40
@export var growth_skl: int = 40
@export var growth_spd: int = 40
@export var growth_lck: int = 30
@export var growth_def: int = 30
@export var growth_res: int = 20

@export_group("Weapon proficiency")
@export var usable_weapon_types: Array[WeaponData.WeaponType] = [WeaponData.WeaponType.SWORD]
