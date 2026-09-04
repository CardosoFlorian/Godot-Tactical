class_name UnitInfoPanel
extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var hp_label: Label = $VBox/HPBar/HPLabel

func _ready() -> void:
	hide()

func show_unit(unit_data: UnitData) -> void:
	name_label.text = unit_data.display_name
	hp_bar.max_value = unit_data.get_max_hp()
	hp_bar.value = unit_data.get_current_hp()
	hp_label.text = "%d / %d" % [unit_data.get_current_hp(), unit_data.get_max_hp()]
	show()

func hide_panel() -> void:
	hide()
