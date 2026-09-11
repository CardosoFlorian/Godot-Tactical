class_name UnitInfoPanel
extends PanelContainer

## Indexed by WeaponData.WeaponType (SWORD=0, LANCE=1, AXE=2, BOW=3, TOME=4,
## SCYTHE=5, GAUNTLET=6).
const PROFICIENCY_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/weapon_icons/sword.png"),
	preload("res://assets/ui/weapon_icons/lance.png"),
	preload("res://assets/ui/weapon_icons/axe.png"),
	preload("res://assets/ui/weapon_icons/bow.png"),
	preload("res://assets/ui/weapon_icons/tome.png"),
	preload("res://assets/ui/weapon_icons/scythe.png"),
	preload("res://assets/ui/weapon_icons/gauntlet.png"),
]

## Reset color for a stat Label once any debuff on it expires — see _set_stat.
const NORMAL_STAT_COLOR := Color.WHITE
const DEBUFF_STAT_COLOR := Color(1.0, 0.35, 0.35, 1)
## A stat currently boosted by a live technique bonus (e.g. Lycith's Serment
## Royale, Lance Puissante) — same green LevelUpScreen already uses for a
## permanent stat gain, reused here for a situational one. Real gap caught
## live: this panel showed base stats only, so a technique's combat-math
## effect (already verified correct) never showed up anywhere the player
## could actually see it — user: "tu donnes des stats à une unité mais tu
## montres pas les stats."
const BUFF_STAT_COLOR := Color(0.4, 1.0, 0.4, 1)

## Indexed by ClassData.MovementType (INFANTRY=0, MOUNTED=1, FLYING=2).
## Unlike PROFICIENCY_ICONS above (all 5 shown, unusable ones dimmed), only
## the one icon matching this unit's actual movement type is ever shown —
## explicit user call, movement type isn't a multi-value "can use" set like
## weapon proficiencies are.
const MOVEMENT_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/movement_icons/infantry.png"),
	preload("res://assets/ui/movement_icons/mounted.png"),
	preload("res://assets/ui/movement_icons/flying.png"),
]

@onready var name_label: Label = $VBox/NameLabel
@onready var class_label: Label = $VBox/ClassRow/ClassLabel
@onready var movement_icon: TextureRect = $VBox/ClassRow/MovementIcon
@onready var proficiency_icons: Array[TextureRect] = [
	$VBox/ClassRow/ProficiencyIcons/Sword,
	$VBox/ClassRow/ProficiencyIcons/Lance,
	$VBox/ClassRow/ProficiencyIcons/Axe,
	$VBox/ClassRow/ProficiencyIcons/Bow,
	$VBox/ClassRow/ProficiencyIcons/Tome,
	$VBox/ClassRow/ProficiencyIcons/Scythe,
	$VBox/ClassRow/ProficiencyIcons/Gauntlet,
]
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var hp_label: Label = $VBox/HPBar/HPLabel
@onready var exp_bar: ProgressBar = $VBox/ExpBar
@onready var exp_label: Label = $VBox/ExpBar/ExpLabel
@onready var stat_str: Label = $VBox/StatGrid/StatStr
@onready var stat_mag: Label = $VBox/StatGrid/StatMag
@onready var stat_skl: Label = $VBox/StatGrid/StatSkl
@onready var stat_spd: Label = $VBox/StatGrid/StatSpd
@onready var stat_lck: Label = $VBox/StatGrid/StatLck
@onready var stat_def: Label = $VBox/StatGrid/StatDef
@onready var stat_res: Label = $VBox/StatGrid/StatRes
@onready var stat_con: Label = $VBox/StatGrid/StatCon
@onready var stat_mov: Label = $VBox/MovWeaponRow/StatMov
@onready var weapon_icon: TextureRect = $VBox/MovWeaponRow/WeaponIcon
@onready var weapon_label: Label = $VBox/MovWeaponRow/WeaponLabel

func _ready() -> void:
	hide()

