class_name EquipMenu
extends PanelContainer
## Inventory list shown by EquipMenuState — one EquipMenuRow per weapon in
## the selected unit's inventory, rebuilt from scratch each time (inventory
## size/order can change between openings), plus a Cancel button. Same
## panel_frame_style.tres as ActionMenu, same screen slot (see BattleHUD.tscn
## — the two panels are never visible at the same time, so overlapping them
## is safe).

const ROW_SCENE := preload("res://scenes/ui/EquipMenuRow.tscn")

signal weapon_selected(index: int)
signal cancel_pressed

@onready var row_list: VBoxContainer = $VBox/RowList
@onready var cancel_button: Button = $VBox/CancelButton

func _ready() -> void:
	cancel_button.pressed.connect(func(): cancel_pressed.emit())

## `for_action` ("attack"/"heal"/"support", default "" = no filter): when
## set, a weapon that's class-usable but doesn't fit that action (see
## WeaponData.matches_action) is dimmed/disabled too — used by
## WeaponPickerState so choosing, say, Soutien only offers gauntlets rather
## than the whole inventory. The plain Equip button (EquipMenuState) always
## passes "" — browsing to switch weapon has no action to filter by.
func show_for_unit(unit_data: UnitData, for_action: String = "") -> void:
	for child in row_list.get_children():
		child.queue_free()
	for i in unit_data.inventory.size():
		var weapon: WeaponData = unit_data.inventory[i]
		var row: EquipMenuRow = ROW_SCENE.instantiate()
		row_list.add_child(row)
		var is_usable := unit_data.can_use_weapon(weapon.weapon_type) and weapon.matches_action(for_action)
		row.setup(weapon, i, i == unit_data.equipped_index, is_usable)
		row.row_selected.connect(func(idx: int): weapon_selected.emit(idx))
	show()
