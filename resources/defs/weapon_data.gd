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
