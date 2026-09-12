class_name UnitsScreen
extends Control
## "Unités" overlay opened from PrepPhase's camp menu — modeled on the
## user's Fire Emblem Engage reference: a scrollable roster list on the
## left, stats+inventory in the middle, techniques on the right (a 3-column
## layout — the first version stacked everything into one middle column,
## which grew the panel tall enough to push the Close button off-screen;
## see the fix note on ButtonsRow below). Squad membership is toggled from a
## dedicated button rather than the roster row itself, so clicking a row
## always just inspects that unit — never blocked by the deploy cap, unlike
## adding them to the squad.
##
## Techniques are shown as 3 SLOT buttons (one per
## UnitData.MAX_EQUIPPED_TECHNIQUES), not a flat list of every learned
## technique with an inline toggle — the original approach the user flagged
## as unworkable once every character has their own full 6-technique list:
## "ça va devenir infernale de chercher une technique précise." Clicking a
## slot opens PickerPanel, a bigger overlay listing every technique NOT
## currently equipped anywhere on this unit, to assign into that slot (or
## clear it).

const CARD_SCENE := preload("res://scenes/prep/RosterCard.tscn")
const EQUIP_ROW_SCENE := preload("res://scenes/ui/EquipMenuRow.tscn")

## Marks a technique as tied to one specific character (TechniqueData.is_unique)
## everywhere its name is shown here (slot buttons, picker rows, the
## "toujours actives" list) — a star prefix plus a distinct gold color, so
## it never reads as "just another technique" that could be picked for
## anyone else once a future copy-between-units system exists.
const UNIQUE_TECHNIQUE_COLOR := Color(1.0, 0.85, 0.2, 1)
const UNIQUE_TECHNIQUE_PREFIX := "★ "

signal closed
signal squad_toggled(unit_data: UnitData, in_squad: bool)

@onready var roster_list: VBoxContainer = $Panel/Margin/VBox/HBox/RosterPanel/RosterScroll/RosterList
@onready var portrait_rect: TextureRect = $Panel/Margin/VBox/HBox/StatsPanel/StatsVBox/TopRow/PortraitRect
@onready var unit_info_panel: UnitInfoPanel = $Panel/Margin/VBox/HBox/StatsPanel/StatsVBox/TopRow/UnitInfoPanel
@onready var inventory_list: VBoxContainer = $Panel/Margin/VBox/HBox/StatsPanel/StatsVBox/InventoryScroll/InventoryList
@onready var slots_list: VBoxContainer = $Panel/Margin/VBox/HBox/TechniquesPanel/TechniquesVBox/SlotsList
@onready var always_active_title_label: Label = $Panel/Margin/VBox/HBox/TechniquesPanel/TechniquesVBox/AlwaysActiveTitleLabel
@onready var always_active_list: VBoxContainer = $Panel/Margin/VBox/HBox/TechniquesPanel/TechniquesVBox/AlwaysActiveList
@onready var description_label: Label = $Panel/Margin/VBox/HBox/TechniquesPanel/TechniquesVBox/DescriptionPanel/DescriptionLabel
## Buttons live OUTSIDE the HBox (roster/stats/techniques row) on purpose —
## real bug caught live: they used to sit at the bottom of the middle
## column, so a taller techniques list grew that whole column past the
## panel's fixed height and pushed Close off-screen with no way to reach
## it. Now only the HBox row (whose own columns scroll internally) shares
## the flexible space; these buttons and Close keep a fixed height below it.
@onready var squad_toggle_button: Button = $Panel/Margin/VBox/ButtonsRow/SquadToggleButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton

## Dims (and blocks clicks to) everything behind the picker while it's open —
## real bug caught live: PickerPanel used the SAME panel_frame_style as the
## screen behind it, with no visual separation at all, so both panels'
## titles/buttons bled together and were unreadable ("trop d'UI ressemblant,
## on y comprend rien"). A plain dimmer is the standard fix for "this modal
## doesn't read as being on top of that content."
@onready var picker_dimmer: ColorRect = $PickerDimmer
@onready var picker_panel: PanelContainer = $PickerPanel
@onready var picker_title_label: Label = $PickerPanel/PickerMargin/PickerVBox/PickerTitleLabel
@onready var picker_list: VBoxContainer = $PickerPanel/PickerMargin/PickerVBox/PickerScroll/PickerList
## Its own description label, separate from the main screen's — the main
## one sits BEHIND the picker while it's open, so hovering a picker row used
## to update a label the user couldn't see at all ("le texte doit aussi
## apparaître ici").
@onready var picker_description_label: Label = $PickerPanel/PickerMargin/PickerVBox/PickerDescriptionPanel/PickerDescriptionLabel
@onready var clear_slot_button: Button = $PickerPanel/PickerMargin/PickerVBox/PickerButtonsRow/ClearSlotButton
@onready var picker_cancel_button: Button = $PickerPanel/PickerMargin/PickerVBox/PickerButtonsRow/PickerCancelButton

