class_name UnitsScreen
extends Control
## "Unités" overlay opened from PrepPhase's camp menu — modeled on the
## user's Fire Emblem Engage reference: a scrollable roster list on the
## left, the selected unit's full detail (portrait, stats via UnitInfoPanel,
## inventory, techniques) on the right. Squad membership is toggled from a
## dedicated button in the detail pane rather than the row itself, so
## clicking a row always just inspects that unit — never blocked by the
## deploy cap, unlike adding them to the squad.

const CARD_SCENE := preload("res://scenes/prep/RosterCard.tscn")
const EQUIP_ROW_SCENE := preload("res://scenes/ui/EquipMenuRow.tscn")

signal closed
signal squad_toggled(unit_data: UnitData, in_squad: bool)

@onready var roster_list: VBoxContainer = $Panel/Margin/VBox/HBox/RosterPanel/RosterScroll/RosterList
@onready var portrait_rect: TextureRect = $Panel/Margin/VBox/HBox/DetailPanel/DetailVBox/TopRow/PortraitRect
@onready var unit_info_panel: UnitInfoPanel = $Panel/Margin/VBox/HBox/DetailPanel/DetailVBox/TopRow/UnitInfoPanel
@onready var inventory_list: VBoxContainer = $Panel/Margin/VBox/HBox/DetailPanel/DetailVBox/InventoryScroll/InventoryList
@onready var techniques_label: Label = $Panel/Margin/VBox/HBox/DetailPanel/DetailVBox/TechniquesLabel
@onready var squad_toggle_button: Button = $Panel/Margin/VBox/HBox/DetailPanel/DetailVBox/SquadToggleButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

var _cards: Dictionary = {}  # UnitData -> RosterCard
var _roster: Array[UnitData] = []
var _squad: Array[UnitData] = []
var _max_deployed: int = 4
var _viewing: UnitData = null

func _ready() -> void:
	hide()
	close_button.pressed.connect(func(): closed.emit())
	squad_toggle_button.pressed.connect(_on_squad_toggle_pressed)

func show_roster(roster: Array[UnitData], squad: Array[UnitData], max_deployed: int) -> void:
	_roster = roster
	_squad = squad
	_max_deployed = max_deployed
	if _viewing == null or not _roster.has(_viewing):
		_viewing = _roster[0] if not _roster.is_empty() else null
	_build_roster_list()
	_show_detail(_viewing)

func _build_roster_list() -> void:
	for child in roster_list.get_children():
		child.queue_free()
	_cards.clear()
	for unit_data in _roster:
		var card: RosterCard = CARD_SCENE.instantiate()
		roster_list.add_child(card)
		card.setup(unit_data)
		card.set_selected(_squad.has(unit_data))
		card.set_viewing(unit_data == _viewing)
		card.card_pressed.connect(_on_card_pressed)
		_cards[unit_data] = card

func _on_card_pressed(unit_data: UnitData) -> void:
	_show_detail(unit_data)
	for other: UnitData in _cards:
		_cards[other].set_viewing(other == unit_data)

func _show_detail(unit_data: UnitData) -> void:
	_viewing = unit_data
	for child in inventory_list.get_children():
		child.queue_free()
	if unit_data == null:
		unit_info_panel.hide_panel()
		portrait_rect.texture = null
		techniques_label.text = ""
		squad_toggle_button.disabled = true
		return

	portrait_rect.texture = unit_data.full_body if unit_data.full_body else unit_data.portrait
	unit_info_panel.show_unit(unit_data)

	for weapon: WeaponData in unit_data.inventory:
		var row: EquipMenuRow = EQUIP_ROW_SCENE.instantiate()
		inventory_list.add_child(row)
		row.setup(weapon, 0, weapon == unit_data.get_equipped_weapon(), true)
		row.disabled = true  # display only — no equip action defined on this screen yet

	if unit_data.techniques.is_empty():
		techniques_label.text = "Aucune technique apprise."
	else:
		var names: Array[String] = []
		for technique: TechniqueData in unit_data.techniques:
			names.append(technique.display_name)
		techniques_label.text = ", ".join(names)

	var in_squad := _squad.has(unit_data)
	squad_toggle_button.text = "Retirer de l'escouade" if in_squad else "Ajouter à l'escouade"
	squad_toggle_button.disabled = not in_squad and _squad.size() >= _max_deployed

func _on_squad_toggle_pressed() -> void:
	if _viewing == null:
		return
	var in_squad := _squad.has(_viewing)
	squad_toggled.emit(_viewing, not in_squad)
