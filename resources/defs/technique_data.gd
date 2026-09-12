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

## SPEED_GAP_ADVANTAGE (added for Lycith's Alacrité/Alacrité Supérieur) and
## NEARBY_ALLIES (added for her Serment Royale) both need context
## CombatResolver's pure attacker/defender math doesn't have — an ally roster
## with positions, for NEARBY_ALLIES — so unlike every other trigger here,
## they're NOT checked by CombatResolver's own _unlocked_techniques-based
## helpers. SPEED_GAP_ADVANTAGE is checked inline in resolve_combat itself
## (it already computes effective Spd for both sides). NEARBY_ALLIES is
## checked by Battle.gd, the only place with grid/unit-roster access, which
## folds the result into a NEW "extra_physical_def" terrain-dict key kept
## deliberately separate from "def" (see get_damage) — Serment Royale is
## Défense only, not Résistance, and terrain "def" already feeds both.
## SELF_MELEE_WEAPON (added for Kessa's Sang de Forgeronne) checks the
## unit's own weapon RANGE (min_range==1 and max_range==1) instead of a
## specific weapon TYPE — see CombatResolver._technique_melee_stat_bonus.
## SELF_INITIATES (added for Kessa's Frappe Rapide) needs the same
## "only ever checked against the true initiating attacker, never a
## defender/counter-attacker" restriction as SPEED_GAP_ADVANTAGE's own
## doc — CombatResolver.resolve_combat computes it once against `attacker`
## specifically, before building the strike order, same pattern as
## _technique_double_before_counter.
enum CombatTrigger { SELF_WEAPON, ENEMY_WEAPON, SELF_LOW_HP, SPEED_GAP_ADVANTAGE, NEARBY_ALLIES, SELF_MELEE_WEAPON, SELF_INITIATES }
## STR_BONUS_FLAT and DEF_BONUS_PHYSICAL_ONLY both add to the physical
## attack_power/defense computed inside get_damage's non-magic branch (NOT a
## post-calc flat reduction like DAMAGE_REDUCTION_FLAT, which applies after
## and to both damage paths) — see get_damage for exactly where each lands.
## DOUBLE_BEFORE_COUNTER carries no magnitude (effect_amount is unused for
## it) — it's a yes/no reordering of resolve_combat's strike sequence, not a
## number. CRIT_BONUS_FLAT adds straight onto get_crit_chance's result.
## STR_SKL_BONUS_FLAT (Sang de Forgeronne: melee weapon → Force ET Technique
## +3) applies the SAME effect_amount to both Force (get_damage's
## attack_power, weight ×1) and Technique (get_hit_chance's ×2 term AND
## get_crit_chance's ÷2 term) — as if the unit's real Force/Technique stats
## were both higher, not two independent flat numbers. ENEMY_AVOID_REDUCTION_FLAT
## (Frappe Rapide) is mathematically identical to a HIT_BONUS (hit_chance is
## just attack_hit - avoid, so -avoid and +hit are the same clamped result)
## but named for what the design actually says, and gated on SELF_INITIATES
## rather than a weapon check.
enum CombatEffect { DAMAGE_PERCENT_BONUS, HIT_BONUS, DAMAGE_REDUCTION_FLAT, DOUBLE_BEFORE_COUNTER, STR_BONUS_FLAT, DEF_BONUS_PHYSICAL_ONLY, CRIT_BONUS_FLAT, STR_SKL_BONUS_FLAT, ENEMY_AVOID_REDUCTION_FLAT }

