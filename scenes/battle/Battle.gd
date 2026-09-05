class_name Battle
extends Node2D
## Root battle scene. Owns the grid, the units, the HUD and the state
## machine, and turns raw input (mouse clicks) into the abstract
## handle_unit_clicked/handle_tile_clicked/handle_cancel events the current
## BattleState reacts to.

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")

# Combat scene staging (execute_attack / _play_combat_scene): how far the
# camera zooms in and how far each unit steps toward the other for the
# close-up clash, before everything eases back to the normal map view.
const COMBAT_SCENE_ZOOM := Vector2(4.0, 4.0)
const APPROACH_FRACTION := 0.3
const STAGE_TWEEN_DURATION := 0.25
# Beat before each strike (including the first) so the sequence reads as a
# series of distinct blows rather than a blur, plus one after the last
# strike so the outcome has a moment to sink in before the scene ends.
const PRE_STRIKE_DELAY := 0.45
const END_HOLD_DURATION := 0.5
# Units without a rigged attack animation (i.e. most of the cast right now)
# still get this little forward-and-back nudge per strike so the clash
# doesn't look like nothing happened.
const BUMP_DISTANCE := 6.0

@export var map_data: BattleMapData

@onready var grid: BattleGrid = $BattleGrid
@onready var ui: BattleHUD = $BattleHUD
@onready var state_machine: BattleStateMachine = $BattleStateMachine
@onready var camera: Camera2D = $Camera2D
@onready var combat_stats: CombatStatsHUD = $CombatStatsHUD

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var selected_unit: Unit
## Where selected_unit stood before this turn's move, set once at selection
## time (UnitSelectState.handle_unit_clicked) — not touched again while it
## stays selected, so cancelling out of ActionMenuState can always restore
## it via undo_move regardless of how many times "move" is re-entered.
var selected_unit_start_pos: Vector2i
var move_range: Dictionary = {}
var current_phase: int = UnitData.Team.PLAYER
var rng := RandomNumberGenerator.new()

var _hovered_unit: Unit = null
var _preview_target: Unit = null
var _combat_scene_active: bool = false

func _ready() -> void:
	rng.randomize()
	ui.attack_pressed.connect(func(): state_machine.handle_action_chosen("attack"))
	ui.wait_pressed.connect(func(): state_machine.handle_action_chosen("wait"))
	ui.promote_pressed.connect(func(): state_machine.handle_action_chosen("promote"))
	ui.cancel_pressed.connect(func(): state_machine.handle_cancel())
	ui.end_turn_pressed.connect(_on_end_turn_pressed)
	state_machine.setup(self)
	if map_data:
		_build_battle(map_data)
	state_machine.start("start_turn")

## Hovering a unit while idle (unit_select) previews its HP and everything
## it threatens this turn (move range in blue, attack range in red).
## Hovering a valid target while choosing who to hit (targeting) previews
## the combat stats panel instead — see _update_targeting_hover. Does
## neither while a combat scene is actually playing, so mouse movement
## during the clash can't fight the scene for control of those same panels.
func _process(_delta: float) -> void:
	if _combat_scene_active:
		return

	if state_machine.current_state_name == "targeting":
		if _hovered_unit:
			ui.hide_hover_unit()
			_hovered_unit = null
		_update_targeting_hover()
		return

	if _preview_target:
		_clear_combat_preview()

	if state_machine.current_state_name != "unit_select":
		if _hovered_unit:
			ui.hide_hover_unit()
			_hovered_unit = null
		return

	var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
	var pos := grid.world_to_grid(local_pos)
	var occupant: Unit = grid.get_occupant(pos) if grid.is_in_bounds(pos) else null
	if occupant == _hovered_unit:
		return

	if _hovered_unit:
		ui.hide_hover_unit()
		grid.clear_highlight()
	_hovered_unit = occupant
	if occupant:
		ui.show_hover_unit(occupant.unit_data)
		var reachable := grid.compute_move_range(occupant.grid_pos, occupant.unit_data.get_mov(), occupant.unit_data.team, occupant.unit_data.get_movement_type())
		show_unit_range(occupant, reachable)

