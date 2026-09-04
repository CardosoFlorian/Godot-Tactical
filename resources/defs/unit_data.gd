class_name UnitData
extends Resource
## Data-driven unit definition: a specific character (template + persistent
## state). Instances live as .tres files in data/units/. Battle-only runtime
## state (grid position, has_acted...) is NOT here — it lives on the Unit
## scene node in battle/scenes, which holds a reference to a UnitData.

enum Team { PLAYER, ENEMY, ALLY }
enum AIBehavior { NONE, AGGRESSIVE, DEFENSIVE }

@export var character_id: String = ""
@export var display_name: String = "Unit"
@export var character_class: ClassData
@export var level: int = 1
@export var team: Team = Team.PLAYER
@export var permadeath: bool = true

@export_group("Equipment")
@export var inventory: Array[WeaponData] = []
@export var equipped_index: int = 0

@export_group("Portraits & sprites")
@export var portrait: Texture2D
@export var battle_sprite: Texture2D

@export_group("Enemy AI (ignored for player units)")
@export var ai_behavior: AIBehavior = AIBehavior.AGGRESSIVE
## How far (in tiles) an enemy will move to engage before giving up and holding position.
@export var ai_aggro_range: int = 99

var current_hp: int = -1  # -1 means "not initialized yet", see get_current_hp()

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
	return character_class.base_str + _growth_bonus(character_class.growth_str) if character_class else 0

func get_mag() -> int:
	return character_class.base_mag + _growth_bonus(character_class.growth_mag) if character_class else 0

func get_skl() -> int:
	return character_class.base_skl + _growth_bonus(character_class.growth_skl) if character_class else 0

func get_spd() -> int:
	return character_class.base_spd + _growth_bonus(character_class.growth_spd) if character_class else 0

func get_lck() -> int:
	return character_class.base_lck + _growth_bonus(character_class.growth_lck) if character_class else 0

func get_def() -> int:
	return character_class.base_def + _growth_bonus(character_class.growth_def) if character_class else 0

func get_res() -> int:
	return character_class.base_res + _growth_bonus(character_class.growth_res) if character_class else 0

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
