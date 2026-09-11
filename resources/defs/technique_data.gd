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
##
## COMBAT_BONUS (added 2026-09-11 for Aurora's kit) covers situational
## combat-time bonuses — "+20% damage against axes," "+20 hit while wielding
## a sword," "take 3 less damage under 50% HP" — as opposed to STAT_BUFF's
## permanent one-time base_X bump. Unlike every other type, a COMBAT_BONUS
## technique does nothing at the moment it's granted (see
## UnitData._grant_technique_if_due, which just records it like PASSIVE) —
## it's checked LIVE every combat by CombatResolver against
## trigger/trigger_weapon_type/trigger_hp_threshold_percent, for every
## technique in a unit's `techniques` array whose level_required <= its
## current level (see CombatResolver._unlocked_techniques). This is
## deliberately generic (trigger × effect, not one enum per specific
## technique) so a future character's own combat-bonus ideas can reuse it
## without more engine work, as long as they fit the same
## weapon-matchup/self-HP shape.

enum TechniqueType { STAT_BUFF, WEAPON_UNLOCK, MOVEMENT_CHANGE, PASSIVE, COMBAT_BONUS }

@export var display_name: String = "Technique"
@export var level_required: int = 5
@export var type: TechniqueType = TechniqueType.STAT_BUFF
## Marks a technique as tied to one specific character (e.g. Aurora's
## "Cœur de Souveraine," her protagonist capstone) — not enforced anywhere
## yet, since the convoy/Gemme Technique copy-between-units system this
## flag is FOR doesn't exist yet either (see technique_equip_and_gem_design
## memory). Recorded now so that system has a real field to check once it's
## built, instead of retrofitting one later.
@export var is_unique: bool = false

## STAT_BUFF only — reuses WeaponData.DebuffStat rather than a new enum,
## since it's already exactly "which of the 7 growth stats" (STR/MAG/SKL/
## SPD/LCK/DEF/RES; NONE is meaningless here). stat2/stat2_amount are
## optional — NONE (the default) means this technique only touches `stat`;
## set them to buff two stats from a single technique (e.g. "Défense et
## Résistance +2") instead of needing two separate TechniqueData resources.
## hp_bonus is separate from stat/stat2 (DebuffStat deliberately has no HP
## entry — a debuff weapon should never be able to lower HP directly) —
## nonzero applies straight to base_hp/current_hp in UnitData, same
## "raising the ceiling also heals by the same amount" rule
## _roll_level_up_stats already uses for a random HP growth roll.
@export var stat: WeaponData.DebuffStat = WeaponData.DebuffStat.NONE
@export var stat_amount: int = 1
@export var stat2: WeaponData.DebuffStat = WeaponData.DebuffStat.NONE
@export var stat2_amount: int = 1
@export var hp_bonus: int = 0

## WEAPON_UNLOCK only.
@export var weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.SWORD

## MOVEMENT_CHANGE only.
@export var new_movement_type: ClassData.MovementType = ClassData.MovementType.MOUNTED

## PASSIVE is a data placeholder only for now — no generic passive-effect
## engine exists anywhere in combat resolution yet, so granting one records
## its name/description for the level-up banner but has no runtime effect
## until something is separately built to read it. (COMBAT_BONUS above is
## NOT that generic engine — it's a narrow, specific mechanism for
## weapon-matchup/self-HP situational bonuses only.)
@export_multiline var description: String = ""

enum CombatTrigger { SELF_WEAPON, ENEMY_WEAPON, SELF_LOW_HP }
enum CombatEffect { DAMAGE_PERCENT_BONUS, HIT_BONUS, DAMAGE_REDUCTION_FLAT }

## COMBAT_BONUS only.
@export var trigger: CombatTrigger = CombatTrigger.SELF_WEAPON
## SELF_WEAPON/ENEMY_WEAPON only.
@export var trigger_weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.SWORD
## SELF_LOW_HP only — active while current HP is BELOW this % of max HP.
@export var trigger_hp_threshold_percent: int = 50
@export var effect: CombatEffect = CombatEffect.HIT_BONUS
@export var effect_amount: int = 0

## Post-combat sustain — currently only Aurora's unique capstone: a % chance
## (equal to the wielder's own Force/STR stat, not a fixed designer number —
## the user's own call) to heal this % of max HP once a full combat exchange
## ends. 0 (the default) means "no such effect." Independent of `type`
## (this technique is STAT_BUFF for its HP+3, but this field is checked
## regardless of type) and deliberately NOT folded into COMBAT_BONUS, which
## fires per-strike mid-combat — this triggers once, after the whole
## exchange resolves. See CombatResolver.resolve_combat's post-combat pass.
@export var post_combat_heal_percent_of_max: int = 0
