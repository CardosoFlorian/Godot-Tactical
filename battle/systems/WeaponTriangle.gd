class_name WeaponTriangle
extends RefCounted
## Data-driven weapon triangle: Sword > Axe > Lance > Sword. Bows (and any
## type not listed) sit outside the triangle and get no bonus/penalty.

const ADVANTAGE := {
	WeaponData.WeaponType.SWORD: WeaponData.WeaponType.AXE,
	WeaponData.WeaponType.AXE: WeaponData.WeaponType.LANCE,
	WeaponData.WeaponType.LANCE: WeaponData.WeaponType.SWORD,
}

const HIT_BONUS := 15
const MIGHT_BONUS := 1

## Returns {"hit": int, "might": int} from the perspective of `attacker_type`
## fighting `defender_type`.
static func get_modifiers(attacker_type: WeaponData.WeaponType, defender_type: WeaponData.WeaponType) -> Dictionary:
	if ADVANTAGE.get(attacker_type) == defender_type:
		return {"hit": HIT_BONUS, "might": MIGHT_BONUS}
	if ADVANTAGE.get(defender_type) == attacker_type:
		return {"hit": -HIT_BONUS, "might": -MIGHT_BONUS}
	return {"hit": 0, "might": 0}
