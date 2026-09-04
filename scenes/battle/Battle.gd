class_name Battle
extends Node2D
## Root battle scene. Owns the grid, the units, the HUD and the state
## machine, and turns raw input (mouse clicks) into the abstract
## handle_unit_clicked/handle_tile_clicked/handle_cancel events the current
## BattleState reacts to.

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")

@export var map_data: BattleMapData

@onready var grid: BattleGrid = $BattleGrid
@onready var ui: BattleHUD = $BattleHUD
@onready var state_machine: BattleStateMachine = $BattleStateMachine

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var selected_unit: Unit
var move_range: Dictionary = {}
var current_phase: int = UnitData.Team.PLAYER
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	ui.attack_pressed.connect(func(): state_machine.handle_action_chosen("attack"))
	ui.wait_pressed.connect(func(): state_machine.handle_action_chosen("wait"))
	ui.end_turn_pressed.connect(_on_end_turn_pressed)
	state_machine.setup(self)
	if map_data:
		_build_battle(map_data)
	state_machine.start("start_turn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
			var pos := grid.world_to_grid(local_pos)
			if not grid.is_in_bounds(pos):
				return
			var occupant := grid.get_occupant(pos)
			if occupant:
				state_machine.handle_unit_clicked(occupant)
			else:
				state_machine.handle_tile_clicked(pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			state_machine.handle_cancel()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		state_machine.handle_cancel()

func _on_end_turn_pressed() -> void:
	if current_phase == UnitData.Team.PLAYER:
		end_player_turn()

func _build_battle(data: BattleMapData) -> void:
	grid.setup(Vector2i(data.width, data.height), data.terrain_overrides, data.default_terrain)
	for spawn in data.spawns:
		if spawn.unit_data == null:
			continue
		# Player units come from the persistent campaign roster when one exists
		# (so HP/deaths carry between battles); enemies are always a fresh
		# duplicate so repeated fights against the same .tres don't bleed
		# leftover damage from a previous battle in the same run.
		var unit_data: UnitData = spawn.unit_data
		if spawn.unit_data.team == UnitData.Team.PLAYER:
			unit_data = GameState.get_roster_unit(spawn.unit_data.character_id)
			if unit_data == null:
				unit_data = spawn.unit_data.duplicate()
		else:
			unit_data = spawn.unit_data.duplicate()
		var unit: Unit = UNIT_SCENE.instantiate()
		add_child(unit)
		unit.setup(unit_data, spawn.spawn_position, grid)
		grid.set_occupant(spawn.spawn_position, unit)
		if unit_data.team == UnitData.Team.PLAYER:
			player_units.append(unit)
		else:
			enemy_units.append(unit)

func all_player_units_acted() -> bool:
	for unit in player_units:
		if not unit.has_acted:
			return false
	return true

func end_player_turn() -> void:
	current_phase = UnitData.Team.ENEMY
	SignalBus.turn_ended.emit()
	state_machine.change_state("start_turn")

func end_enemy_turn() -> void:
	current_phase = UnitData.Team.PLAYER
	SignalBus.turn_ended.emit()
	state_machine.change_state("start_turn")

func get_attackable_targets(unit: Unit) -> Array[Unit]:
	return get_attackable_targets_from(unit.grid_pos, unit)

func get_attackable_targets_from(from_pos: Vector2i, unit: Unit) -> Array[Unit]:
	var weapon := unit.unit_data.get_equipped_weapon()
	if weapon == null:
		return []
	var tiles := grid.get_tiles_in_range(from_pos, weapon.min_range, weapon.max_range)
	var opponents := enemy_units if unit.unit_data.team == UnitData.Team.PLAYER else player_units
	var result: Array[Unit] = []
	for tile in tiles:
		var occupant := grid.get_occupant(tile)
		if occupant and opponents.has(occupant):
			result.append(occupant)
	return result

func has_attackable_target(unit: Unit) -> bool:
	return not get_attackable_targets(unit).is_empty()

func apply_combat_aftermath(attacker: Unit, target: Unit) -> void:
	_handle_death_if_needed(attacker)
	_handle_death_if_needed(target)

func _handle_death_if_needed(unit: Unit) -> void:
	if not is_instance_valid(unit) or unit.unit_data.is_alive():
		return
	SignalBus.unit_died.emit(unit)
	GameState.on_unit_died(unit.unit_data)
	grid.clear_occupant(unit.grid_pos)
	player_units.erase(unit)
	enemy_units.erase(unit)
	unit.queue_free()

func check_battle_end() -> bool:
	if enemy_units.is_empty():
		SignalBus.battle_won.emit()
		return true
	if player_units.is_empty():
		SignalBus.battle_lost.emit()
		return true
	return false
