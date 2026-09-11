class_name PrepPhase
extends Control
## Camp screen shown over the live battle map before every fight — run by
## CampaignFlow before every battle step (see CampaignFlow._start_prep).
## Modeled directly on the user's Fire Emblem Engage reference: a small
## corner menu (Combattre!/Unités/Inventaire) sits over the actual map, with
## the squad already auto-placed on it; "Unités" opens a roster+detail
## overlay to change who's deployed and inspect them, "Inventaire" opens a
## convoy overlay to move gear between any two recruited units, and
## "Combattre !" locks in the current squad/positions.
##
## Doesn't touch BattleStateMachine — that machine and every BattleState
## assume a live Battle with units already spawned, which doesn't exist yet
## here. Drives its own BattleGrid instance directly instead. Placed units
## are real Unit.tscn instances (same scene Battle.gd spawns), not a
## placeholder — that's what gets their actual idle sprite/rig, team tint
## and facing for free via Unit._refresh_sprite, instead of reinventing a
## second, worse rendering path here. grid.set_occupant/get_occupant (same
## API Battle.gd's own movement code uses) is the single source of truth for
## who's standing where — no separate position bookkeeping on this side.

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")

@export var map_data: BattleMapData

signal prep_confirmed(deployment: Dictionary)  # UnitData -> Vector2i

@onready var grid: BattleGrid = $BattleGrid
@onready var camera: Camera2D = $Camera2D
@onready var ui_layer: CanvasLayer = $UI
@onready var menu_panel: PanelContainer = $UI/MenuPanel
@onready var fight_button: Button = $UI/MenuPanel/VBox/FightButton
@onready var units_button: Button = $UI/MenuPanel/VBox/UnitsButton
@onready var inventory_button: Button = $UI/MenuPanel/VBox/InventoryButton
@onready var observe_button: Button = $UI/MenuPanel/VBox/ObserveButton
@onready var hint_label: Label = $UI/HintLabel
@onready var back_button: Button = $UI/BackButton
@onready var hover_info_panel: UnitInfoPanel = $UI/HoverInfoPanel
@onready var units_screen: UnitsScreen = $UI/UnitsScreen
@onready var convoy_screen: ConvoyScreen = $UI/ConvoyScreen

var _roster: Array[UnitData] = []
var _squad: Array[UnitData] = []
var _unit_nodes: Dictionary = {}  # UnitData -> Unit
var _armed_unit: UnitData = null
var _armed_node: Unit = null
## "Observer" mode: map clicks stop placing units, hovering ANY unit (ally
## or enemy) shows their stats in hover_info_panel instead — same
## poll-the-mouse-every-frame pattern Battle.gd's own _process hover uses
## (see Battle._process/ui.show_hover_unit), just against this screen's own
## panel instead of going through a BattleHUD.
var _observing: bool = false
var _hovered_unit: Unit = null

