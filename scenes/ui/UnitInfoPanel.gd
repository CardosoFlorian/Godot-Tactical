class_name UnitInfoPanel
extends PanelContainer

## Indexed by WeaponData.WeaponType (SWORD=0, LANCE=1, AXE=2, BOW=3, TOME=4,
## SCYTHE=5).
const PROFICIENCY_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/weapon_icons/sword.png"),
	preload("res://assets/ui/weapon_icons/lance.png"),
	preload("res://assets/ui/weapon_icons/axe.png"),
	preload("res://assets/ui/weapon_icons/bow.png"),
	preload("res://assets/ui/weapon_icons/tome.png"),
	preload("res://assets/ui/weapon_icons/scythe.png"),
]

## Reset color for a stat Label once any debuff on it expires — see _set_stat.
const NORMAL_STAT_COLOR := Color.WHITE
const DEBUFF_STAT_COLOR := Color(1.0, 0.35, 0.35, 1)

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
]
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var hp_label: Label = $VBox/HPBar/HPLabel
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

func show_unit(unit_data: UnitData) -> void:
	name_label.text = unit_data.display_name
	var class_name_text := unit_data.character_class.display_name if unit_data.character_class else "?"
	class_label.text = "%s Niv.%d" % [class_name_text, unit_data.level]
	_show_proficiencies(unit_data.character_class)
	_show_movement_type(unit_data.character_class)
	hp_bar.max_value = unit_data.get_max_hp()
	hp_bar.value = unit_data.get_current_hp()
	hp_label.text = "%d / %d" % [unit_data.get_current_hp(), unit_data.get_max_hp()]

	_set_stat(stat_str, "Force", unit_data.get_str(), unit_data, WeaponData.DebuffStat.STR)
	_set_stat(stat_mag, "Magie", unit_data.get_mag(), unit_data, WeaponData.DebuffStat.MAG)
	_set_stat(stat_skl, "Technique", unit_data.get_skl(), unit_data, WeaponData.DebuffStat.SKL)
	_set_stat(stat_spd, "Vitesse", unit_data.get_spd(), unit_data, WeaponData.DebuffStat.SPD)
	_set_stat(stat_def, "Defense", unit_data.get_def(), unit_data, WeaponData.DebuffStat.DEF)
	_set_stat(stat_res, "Resist.", unit_data.get_res(), unit_data, WeaponData.DebuffStat.RES)
	_set_stat(stat_lck, "Chance", unit_data.get_lck(), unit_data, WeaponData.DebuffStat.LCK)
	stat_con.text = "Constit. %d" % unit_data.get_con()
	stat_mov.text = "Mouv %d" % unit_data.get_mov()

	var weapon := unit_data.get_equipped_weapon()
	weapon_label.text = weapon.display_name if weapon else "A mains nues"
	weapon_icon.texture = weapon.icon if weapon else null
	weapon_icon.visible = weapon_icon.texture != null

	show()

## Sets a stat label's text AND colors it red whenever an active debuff is
## currently lowering that stat, white otherwise — re-set every call (not
## just when debuffed) since the SAME Label nodes are reused across
## show_unit() calls for different units/turns, so a stat that was red last
## time needs to be explicitly reset once its debuff expires or a different,
## non-debuffed unit is shown.
func _set_stat(label: Label, prefix: String, value: int, unit_data: UnitData, stat: WeaponData.DebuffStat) -> void:
	label.text = "%s %d" % [prefix, value]
	var is_debuffed := unit_data.get_debuff_total(stat) > 0
	label.add_theme_color_override("font_color", DEBUFF_STAT_COLOR if is_debuffed else NORMAL_STAT_COLOR)

## Lights up one icon per weapon type character_class.usable_weapon_types
## allows, dims the rest rather than hiding them (so the full 5-icon set is
## always there as a reference for what exists, not just what this unit has).
func _show_proficiencies(character_class: ClassData) -> void:
	for type in PROFICIENCY_ICONS.size():
		var icon := proficiency_icons[type]
		icon.texture = PROFICIENCY_ICONS[type]
		var usable := character_class != null and character_class.can_use_weapon(type)
		icon.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.25)

## Shows only the icon matching this class's actual movement type (no dimmed
## siblings, unlike _show_proficiencies above) — hidden entirely if there's
## no class to read a movement type from.
func _show_movement_type(character_class: ClassData) -> void:
	if character_class == null:
		movement_icon.visible = false
		return
	movement_icon.texture = MOVEMENT_ICONS[character_class.movement_type]
	movement_icon.visible = true

func hide_panel() -> void:
	hide()