## COMBAT_BONUS only, EXCEPT it's also read (always as an implicit
## SELF_WEAPON check — the unit's own currently wielded weapon) by
## avoid_bonus_while_equipped below regardless of `type`, same
## independent-of-type shape as post_combat_heal_percent_of_max.
@export var trigger: CombatTrigger = CombatTrigger.SELF_WEAPON
## SELF_WEAPON/ENEMY_WEAPON only, EXCEPT also used by
## avoid_bonus_while_equipped (see its own doc) to gate on the wielded
## weapon's type — e.g. Martin's Œil du Lettré only grants its avoid bonus
## while he's actually holding a Tome, not just whenever the technique
## occupies one of his 3 equip slots.
@export var trigger_weapon_type: WeaponData.WeaponType = WeaponData.WeaponType.SWORD
## SELF_LOW_HP only — active while current HP is BELOW this % of max HP.
@export var trigger_hp_threshold_percent: int = 50
## SPEED_GAP_ADVANTAGE only — active while the unit's own effective Spd
## exceeds its opponent's by at least this much, and only when the unit is
## the one INITIATING combat (checked against `attacker` specifically in
## resolve_combat, never against a defender/counter-attacker — the user's
## own call for Alacrité: "Si l'unité initie le combat").
@export var trigger_spd_gap: int = 5
## NEARBY_ALLIES only.
@export var trigger_ally_radius: int = 2
@export var trigger_ally_count: int = 2
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

## Flat avoid (esquive) bonus while this technique is equipped AND the unit
## is currently wielding a weapon of `trigger_weapon_type` — same
## "independent of `type`" shape as post_combat_heal_percent_of_max above
## (added for Martin's capstone, Œil du Lettré: a permanent STAT_BUFF
## Mag/Res bump PLUS a gated avoid bonus on the same resource, gated
## specifically on wielding a Tome — the user's own wording, "tant qu'il
## est équipé d'un tome"). 0 (default) means no such effect. Checked by
## CombatResolver.get_hit_chance against the DEFENDER's own equipped
## techniques — see CombatResolver._technique_avoid_bonus.
@export var avoid_bonus_while_equipped: int = 0

## Whether this technique needs to be one of a unit's (at most
## UnitData.MAX_EQUIPPED_TECHNIQUES) EQUIPPED techniques to have any effect
## at all, rather than being permanently active from the instant it's
## learned — the user's own rule. WEAPON_UNLOCK, MOVEMENT_CHANGE, and an
## unconditional STAT_BUFF (its stat/stat2/hp_bonus effects are one-time,
## permanent base_X mutations applied once at grant time — there's nothing
## left to "unequip") are NEVER gated this way. Anything with a live,
## situational check IS gated — every COMBAT_BONUS technique, or a
## post-combat proc — even one that's nominally STAT_BUFF-typed like
## Aurora's Cœur de Souveraine: its HP+3 stays permanent/always-on, but its
## post_combat_heal_percent_of_max proc specifically needs equipping to fire.
func is_conditional() -> bool:
	return type == TechniqueType.COMBAT_BONUS or post_combat_heal_percent_of_max > 0 or avoid_bonus_while_equipped > 0

## Full stat names (unlike WeaponData.DEBUFF_STAT_LABELS' abbreviations —
## those are sized for a tight combat notice, this is for a readable hover
## tooltip) indexed by WeaponData.DebuffStat.
const STAT_FULL_LABELS: Array[String] = ["", "Force", "Magie", "Technique", "Vitesse", "Chance", "Défense", "Résistance"]

## Human-readable (French) description of what this technique actually
## does, built from its own fields rather than authored separately per
## technique — used for UnitsScreen's hover tooltip so a player (or the
## user testing in the editor) can see the mechanical effect, not just the
## flavor name.
func get_effect_description() -> String:
	match type:
		TechniqueType.STAT_BUFF:
			return _describe_stat_buff()
		TechniqueType.WEAPON_UNLOCK:
			return "Débloque l'utilisation des armes de type %s." % WeaponData.WEAPON_TYPE_LABELS[weapon_type]
		TechniqueType.MOVEMENT_CHANGE:
			return "Change le type de déplacement de l'unité."
		TechniqueType.PASSIVE:
			return description if description != "" else "Technique passive (sans effet mécanique pour l'instant)."
		TechniqueType.COMBAT_BONUS:
			return _describe_combat_bonus()
	return ""