func _ready() -> void:
	# Root Control defaults to mouse_filter STOP, which swallows every click
	# before it reaches _unhandled_input below — real bug caught live (the
	# same recurring gotcha documented in combat_ui_click_blocking): nothing
	# on the map was clickable at all until this was set explicitly.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.visible = visible
	fight_button.pressed.connect(_on_fight_pressed)
	units_button.pressed.connect(_on_units_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	observe_button.pressed.connect(_on_observe_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.hide()
	units_screen.closed.connect(_on_subscreen_closed)
	units_screen.squad_toggled.connect(_on_squad_toggled)
	convoy_screen.closed.connect(_on_subscreen_closed)

	grid.setup(Vector2i(map_data.width, map_data.height), map_data.terrain_overrides, map_data.default_terrain)
	grid.clear_highlight()
	# Same green as the in-battle heal-targeting highlight (HIGHLIGHT_HEAL) —
	# reused deliberately for visual consistency with the rest of the game,
	# rather than a one-off deploy-only color.
	grid.show_highlight(map_data.deployment_zone, grid.HIGHLIGHT_HEAL)
	camera.make_current()

	_spawn_enemies()
	_roster = GameState.get_living_roster()
	_squad = _roster.slice(0, map_data.max_deployed)
	_auto_place_squad()
	_update_hint()

## Enemies are visible on the camp map from the start (not just once
## "Observer" is opened) — lets their rig/texture cost land here, spread out
## while the player is still on the roster/convoy screens, rather than all
## landing in the same frame as Battle.tscn's own spawn once "Combattre !"
## is pressed. Fresh duplicates, same reasoning as Battle._build_battle's
## own enemy loop: repeated fights against the same .tres shouldn't bleed
## leftover damage from a previous run.
func _spawn_enemies() -> void:
	for spawn in map_data.spawns:
		if spawn.unit_data == null or spawn.unit_data.team != UnitData.Team.ENEMY:
			continue
		var unit: Unit = UNIT_SCENE.instantiate()
		add_child(unit)
		unit.setup(spawn.unit_data.duplicate(), spawn.spawn_position, grid)
		grid.set_occupant(spawn.spawn_position, unit)

## Fills every squad member without a placement onto the first free
## deployment_zone tile, in order — the default formation the player sees on
## entering camp (matches the reference: units already standing on the map,
## free to be picked up and moved rather than placed from nothing).
func _auto_place_squad() -> void:
	for unit_data in _squad:
		if _unit_nodes.has(unit_data):
			continue
		for pos in map_data.deployment_zone:
			if grid.get_occupant(pos) == null:
				_place_unit(unit_data, pos)
				break

func _place_unit(unit_data: UnitData, pos: Vector2i) -> void:
	var unit: Unit = UNIT_SCENE.instantiate()
	add_child(unit)
	unit.setup(unit_data, pos, grid)
	grid.set_occupant(pos, unit)
	_unit_nodes[unit_data] = unit

func _remove_unit(unit_data: UnitData) -> void:
	var unit: Unit = _unit_nodes.get(unit_data)
	if unit == null:
		return
	grid.clear_occupant(unit.grid_pos)
	unit.queue_free()
	_unit_nodes.erase(unit_data)

func get_placements() -> Dictionary:
	var placements := {}
	for unit_data: UnitData in _unit_nodes:
		placements[unit_data] = _unit_nodes[unit_data].grid_pos
	return placements

## Polls the mouse every frame, same pattern Battle.gd's own hover preview
## uses (see Battle._process) — only active in Observer mode, where hovering
## ANY unit (ally or enemy) should show its stats regardless of the normal
## placement rules.
func _process(_delta: float) -> void:
	if not _observing:
		return
	var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
	var pos := grid.world_to_grid(local_pos)
	var occupant: Unit = grid.get_occupant(pos) if grid.is_in_bounds(pos) else null
	if occupant == _hovered_unit:
		return
	_hovered_unit = occupant
	if occupant:
		hover_info_panel.show_unit(occupant.unit_data)
	else:
		hover_info_panel.hide_panel()

func _on_observe_pressed() -> void:
	_observing = true
	menu_panel.hide()
	hint_label.hide()
	back_button.show()

func _on_back_pressed() -> void:
	_observing = false
	_hovered_unit = null
	hover_info_panel.hide_panel()
	back_button.hide()
	menu_panel.show()
	hint_label.show()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or units_screen.visible or convoy_screen.visible or _observing:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
	var pos := grid.world_to_grid(local_pos)
	if not map_data.deployment_zone.has(pos):
		return
	var occupant := grid.get_occupant(pos)
	if occupant != null:
		# Pick back up — re-arm whoever's standing there so they can be moved.
		# Just hides/detaches the SAME node rather than freeing it (see
		# _place_armed_node below) — freeing and re-instantiating a rigged
		# unit on every single click caused a real, visible stutter each time
		# a unit was repositioned.
		_armed_unit = occupant.unit_data
		_armed_node = occupant
		grid.clear_occupant(pos)
		occupant.hide()
		_update_hint()
	elif _armed_unit != null:
		_place_armed_node(pos)
		_armed_unit = null
		_armed_node = null
		_update_hint()

## Repositions the already-instanced armed unit node instead of destroying
## and recreating it — see the note on pickup above.
func _place_armed_node(pos: Vector2i) -> void:
	_armed_node.grid_pos = pos
	_armed_node.position = grid.grid_to_world(pos)
	_armed_node.show()
	grid.set_occupant(pos, _armed_node)

func _update_hint() -> void:
	if _armed_unit != null:
		hint_label.text = "Cliquez une tuile en surbrillance pour placer %s." % _armed_unit.display_name
	else:
		hint_label.text = "Cliquez une unité sur la carte pour la déplacer."

func _on_fight_pressed() -> void:
	if _squad.is_empty():
		return
	prep_confirmed.emit(get_placements())

func _on_units_pressed() -> void:
	units_screen.show_roster(_roster, _squad, map_data.max_deployed)
	units_screen.show()

func _on_inventory_pressed() -> void:
	convoy_screen.show_roster(_roster)
	convoy_screen.show()

func _on_subscreen_closed() -> void:
	units_screen.hide()
	convoy_screen.hide()

## UnitsScreen doesn't place units itself (it has no grid) — it just reports
## who joined/left the squad; PrepPhase keeps the map in sync: a dropped
## unit disappears from it immediately, a newly added one gets auto-placed
## on the next free zone tile (same rule _auto_place_squad uses on entry).
func _on_squad_toggled(unit_data: UnitData, in_squad: bool) -> void:
	if in_squad:
		if not _squad.has(unit_data):
			_squad.append(unit_data)
		_auto_place_squad()
	else:
		_squad.erase(unit_data)
		_remove_unit(unit_data)
	units_screen.show_roster(_roster, _squad, map_data.max_deployed)