const DEFAULT_DESCRIPTION := "Survolez une technique pour voir son effet."

## Set by PrepPhase (see its _ready) — this screen has no grid of its own to
## work out a positional technique bonus (Serment Royale-style) with, the
## same reason Battle.gd computes its own for the in-battle panels. Left
## unset (never called) is safe: `_show_detail` only invokes it when valid.
var get_ally_def_bonus: Callable

var _cards: Dictionary = {}  # UnitData -> RosterCard
var _roster: Array[UnitData] = []
var _squad: Array[UnitData] = []
var _max_deployed: int = 4
var _viewing: UnitData = null
## Which slot (0-based index into equipped_techniques) PickerPanel is
## currently filling, or -1 while it's closed.
var _picking_slot_index: int = -1

func _ready() -> void:
	hide()
	picker_dimmer.hide()
	picker_panel.hide()
	close_button.pressed.connect(func(): closed.emit())
	squad_toggle_button.pressed.connect(_on_squad_toggle_pressed)
	clear_slot_button.pressed.connect(_on_clear_slot_pressed)
	picker_cancel_button.pressed.connect(_on_picker_cancel_pressed)

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
	picker_dimmer.hide()
	picker_panel.hide()
	_picking_slot_index = -1
	for child in inventory_list.get_children():
		child.queue_free()
	description_label.text = DEFAULT_DESCRIPTION
	if unit_data == null:
		unit_info_panel.hide_panel()
		portrait_rect.texture = null
		for child in slots_list.get_children():
			child.queue_free()
		for child in always_active_list.get_children():
			child.queue_free()
		always_active_title_label.hide()
		squad_toggle_button.disabled = true
		return

	portrait_rect.texture = unit_data.full_body if unit_data.full_body else unit_data.portrait
	var ally_def_bonus: int = get_ally_def_bonus.call(unit_data) if get_ally_def_bonus.is_valid() else 0
	unit_info_panel.show_unit(unit_data, ally_def_bonus)

	for weapon: WeaponData in unit_data.inventory:
		var row: EquipMenuRow = EQUIP_ROW_SCENE.instantiate()
		inventory_list.add_child(row)
		row.setup(weapon, 0, weapon == unit_data.get_equipped_weapon(), true)
		row.disabled = true  # display only — no equip action defined on this screen yet

	_build_slots(unit_data)

	var in_squad := _squad.has(unit_data)
	squad_toggle_button.text = "Retirer de l'escouade" if in_squad else "Ajouter à l'escouade"
	squad_toggle_button.disabled = not in_squad and _squad.size() >= _max_deployed

func _on_squad_toggle_pressed() -> void:
	if _viewing == null:
		return
	var in_squad := _squad.has(_viewing)
	squad_toggled.emit(_viewing, not in_squad)


## One button per equip slot (always exactly MAX_EQUIPPED_TECHNIQUES of
## them) showing whichever technique currently occupies it, or "Emplacement
## libre." Clicking any slot opens the picker for it. Non-conditional
## techniques (permanent stat bumps, weapon unlocks, movement changes — see
## TechniqueData.is_conditional) never occupy a slot at all — they're just
## always on — so they're summarized separately below the slots instead.
func _build_slots(unit_data: UnitData) -> void:
	for child in slots_list.get_children():
		child.queue_free()
	var equipped := unit_data.equipped_techniques
	for i in UnitData.MAX_EQUIPPED_TECHNIQUES:
		slots_list.add_child(_make_slot_button(unit_data, i, equipped[i] if i < equipped.size() else null))
	_update_always_active_label(unit_data)