func _describe_stat_buff() -> String:
	var parts: Array[String] = []
	if stat != WeaponData.DebuffStat.NONE:
		parts.append("%s +%d" % [STAT_FULL_LABELS[stat], stat_amount])
	if stat2 != WeaponData.DebuffStat.NONE:
		parts.append("%s +%d" % [STAT_FULL_LABELS[stat2], stat2_amount])
	if hp_bonus != 0:
		parts.append("PV +%d" % hp_bonus)
	var text := ", ".join(parts)
	# Clarified per the user's own request — a technique mixing a permanent
	# stat bump with a gated proc (currently only Aurora's Cœur de
	# Souveraine) could otherwise read as if the WHOLE thing needs equipping.
	# It doesn't: stat/stat2/hp_bonus are one-time base_X mutations already
	# applied the instant the technique is learned (see
	# UnitData._grant_technique_if_due), regardless of equip state — only
	# the proc below is gated (see TechniqueData.is_conditional).
	if post_combat_heal_percent_of_max > 0:
		text += " (permanent, actif dès l'apprentissage même si la technique n'est pas équipée)"
		text += "\nAprès un combat, si équipée : chance égale à sa Force de récupérer %d%% de ses PV max." % post_combat_heal_percent_of_max
	if avoid_bonus_while_equipped > 0:
		text += " (permanent, actif dès l'apprentissage même si la technique n'est pas équipée)"
		text += "\nSi équipée, et si l'unité manie alors %s %s : Esquive +%d." % [WeaponData.WEAPON_TYPE_ARTICLES[trigger_weapon_type], WeaponData.WEAPON_TYPE_LABELS[trigger_weapon_type], avoid_bonus_while_equipped]
	return text

func _describe_combat_bonus() -> String:
	var condition := ""
	match trigger:
		CombatTrigger.SELF_WEAPON:
			condition = "Si l'unité est équipée d'%s %s" % [WeaponData.WEAPON_TYPE_ARTICLES[trigger_weapon_type], WeaponData.WEAPON_TYPE_LABELS[trigger_weapon_type]]
		CombatTrigger.ENEMY_WEAPON:
			condition = "Si l'ennemi est équipé d'%s %s" % [WeaponData.WEAPON_TYPE_ARTICLES[trigger_weapon_type], WeaponData.WEAPON_TYPE_LABELS[trigger_weapon_type]]
		CombatTrigger.SELF_LOW_HP:
			condition = "Si l'unité a moins de %d%% de ses PV max" % trigger_hp_threshold_percent
		CombatTrigger.SPEED_GAP_ADVANTAGE:
			condition = "Si l'unité initie le combat avec au moins %d points de Vitesse de plus que l'ennemi" % trigger_spd_gap
		CombatTrigger.NEARBY_ALLIES:
			condition = "Si %d alliés ou plus se trouvent à %d case(s) ou moins" % [trigger_ally_count, trigger_ally_radius]
		CombatTrigger.SELF_MELEE_WEAPON:
			condition = "Si l'unité est équipée d'une arme à 1 case de portée"
		CombatTrigger.SELF_INITIATES:
			condition = "Si l'unité engage le combat"
	var effect_text := ""
	match effect:
		CombatEffect.DAMAGE_PERCENT_BONUS:
			effect_text = "augmente les dégâts infligés de %d%%." % effect_amount
		CombatEffect.HIT_BONUS:
			effect_text = "augmente la précision de %d." % effect_amount
		CombatEffect.DAMAGE_REDUCTION_FLAT:
			effect_text = "réduit les dégâts subis de %d." % effect_amount
		CombatEffect.DOUBLE_BEFORE_COUNTER:
			effect_text = "sa seconde frappe (si double attaque) se déclenche avant la riposte adverse."
		CombatEffect.STR_BONUS_FLAT:
			effect_text = "augmente la Force de %d." % effect_amount
		CombatEffect.DEF_BONUS_PHYSICAL_ONLY:
			effect_text = "augmente la Défense de %d." % effect_amount
		CombatEffect.CRIT_BONUS_FLAT:
			effect_text = "augmente le taux de coup critique de %d." % effect_amount
		CombatEffect.STR_SKL_BONUS_FLAT:
			effect_text = "augmente la Force et la Technique de %d." % effect_amount
		CombatEffect.ENEMY_AVOID_REDUCTION_FLAT:
			effect_text = "réduit l'esquive de l'ennemi de %d durant ce combat." % effect_amount
	return "%s, %s" % [condition, effect_text]