## Previews the combat stats panel (see CombatStatsHUD) when hovering a
## valid attack target during TargetingState — no camera zoom, no unit
## movement, no strike animation, just the two panels showing what would
## happen at current HP if you clicked. Clicking through still goes
## through the full _play_combat_scene.
func _update_targeting_hover() -> void:
	var targeting_state := state_machine.current_state as TargetingState
	if targeting_state == null:
		return
	var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
	var pos := grid.world_to_grid(local_pos)
	var occupant: Unit = grid.get_occupant(pos) if grid.is_in_bounds(pos) else null
	if occupant == _preview_target:
		return
	_preview_target = occupant
	if occupant and targeting_state.valid_targets.has(occupant):
		# Ghost preview on here (before you've committed to the attack) —
		# see _play_combat_scene for why it's off once strikes start landing.
		# No HP override: nothing has happened yet, so live current HP IS
		# the real starting point.
		_display_combat_stats(selected_unit, occupant, _compute_combat_stats(selected_unit, occupant), true)
	else:
		_clear_combat_preview()

## The player's unit is always the left panel and the enemy's always the
## right one, regardless of attacker/defender role or where they're
## actually standing on the map — matching map position instead was
## confusing (which side a unit shows on would flip depending on whether it
## attacked from the west or east). Shared by the real combat scene and the
## TargetingState hover preview so both show identical panels.
##
## `attacker_hp`/`defender_hp` are the HP values to actually display; pass
## -1 (the default) to just read current live HP, or a snapshot taken
## before CombatResolver ran — see execute_attack — so the scene starts
## from the real pre-fight numbers instead of the already-resolved ones.
func _display_combat_stats(attacker: Unit, defender: Unit, stats: Dictionary, show_ghost: bool,
		attacker_hp: int = -1, defender_hp: int = -1) -> void:
	if attacker.unit_data.team == UnitData.Team.PLAYER:
		combat_stats.show_combat(
			attacker.unit_data, stats["attacker_dmg"], stats["attacker_hit"], stats["attacker_crit"], true,
			defender.unit_data, stats["defender_dmg"], stats["defender_hit"], stats["defender_crit"], stats["defender_can_counter"],
			show_ghost, attacker_hp, defender_hp)
	else:
		combat_stats.show_combat(
			defender.unit_data, stats["defender_dmg"], stats["defender_hit"], stats["defender_crit"], stats["defender_can_counter"],
			attacker.unit_data, stats["attacker_dmg"], stats["attacker_hit"], stats["attacker_crit"], true,
			show_ghost, defender_hp, attacker_hp)

func _clear_combat_preview() -> void:
	_preview_target = null
	combat_stats.hide_combat()

## Move range in blue is the base; attack range is only drawn red on the
## tiles it adds BEYOND the move range (the "can't stand here but could
## still get hit" ring), so tiles you can actually walk onto stay blue.
## Tiles occupied by one of `unit`'s own teammates are excluded from that
## red ring entirely, since it could never attack them. Used both for the
## idle hover preview and for the selected unit's own MoveState display, so
## the attack ring doesn't disappear the moment you actually pick a unit.
func show_unit_range(unit: Unit, reachable: Dictionary) -> void:
	var move_tiles: Array[Vector2i] = []
	move_tiles.assign(reachable.keys())
	grid.show_highlight(move_tiles, grid.HIGHLIGHT_MOVE)

	var weapon := unit.unit_data.get_equipped_weapon()
	if weapon == null:
		return
	var attack_only_tiles := {}
	for tile in reachable:
		for t in grid.get_tiles_in_range(tile, weapon.min_range, weapon.max_range):
			if reachable.has(t):
				continue
			var occupant := grid.get_occupant(t)
			if occupant and occupant.unit_data.team == unit.unit_data.team:
				continue
			attack_only_tiles[t] = true
	var attack_list: Array[Vector2i] = []
	attack_list.assign(attack_only_tiles.keys())
	grid.show_highlight(attack_list, grid.HIGHLIGHT_ATTACK)

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

## Snaps `unit` back to selected_unit_start_pos and clears has_moved, so
## ActionMenuState.handle_cancel can send the player back to "move" instead
## of being stuck committing to whatever tile they moved to. Instant, no
## tween back — the player is about to immediately pick a new destination.
func undo_move(unit: Unit) -> void:
	grid.clear_occupant(unit.grid_pos)
	unit.grid_pos = selected_unit_start_pos
	unit.position = grid.grid_to_world(selected_unit_start_pos)
	unit.has_moved = false
	grid.set_occupant(selected_unit_start_pos, unit)

