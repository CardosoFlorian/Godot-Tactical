class_name ConvoyScreen
extends Control
## "Inventaire" overlay opened from PrepPhase's camp menu: transfer weapons
## between ANY two recruited units (not just the deployed squad — a
## full-roster convoy was the user's own explicit call, so gear can reach a
## unit left at camp). Reuses EquipMenuRow exactly as EquipMenu does for its
## own inventory rows. Unlike EquipMenu, a row here stays clickable even
## when the RECEIVING unit couldn't wield it — carrying gear for later is
## valid in a convoy, only actually equipping-to-fight enforces class
## usability.

const EQUIP_ROW_SCENE := preload("res://scenes/ui/EquipMenuRow.tscn")

signal closed

@onready var source_option: OptionButton = $Panel/Margin/VBox/HBox/SourceCol/SourceOption
@onready var target_option: OptionButton = $Panel/Margin/VBox/HBox/TargetCol/TargetOption
@onready var source_list: VBoxContainer = $Panel/Margin/VBox/HBox/SourceCol/SourceScroll/SourceList
@onready var target_list: VBoxContainer = $Panel/Margin/VBox/HBox/TargetCol/TargetScroll/TargetList
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _roster: Array[UnitData] = []

func _ready() -> void:
	hide()
	close_button.pressed.connect(func(): closed.emit())
	source_option.item_selected.connect(func(_i): _refresh_lists())
	target_option.item_selected.connect(func(_i): _refresh_lists())

func show_roster(roster: Array[UnitData]) -> void:
	_roster = roster
	source_option.clear()
	target_option.clear()
	for unit_data in _roster:
		source_option.add_item(unit_data.display_name)
		target_option.add_item(unit_data.display_name)
	if _roster.size() > 1:
		target_option.select(1)
	_refresh_lists()

func _refresh_lists() -> void:
	for child in source_list.get_children():
		child.queue_free()
	for child in target_list.get_children():
		child.queue_free()
	if _roster.is_empty():
		return
	var source_unit := _roster[source_option.selected]
	var target_unit := _roster[target_option.selected]
	_populate_list(source_list, source_unit, target_unit)
	_populate_list(target_list, target_unit, source_unit)

func _populate_list(list: VBoxContainer, owner_unit: UnitData, other_unit: UnitData) -> void:
	for i in owner_unit.inventory.size():
		var weapon: WeaponData = owner_unit.inventory[i]
		var row: EquipMenuRow = EQUIP_ROW_SCENE.instantiate()
		list.add_child(row)
		row.setup(weapon, i, i == owner_unit.equipped_index, other_unit.can_use_weapon(weapon.weapon_type))
		row.disabled = false  # convoy allows moving gear the OTHER unit can't use yet — only the dim stays
		row.row_selected.connect(_on_row_selected.bind(owner_unit, other_unit))

func _on_row_selected(index: int, owner_unit: UnitData, other_unit: UnitData) -> void:
	owner_unit.transfer_weapon_to(other_unit, index)
	_refresh_lists()
