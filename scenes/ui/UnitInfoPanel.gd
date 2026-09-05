class_name UnitInfoPanel
extends PanelContainer

## Indexed by WeaponData.WeaponType (SWORD=0, LANCE=1, AXE=2, BOW=3, TOME=4).
const PROFICIENCY_ICONS: Array[Texture2D] = [
	preload("res://assets/ui/weapon_icons/sword.png"),
	preload("res://assets/ui/weapon_icons/lance.png"),
	preload("res://assets/ui/weapon_icons/axe.png"),
	preload("res://assets/ui/weapon_icons/bow.png"),
	preload("res://assets/ui/weapon_icons/tome.png"),
]

@onready var name_label: Label = $VBox/NameLabel
@onready var class_label: Label = $VBox/ClassRow/ClassLabel
@onready var proficiency_icons: Array[TextureRect] = [
	$VBox/ClassRow/ProficiencyIcons/Sword,
	$VBox/ClassRow/ProficiencyIcons/Lance,
	$VBox/ClassRow/ProficiencyIcons/Axe,
	$VBox/ClassRow/ProficiencyIcons/Bow,
	$VBox/ClassRow/ProficiencyIcons/Tome,
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
	hp_bar.max_value = unit_data.get_max_hp()
	hp_bar.value = unit_data.get_current_hp()
	hp_label.text = "%d / %d" % [unit_data.get_current_hp(), unit_data.get_max_hp()]

	stat_str.text = "Force %d" % unit_data.get_str()
	stat_mag.text = "Magie %d" % unit_data.get_mag()
	stat_skl.text = "Technique %d" % unit_data.get_skl()
	stat_spd.text = "Vitesse %d" % unit_data.get_spd()
	stat_def.text = "Defense %d" % unit_data.get_def()
	stat_res.text = "Resist. %d" % unit_data.get_res()
	stat_lck.text = "Chance %d" % unit_data.get_lck()
	stat_con.text = "Constit. %d" % unit_data.get_con()
	stat_mov.text = "Mouv %d" % unit_data.get_mov()

	var weapon := unit_data.get_equipped_weapon()
	weapon_label.text = weapon.display_name if weapon else "A mains nues"
	weapon_icon.texture = weapon.icon if weapon else null
	weapon_icon.visible = weapon_icon.texture != null

	show()

## Lights up one icon per weapon type character_class.usable_weapon_types
## allows, dims the rest rather than hiding them (so the full 5-icon set is
## always there as a reference for what exists, not just what this unit has).
func _show_proficiencies(character_class: ClassData) -> void:
	for type in PROFICIENCY_ICONS.size():
		var icon := proficiency_icons[type]
		icon.texture = PROFICIENCY_ICONS[type]
		var usable := character_class != null and character_class.can_use_weapon(type)
		icon.modulate = Color.WHITE if usable else Color(1, 1, 1, 0.25)

func hide_panel() -> void:
	hide()