func _make_slot_button(unit_data: UnitData, slot_index: int, technique: TechniqueData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	if technique:
		var name_part := (UNIQUE_TECHNIQUE_PREFIX + technique.display_name) if technique.is_unique else technique.display_name
		button.text = "%d. %s" % [slot_index + 1, name_part]
		if technique.is_unique:
			button.add_theme_color_override("font_color", UNIQUE_TECHNIQUE_COLOR)
		var description := technique.get_effect_description()
		button.mouse_entered.connect(func(): description_label.text = description)
	else:
		button.text = "%d. Emplacement libre" % (slot_index + 1)
		button.modulate = Color(1, 1, 1, 0.6)
		button.mouse_entered.connect(func(): description_label.text = "Cliquez pour choisir une technique à équiper ici.")
	button.mouse_exited.connect(func(): description_label.text = DEFAULT_DESCRIPTION)
	button.pressed.connect(_open_picker.bind(unit_data, slot_index))
	return button

func _update_always_active_label(unit_data: UnitData) -> void:
	for child in always_active_list.get_children():
		child.queue_free()
	var always_active: Array[TechniqueData] = []
	for technique: TechniqueData in unit_data.techniques:
		if technique.level_required <= unit_data.level and not technique.is_conditional():
			always_active.append(technique)
	always_active_title_label.visible = not always_active.is_empty()
	for technique in always_active:
		var label := Label.new()
		var name_part := (UNIQUE_TECHNIQUE_PREFIX + technique.display_name) if technique.is_unique else technique.display_name
		label.text = "• %s" % name_part
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", UNIQUE_TECHNIQUE_COLOR if technique.is_unique else Color(0.7, 0.85, 1.0, 1))
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		var description := technique.get_effect_description()
		label.mouse_entered.connect(func(): description_label.text = description)
		label.mouse_exited.connect(func(): description_label.text = DEFAULT_DESCRIPTION)
		always_active_list.add_child(label)

## Opens PickerPanel for `slot_index` — every LEARNED conditional technique
## NOT currently occupying some other slot is a valid pick (one already
## equipped elsewhere is excluded outright rather than shown-but-disabled;
## picking it again would be a confusing no-op). A locked (not yet reached)
## one is still listed, greyed out, so the player can see what's coming.
func _open_picker(unit_data: UnitData, slot_index: int) -> void:
	_picking_slot_index = slot_index
	picker_title_label.text = "Choisir une technique — emplacement %d" % (slot_index + 1)
	for child in picker_list.get_children():
		child.queue_free()
	var any_option := false
	for technique: TechniqueData in unit_data.techniques:
		if not technique.is_conditional() or unit_data.is_technique_equipped(technique):
			continue
		any_option = true
		picker_list.add_child(_make_picker_row(unit_data, technique))
	if not any_option:
		var empty_label := Label.new()
		empty_label.text = "Aucune autre technique disponible."
		picker_list.add_child(empty_label)
	clear_slot_button.disabled = slot_index >= unit_data.equipped_techniques.size()
	picker_description_label.text = DEFAULT_DESCRIPTION
	picker_dimmer.show()
	picker_panel.show()

func _make_picker_row(unit_data: UnitData, technique: TechniqueData) -> Control:
	var unlocked := technique.level_required <= unit_data.level
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 40)
	var name_part := (UNIQUE_TECHNIQUE_PREFIX + technique.display_name) if technique.is_unique else technique.display_name
	button.text = "%s (niv.%d)%s" % [name_part, technique.level_required, "" if unlocked else " — non débloquée"]
	button.disabled = not unlocked
	if technique.is_unique:
		button.add_theme_color_override("font_color", UNIQUE_TECHNIQUE_COLOR)
	if not unlocked:
		button.modulate = Color(1, 1, 1, 0.4)
	var description := technique.get_effect_description()
	button.mouse_entered.connect(func(): picker_description_label.text = description)
	button.mouse_exited.connect(func(): picker_description_label.text = DEFAULT_DESCRIPTION)
	button.pressed.connect(_on_picker_technique_chosen.bind(unit_data, technique))
	return button

func _on_picker_technique_chosen(unit_data: UnitData, technique: TechniqueData) -> void:
	var equipped := unit_data.equipped_techniques
	var replacing: TechniqueData = equipped[_picking_slot_index] if _picking_slot_index < equipped.size() else null
	unit_data.equip_technique(technique, replacing)
	_show_detail(unit_data)

func _on_clear_slot_pressed() -> void:
	if _viewing == null:
		return
	var equipped := _viewing.equipped_techniques
	if _picking_slot_index >= 0 and _picking_slot_index < equipped.size():
		_viewing.unequip_technique(equipped[_picking_slot_index])
	_show_detail(_viewing)

func _on_picker_cancel_pressed() -> void:
	picker_dimmer.hide()
	picker_panel.hide()
	_picking_slot_index = -1
