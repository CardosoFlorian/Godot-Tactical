class_name UnitInfoPanel
extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var class_label: Label = $VBox/ClassLabel
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
@onready var weapon_label: Label = $VBox/MovWeaponRow/WeaponLabel

func _ready() -> void:
	hide()

func show_unit(unit_data: UnitData) -> void:
	name_label.text = unit_data.display_name
	var class_name_text := unit_data.character_class.display_name if unit_data.character_class else "?"
	class_label.text = "%s Niv.%d" % [class_name_text, unit_data.level]
	hp_bar.max_value = unit_data.get_max_hp()
	hp_bar.value = unit_data.get_current_hp()
	hp_label.text = "%d / %d" % [unit_data.get_current_hp(), unit_data.get_max_hp()]

	stat_str.text = "Force %d" % unit_data.get_str()
	stat_mag.text = "Magie %d" % unit_data.get_mag()
	stat_skl.text = "Adresse %d" % unit_data.get_skl()
	stat_spd.text = "Vitesse %d" % unit_data.get_spd()
	stat_def.text = "Defense %d" % unit_data.get_def()
	stat_res.text = "Resist. %d" % unit_data.get_res()
	stat_lck.text = "Chance %d" % unit_data.get_lck()
	stat_con.text = "Constit. %d" % unit_data.get_con()
	stat_mov.text = "Mouv %d" % unit_data.get_mov()

	var weapon := unit_data.get_equipped_weapon()
	weapon_label.text = weapon.display_name if weapon else "A mains nues"

	show()

func hide_panel() -> void:
	hide()