## `extra_def_bonus` is a live positional technique bonus (Serment
## Royale-style) the caller computed externally — this panel has no
## grid/roster access to work it out itself (see Battle._ally_def_bonus).
## A SELF_WEAPON Force bonus (Lance Puissante-style), by contrast, needs
## nothing external — it only depends on unit_data's own equipped weapon
## and techniques, so it's computed right here via
## CombatResolver._technique_str_bonus, reused rather than duplicated.
func show_unit(unit_data: UnitData, extra_def_bonus: int = 0) -> void:
	name_label.text = unit_data.display_name
	# No unit shows a class name here anymore, not even a regular enemy —
	# display_name alone (e.g. "Bandit") already carries that identity per
	# enemy_naming_convention; class_label is just the level for everyone now,
	# not a redundant/leftover class label ("Épéiste", or a second "Bandit").
	class_label.text = "Niv.%d" % unit_data.level
	_show_proficiencies(unit_data)
	_show_movement_type(unit_data)
	hp_bar.max_value = unit_data.get_max_hp()
	hp_bar.value = unit_data.get_current_hp()
	hp_label.text = "%d / %d" % [unit_data.get_current_hp(), unit_data.get_max_hp()]

	# EXP only means anything for a character_class == null unit (a
	# playable/boss-style unit with its own level — see UnitData.gain_exp);
	# a regular ClassData-templated enemy never levels up mid-battle, so
	# hide the bar entirely for those rather than showing a meaningless 0/100.
	exp_bar.visible = unit_data.character_class == null
	if exp_bar.visible:
		_set_exp_display(unit_data.exp)

	_set_stat(stat_str, "Force", unit_data.get_str(), unit_data, WeaponData.DebuffStat.STR, CombatResolver._technique_str_bonus(unit_data))
	_set_stat(stat_mag, "Magie", unit_data.get_mag(), unit_data, WeaponData.DebuffStat.MAG)
	_set_stat(stat_skl, "Technique", unit_data.get_skl(), unit_data, WeaponData.DebuffStat.SKL)
	_set_stat(stat_spd, "Vitesse", unit_data.get_spd(), unit_data, WeaponData.DebuffStat.SPD)
	_set_stat(stat_def, "Defense", unit_data.get_def(), unit_data, WeaponData.DebuffStat.DEF, extra_def_bonus)
	_set_stat(stat_res, "Resist.", unit_data.get_res(), unit_data, WeaponData.DebuffStat.RES)
	_set_stat(stat_lck, "Chance", unit_data.get_lck(), unit_data, WeaponData.DebuffStat.LCK)
	stat_con.text = "Constit. %d" % unit_data.get_con()
	stat_mov.text = "Mouv %d" % unit_data.get_mov()

	var weapon := unit_data.get_equipped_weapon()
	weapon_label.text = weapon.display_name if weapon else "A mains nues"
	weapon_icon.texture = weapon.icon if weapon else null
	weapon_icon.visible = weapon_icon.texture != null

	show()

## Sets a stat label's text AND colors it: green with a "(+N)" suffix while
## `bonus` (a live technique effect, e.g. Serment Royale/Lance Puissante) is
## active, red whenever an active debuff is lowering the stat instead, white
## otherwise. Re-set every call (not just when relevant) since the SAME
## Label nodes are reused across show_unit() calls for different units/
## turns, so a color from last time needs to be explicitly reset once it no
## longer applies. `bonus` takes priority over a debuff on the same stat —
## not expected to co-occur in practice, but a buffed display reads more
## usefully than a red one if it somehow did.
func _set_stat(label: Label, prefix: String, value: int, unit_data: UnitData, stat: WeaponData.DebuffStat, bonus: int = 0) -> void:
	if bonus > 0:
		label.text = "%s %d (+%d)" % [prefix, value + bonus, bonus]
		label.add_theme_color_override("font_color", BUFF_STAT_COLOR)
		return
	label.text = "%s %d" % [prefix, value]
	var is_debuffed := unit_data.get_debuff_total(stat) > 0
	label.add_theme_color_override("font_color", DEBUFF_STAT_COLOR if is_debuffed else NORMAL_STAT_COLOR)

## Lights up one icon per weapon type unit_data.can_use_weapon allows, dims
## the rest rather than hiding them (so the full icon set is always there as
## a reference for what exists, not just what this unit has).
func _show_proficiencies(unit_data: UnitData) -> void:
	for type in PROFICIENCY_ICONS.size():
		var icon := proficiency_icons[type]
		icon.texture = PROFICIENCY_ICONS[type]
		icon.modulate = Color.WHITE if unit_data.can_use_weapon(type) else Color(1, 1, 1, 0.25)

## Shows only the icon matching this unit's actual movement type (no dimmed
## siblings, unlike _show_proficiencies above).
func _show_movement_type(unit_data: UnitData) -> void:
	movement_icon.texture = MOVEMENT_ICONS[unit_data.get_movement_type()]
	movement_icon.visible = true

func hide_panel() -> void:
	hide()

## Static only — no animation here anymore (see ExpGainOverlay, the
## centered on-screen bar that plays the actual fill animation; this
## corner panel just snaps straight to whatever the real value is,
## refreshed via the SignalBus.unit_selected re-emit Battle.gd does once
## an XP grant finishes).
func _set_exp_display(value: int) -> void:
	exp_bar.value = value
	exp_label.text = "XP %d / 100" % value
