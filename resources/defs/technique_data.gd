class_name TechniqueData
extends Resource
## A level-gated bonus a character-model unit (character_class == null — see
## UnitData) gains on leveling up, granted from UnitData.gain_exp. Deliberately
## NOT limited to weapon unlocks — user's own framing, "outre buff de stats et
## nouvelles armes" — a technique can also change a unit's movement type
## (e.g. infantry -> mounted) or, eventually, grant a passive.
##
## Engine only, no content authored yet: every playable character's
## `techniques` array ships empty. Which technique, for which character, at
## which level (roughly every 5, per the user's own cadence) is real
## per-character creative design, not something to invent here.

enum TechniqueType { STAT_BUFF, WEAPON_UNLOCK, MOVEMENT_CHANGE, PASSIVE }

@export var display_name: String = "Technique"
@export var level_required: int = 5
@export var type: TechniqueType = TechniqueType.STAT_BUFF

## STAT_BUFF only — reuses WeaponData.DebuffStat rather than a new enum,
## since it's already exactly "which of the 7 growth stats" (STR/MAG/SKL/
## SPD/LCK/DEF/RES; NONE is meaningless here).
@export var stat: WeaponData.DebuffStat = WeaponData.DebuffStat.NONE
@export var stat_amount: int = 1

## WEAPON_UNLOCK only.
@export var weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.SWORD

## MOVEMENT_CHANGE only.
@export var new_movement_type: ClassData.MovementType = ClassData.MovementType.MOUNTED

## PASSIVE is a data placeholder only for now — no passive-effect engine
## exists anywhere in combat resolution yet, so granting one records its
## name/description for the level-up banner but has no runtime effect until
## something is separately built to read it.
@export_multiline var description: String = ""