## Resolves a full attack (distance, terrain bonuses, RNG, HP application,
## death handling) between two units already in position. Shared by manual
## targeting (TargetingState) and click-to-attack (MoveState moving a unit
## into range and immediately striking).
func execute_attack(attacker: Unit, defender: Unit) -> void:
	var distance := absi(attacker.grid_pos.x - defender.grid_pos.x) + absi(attacker.grid_pos.y - defender.grid_pos.y)
	var attacker_terrain := grid.get_terrain_combat_bonus(attacker.grid_pos)
	var defender_terrain := grid.get_terrain_combat_bonus(defender.grid_pos)
	SignalBus.combat_started.emit(attacker, defender)

	# CombatResolver applies every strike's HP change immediately, all at
	# once — so by the time the scene plays, unit_data already holds the
	# post-combat numbers. Snapshot the real pre-fight HP here so the panels
	# can start from there and count down in step with the log instead of
	# starting already at the end result.
	var attacker_hp_before := attacker.unit_data.get_current_hp()
	var defender_hp_before := defender.unit_data.get_current_hp()
	var stats := _compute_combat_stats(attacker, defender)
	var result := CombatResolver.resolve_combat(attacker.unit_data, defender.unit_data, distance, rng, attacker_terrain, defender_terrain)
	SignalBus.combat_resolved.emit(result)

	await _play_combat_scene(attacker, defender, result["log"], stats, attacker_hp_before, defender_hp_before)
	apply_combat_aftermath(attacker, defender)
	if is_instance_valid(attacker):
		attacker.has_acted = true

## Dmg/Hit/Crit each combatant would deal against the other at their
## current positions — used both for the real combat scene and for the
## hover preview in TargetingState (see _update_targeting_hover), so both
## show exactly the same numbers.
func _compute_combat_stats(attacker: Unit, defender: Unit) -> Dictionary:
	var distance := absi(attacker.grid_pos.x - defender.grid_pos.x) + absi(attacker.grid_pos.y - defender.grid_pos.y)
	var attacker_terrain := grid.get_terrain_combat_bonus(attacker.grid_pos)
	var defender_terrain := grid.get_terrain_combat_bonus(defender.grid_pos)
	var defender_can_counter := CombatResolver.is_in_weapon_range(distance, defender.unit_data.get_equipped_weapon())
	return {
		"attacker_hit": CombatResolver.get_hit_chance(attacker.unit_data, defender.unit_data, defender_terrain["avoid"]),
		"attacker_dmg": CombatResolver.get_damage(attacker.unit_data, defender.unit_data, defender_terrain["def"]),
		"attacker_crit": CombatResolver.get_crit_chance(attacker.unit_data, defender.unit_data),
		"defender_hit": CombatResolver.get_hit_chance(defender.unit_data, attacker.unit_data, attacker_terrain["avoid"]) if defender_can_counter else 0,
		"defender_dmg": CombatResolver.get_damage(defender.unit_data, attacker.unit_data, attacker_terrain["def"]) if defender_can_counter else 0,
		"defender_crit": CombatResolver.get_crit_chance(defender.unit_data, attacker.unit_data) if defender_can_counter else 0,
		"defender_can_counter": defender_can_counter,
	}

