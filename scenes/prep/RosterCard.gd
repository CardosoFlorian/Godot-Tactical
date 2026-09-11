class_name RosterCard
extends Button
## One card in UnitsScreen's roster list, one per GameState.get_living_roster()
## unit. Same Button-wrapping-a-margin-padded-HBox pattern as EquipMenuRow
## (scenes/ui/EquipMenuRow.gd) — every child Control is mouse_filter IGNORE
## so clicks pass through to the Button underneath. Doesn't own selected/
## viewing state itself — UnitsScreen tracks both centrally and pushes them
## down via set_selected/set_viewing.

signal card_pressed(unit_data: UnitData)

@onready var portrait_rect: TextureRect = $Margin/Content/Portrait
@onready var name_label: Label = $Margin/Content/TextCol/NameLabel
@onready var class_label: Label = $Margin/Content/TextCol/ClassLabel
@onready var selected_badge: Label = $Margin/Content/SelectedBadge

var unit_data: UnitData

func _ready() -> void:
	pressed.connect(func(): card_pressed.emit(unit_data))

func setup(data: UnitData) -> void:
	unit_data = data
	portrait_rect.texture = _load_portrait(data.character_id)
	name_label.text = data.display_name
	# Always a player-roster unit here (GameState.get_living_roster()), never
	# an enemy — no leftover "Épéiste"/"Lancier" class label, just the level.
	class_label.text = "Niveau %d" % data.level
	selected_badge.visible = false

## Shows the "in squad" checkmark badge — independent of set_viewing below,
## since a card can be in the squad without currently being the one shown in
## UnitsScreen's detail pane, or vice versa.
func set_selected(value: bool) -> void:
	selected_badge.visible = value

## Highlights whichever card is currently open in UnitsScreen's detail pane.
func set_viewing(value: bool) -> void:
	modulate = Color(1, 1, 0.75) if value else Color.WHITE

## Same "look up a portrait PNG by character_id" convention LevelUpScreen
## already established — no shared portrait-lookup utility exists yet, so
## this is a second independent copy of it.
func _load_portrait(character_id: String) -> Texture2D:
	var path := "res://assets/placeholder/portraits/%s/neutral.png" % character_id
	return load(path) if ResourceLoader.exists(path) else null