## Zooms the camera in on the pair and steps them toward each other, shows
## the stat panels, plays each strike from `log` in order (real swing
## animation for a rigged unit like Aurora, a small forward-and-back nudge
## otherwise) updating HP bars as they land, then eases the camera, units
## and panels back to how they were. HP/death were already applied inside
## CombatResolver.resolve_combat by the time this runs — this is
## presentation only.
func _play_combat_scene(attacker: Unit, defender: Unit, log: Array, stats: Dictionary,
		attacker_hp_before: int, defender_hp_before: int) -> void:
	_combat_scene_active = true
	var original_camera_pos := camera.position
	var original_camera_zoom := camera.zoom
	var attacker_start := attacker.position
	var defender_start := defender.position
	var approach: Vector2 = defender_start - attacker_start

	# Face each other for the clash — facing only ever changes left/right
	# (see Unit.facing_left), so this is skipped if they're stacked vertically.
	if approach.x > 0:
		attacker.facing_left = false
		defender.facing_left = true
	elif approach.x < 0:
		attacker.facing_left = true
		defender.facing_left = false

	var stage_tween := create_tween().set_parallel(true)
	stage_tween.tween_property(camera, "position", (attacker_start + defender_start) / 2.0, STAGE_TWEEN_DURATION)
	stage_tween.tween_property(camera, "zoom", COMBAT_SCENE_ZOOM, STAGE_TWEEN_DURATION)
	stage_tween.tween_property(attacker, "position", attacker_start + approach * APPROACH_FRACTION, STAGE_TWEEN_DURATION)
	stage_tween.tween_property(defender, "position", defender_start - approach * APPROACH_FRACTION, STAGE_TWEEN_DURATION)

	# No ghost preview here: the strikes are about to actually land, so both
	# bars should just start at real current HP and count down for real as
	# each one connects (see the strike loop below) — not show a guessed
	# "if this hits" value that then has to visibly correct itself when a
	# strike misses or crits differently than predicted. Pass the pre-fight
	# HP snapshot rather than live data (already post-combat by now — see
	# execute_attack), so the bars actually have somewhere to count down from.
	_display_combat_stats(attacker, defender, stats, false, attacker_hp_before, defender_hp_before)
	await stage_tween.finished

	for strike in log:
		var source: Unit = attacker if strike["source"] == attacker.unit_data else defender
		if not is_instance_valid(source):
			continue
		await get_tree().create_timer(PRE_STRIKE_DELAY).timeout
		var bump_dir := approach.normalized() if source == attacker else -approach.normalized()
		var bump_start := source.position
		# Lunge forward and HOLD there for the whole swing (rather than
		# bouncing back on its own fixed timer) so a rigged unit's ~1s
		# animation doesn't finish standing back at rest — the two used to
		# run on unrelated clocks and looked disconnected.
		var lunge_out := create_tween()
		lunge_out.tween_property(source, "position", bump_start + bump_dir * BUMP_DISTANCE, 0.1)
		await lunge_out.finished
		await source.play_attack_animation()
		var lunge_back := create_tween()
		lunge_back.tween_property(source, "position", bump_start, 0.15)
		await lunge_back.finished
		combat_stats.update_hp(strike["target"], strike["target_hp_after"])

		var target: Unit = attacker if strike["target"] == attacker.unit_data else defender
		if not strike["hit"]:
			_show_strike_message(target, "Rate !", Color.WHITE)
		elif strike["crit"]:
			_show_strike_message(target, "Critique ! -%d" % strike["damage"], Color(1.0, 0.85, 0.2))
		else:
			_show_strike_message(target, "-%d" % strike["damage"], Color(1.0, 0.4, 0.4))

	await get_tree().create_timer(END_HOLD_DURATION).timeout
	combat_stats.hide_combat()

	var unstage_tween := create_tween().set_parallel(true)
	unstage_tween.tween_property(camera, "position", original_camera_pos, STAGE_TWEEN_DURATION)
	unstage_tween.tween_property(camera, "zoom", original_camera_zoom, STAGE_TWEEN_DURATION)
	if is_instance_valid(attacker):
		unstage_tween.tween_property(attacker, "position", attacker_start, STAGE_TWEEN_DURATION)
	if is_instance_valid(defender):
		unstage_tween.tween_property(defender, "position", defender_start, STAGE_TWEEN_DURATION)
	await unstage_tween.finished
	_combat_scene_active = false

## Brief floating text over `target`: "Rate !" on a miss, "-N" on an
## ordinary hit, "Critique ! -N" on a crit — so damage and the two special
## cases are all readable at a glance instead of only inferable from how
## much the HP bar moved.
const STRIKE_MESSAGE_WIDTH := 220.0

func _show_strike_message(target: Unit, text: String, color: Color) -> void:
	if not is_instance_valid(target):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 10
	# Fixed width, centered on the target regardless of text length ("Rate !"
	# vs "Critique ! -30") — anchoring off the label's own auto-sized width
	# would need it in the tree a frame early to measure correctly.
	label.custom_minimum_size = Vector2(STRIKE_MESSAGE_WIDTH, 0)
	label.size = Vector2(STRIKE_MESSAGE_WIDTH, 32)
	label.position = target.position + Vector2(-STRIKE_MESSAGE_WIDTH / 2.0, -70)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tween.tween_callback(label.queue_free)

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
