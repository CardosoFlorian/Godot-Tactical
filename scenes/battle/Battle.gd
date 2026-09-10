class_name Battle
extends Node2D
## Root battle scene. Owns the grid, the units, the HUD and the state
## machine, and turns raw input (mouse clicks) into the abstract
## handle_unit_clicked/handle_tile_clicked/handle_cancel events the current
## BattleState reacts to.

const UNIT_SCENE := preload("res://scenes/battle/Unit.tscn")
const IMPACT_EFFECT_SCENE := preload("res://scenes/battle/effects/ImpactEffect.tscn")
const HEAL_EFFECT_SCENE := preload("res://scenes/battle/effects/HealEffect.tscn")
const SUPPORT_EFFECT_SCENE := preload("res://scenes/battle/effects/SupportEffect.tscn")
## Whoosh sound for a missed strike — weapon-agnostic (same sound for melee/
## bow/tome misses), unlike the weapon-typed impact sounds a landed hit
## uses, since nothing actually connects on a miss for a weapon type to
## color. Played via _play_miss_sound, not a full ImpactEffect (no particle
## burst — a miss has nothing to show a burst at).
const SOUND_MISS := preload("res://assets/audio/sfx/miss.mp3")
## Plays the instant the crit cut-in portrait appears — see _play_crit_portrait.
const SOUND_CRIT_PORTRAIT := preload("res://assets/audio/sfx/crit_portrait.mp3")


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

# Crit "hit-stop": a brief global slowdown + gray screen flash, only on a
# critical hit landing — see _play_crit_hitstop. HITSTOP_DURATION is REAL
# seconds (the timer that restores time_scale explicitly ignores time_scale
# itself — see create_timer's 4th arg — otherwise a slowed time_scale would
# make its own restore timer take longer to fire, stretching the freeze).
## Less extreme than the first pass (0.12) — a near-total freeze left the
## crit burst's own animation (which has no way to ignore Engine.time_scale,
## unlike the flash tween below) barely advancing during the dip, so almost
## the whole thing played in a rush right as time_scale reset. 0.3 still
## reads as a clear slowdown but gives the burst room to actually animate
## through the freeze instead of racing to catch up after it.
const HITSTOP_TIME_SCALE := 0.3
const HITSTOP_DURATION := 0.2
const CRIT_FLASH_PEAK_ALPHA := 0.45
# Real seconds — the flash tween explicitly ignores time_scale (see
# _play_crit_hitstop), so these aren't stretched/compressed by the
# slowdown the way an ordinary tween sharing the same window would be.
const CRIT_FLASH_IN_DURATION := 0.05
const CRIT_FLASH_OUT_DURATION := 0.35

## Fire Emblem-style crit cut-in: a horizontal letterbox band (not the full
## screen — first pass did that and the user rejected it, see the fix note
## below) showing a TIGHT crop of just the attacker's eyes/brow from their
## "mad" VN expression portrait (see DialogueCharacters' *_PORTRAITS dicts —
## reused as-is rather than commissioning dedicated crit art), held briefly,
## then removed before the normal impact effect/hit-stop plays. Only the 4
## named companions have VN portraits at all — anything else (every current
## enemy) has no entry here and skips the cut-in entirely, falling back to
## just the flash+hit-stop. "mad" specifically (not each character's own
## default), per the user's own call: a character's default/neutral
## expression can read as cheerful (e.g. Martin's), which looks wrong for a
## critical hit.
##
## `crop` is a Rect2 in the SOURCE image's own pixel coordinates (each
## portrait has a different canvas size/composition, so this can't be one
## shared rect) — found by eye, cropping around each portrait's eyes/brow
## the same tight way the real Fire Emblem cut-in does. Applied via an
## AtlasTexture (region) rather than TextureRect's own stretch/expand modes,
## which only scale the WHOLE image, not crop a sub-region of it.
## Each rect is centered vertically on that character's own eye line (found
## with a Y-coordinate grid overlaid on the source portrait, not eyeballed
## off a thumbnail) — Martin's face sits much higher in his canvas than the
## other three (his eyes are around y=95 of a 390-tall image, vs. Kessa's
## ~180 of 449), so reusing one character's rect shape on another would NOT
## center correctly; each needed its own independent placement.
const CRIT_PORTRAIT_DATA := {
	"aurora": {"path": "res://assets/placeholder/portraits/aurora/mad.png", "crop": Rect2(30, 88, 310, 105)},
	"lycith": {"path": "res://assets/placeholder/portraits/lycith/mad.png", "crop": Rect2(30, 95, 310, 110)},
	"martin": {"path": "res://assets/placeholder/portraits/martin/mad.png", "crop": Rect2(60, 50, 260, 90)},
	"kessa": {"path": "res://assets/placeholder/portraits/kessa/mad.png", "crop": Rect2(40, 125, 260, 110)},
}
## Real seconds (ignores time_scale, same as the other crit timers) — kept
## short on purpose per the user ("le temps qu'on voit le truc minimum"),
## just long enough to register before cutting back to normal play.
const CRIT_PORTRAIT_DURATION := 0.45

@export var map_data: BattleMapData

@onready var grid: BattleGrid = $BattleGrid
@onready var ui: BattleHUD = $BattleHUD
@onready var state_machine: BattleStateMachine = $BattleStateMachine
@onready var camera: Camera2D = $Camera2D
@onready var combat_stats: CombatStatsHUD = $CombatStatsHUD
@onready var heal_preview: HealPreviewPanel = $HealPreviewLayer/HealPreviewPanel
@onready var level_up_screen: LevelUpScreen = $LevelUpLayer/LevelUpScreen
@onready var exp_gain_overlay: ExpGainOverlay = $ExpGainLayer/ExpGainOverlay
@onready var _crit_flash: ColorRect = $CritFlashLayer/CritFlash
@onready var _crit_portrait_layer: CanvasLayer = $CritPortraitLayer
@onready var _crit_portrait_rect: TextureRect = $CritPortraitLayer/Portrait
@onready var _crit_portrait_sound: AudioStreamPlayer = $CritPortraitLayer/Sound

var player_units: Array[Unit] = []
var enemy_units: Array[Unit] = []
var selected_unit: Unit
## Where selected_unit stood before this turn's move, set once at selection
## time (UnitSelectState.handle_unit_clicked) — not touched again while it
## stays selected, so cancelling out of ActionMenuState can always restore
## it via undo_move regardless of how many times "move" is re-entered.
var selected_unit_start_pos: Vector2i
## Same idea as selected_unit_start_pos, for the equipped weapon: equipping
## is a free action (see EquipMenuState) with no separate "commit" step of
## its own, so without this, cancelling the whole turn attempt via
## ActionMenuState.handle_cancel would leave a weapon swap stuck even though
## everything else about the attempt got undone. Restored in undo_move
## alongside position.
var selected_unit_start_equipped_index: int = 0
## Which action ("attack"/"heal"/"support") WeaponPickerState is currently
## choosing a weapon for — set by start_targeting right before switching to
## "weapon_picker", read back by WeaponPickerState.enter/handle_weapon_selected.
## No return-state tracking needed the way EquipMenuState has one: this
## state is only ever reached after the unit's move is already committed
## (see start_targeting), so Cancel always goes back to "action_menu",
## same as TargetingState/HealState/SupportTargetingState's own Cancel.
var pending_weapon_picker_action: String = ""
var move_range: Dictionary = {}
var current_phase: int = UnitData.Team.PLAYER
var rng := RandomNumberGenerator.new()

var _hovered_unit: Unit = null
var _preview_target: Unit = null
var _heal_preview_target: Unit = null
var _combat_scene_active: bool = false

func _ready() -> void:
	rng.randomize()
	ui.attack_pressed.connect(func(): state_machine.handle_action_chosen("attack"))
	ui.heal_pressed.connect(func(): state_machine.handle_action_chosen("heal"))
	ui.support_pressed.connect(func(): state_machine.handle_action_chosen("support"))
	ui.equip_pressed.connect(func(): state_machine.handle_action_chosen("equip"))
	ui.weapon_selected.connect(func(i: int): state_machine.handle_weapon_selected(i))
	ui.wait_pressed.connect(func(): state_machine.handle_action_chosen("wait"))
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
		if _heal_preview_target:
			_clear_heal_preview()
		_update_targeting_hover()
		return

	if _preview_target:
		_clear_combat_preview()

	if state_machine.current_state_name == "heal_targeting":
		if _hovered_unit:
			ui.hide_hover_unit()
			_hovered_unit = null
		_update_heal_hover()
		return

	if _heal_preview_target:
		_clear_heal_preview()

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
		show_unit_range(occupant, get_move_range(occupant))

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
	# The attacker always strikes first chronologically, regardless of which
	# side (left/player or right/enemy) that ends up being — the HUD needs
	# this to lay its arrow rows out in the real attack/counter/double order.
	if attacker.unit_data.team == UnitData.Team.PLAYER:
		combat_stats.show_combat(
			attacker.unit_data, stats["attacker_dmg"], stats["attacker_hit"], stats["attacker_crit"], true,
			defender.unit_data, stats["defender_dmg"], stats["defender_hit"], stats["defender_crit"], stats["defender_can_counter"],
			show_ghost, attacker_hp, defender_hp,
			true, stats["attacker_hits"], stats["defender_hits"])
	else:
		combat_stats.show_combat(
			defender.unit_data, stats["defender_dmg"], stats["defender_hit"], stats["defender_crit"], stats["defender_can_counter"],
			attacker.unit_data, stats["attacker_dmg"], stats["attacker_hit"], stats["attacker_crit"], true,
			show_ghost, defender_hp, attacker_hp,
			false, stats["defender_hits"], stats["attacker_hits"])

func _clear_combat_preview() -> void:
	_preview_target = null
	combat_stats.hide_combat()

## Previews the heal panel (see HealPreviewPanel) when hovering a valid heal
## target during HealState — mirrors _update_targeting_hover, but there's no
## click-through combat scene to worry about landing mid-preview: the panel
## only ever shows current HP + the flat heal, nothing rolls.
func _update_heal_hover() -> void:
	var heal_state := state_machine.current_state as HealState
	if heal_state == null:
		return
	var local_pos: Vector2 = grid.to_local(get_global_mouse_position())
	var pos := grid.world_to_grid(local_pos)
	var occupant: Unit = grid.get_occupant(pos) if grid.is_in_bounds(pos) else null
	if occupant == _heal_preview_target:
		return
	_heal_preview_target = occupant
	if occupant and heal_state.valid_targets.has(occupant):
		var weapon := selected_unit.unit_data.get_equipped_weapon()
		heal_preview.show_preview(occupant.unit_data, weapon.heal_amount)
	else:
		_clear_heal_preview()

func _clear_heal_preview() -> void:
	_heal_preview_target = null
	heal_preview.hide_preview()

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

## Debuffs AND freeze tick at the END of EVERY phase (both sides), not just
## the affected unit's own — "2 turns" means 2 phase-ends total, counting
## from whichever phase-end the effect was applied during, even if that's
## the attacker's own phase and the target hasn't acted yet. E.g. unit A
## debuffs unit B during A's phase: A's phase ending is already "1 tour de
## malus" for B; B then plays its own phase, and THAT phase ending is "tour
## 2", removing it. Ticking only the ending side's own units would miss this
## first tick. Freeze (see UnitData.tick_freeze) follows the exact same
## timing convention, no reason for it to behave differently from a debuff.
func end_player_turn() -> void:
	_tick_all_status_effects()
	current_phase = UnitData.Team.ENEMY
	SignalBus.turn_ended.emit()
	state_machine.change_state("start_turn")

func end_enemy_turn() -> void:
	_tick_all_status_effects()
	current_phase = UnitData.Team.PLAYER
	SignalBus.turn_ended.emit()
	state_machine.change_state("start_turn")

func _tick_all_status_effects() -> void:
	for unit in player_units:
		unit.unit_data.tick_debuffs()
		unit.unit_data.tick_freeze()
	for unit in enemy_units:
		unit.unit_data.tick_debuffs()
		unit.unit_data.tick_freeze()

func get_attackable_targets(unit: Unit) -> Array[Unit]:
	return get_attackable_targets_from(unit.grid_pos, unit)

func get_attackable_targets_from(from_pos: Vector2i, unit: Unit) -> Array[Unit]:
	var weapon := unit.unit_data.get_equipped_weapon()
	# A support gauntlet is never a combat weapon (user's own words: "jamais
	# en attaque") — unlike Scythe (attacks AND debuffs) or a heal tome
	# (attacks OR heals), it ONLY does its Support effect. Attack just stays
	# permanently unavailable while one's equipped, same "always disabled,
	# never hidden" Attack already does for an out-of-range target.
	if weapon == null or not weapon.can_attack():
		return []
	var tiles := grid.get_tiles_in_range(from_pos, weapon.min_range, weapon.max_range)
	var opponents := enemy_units if unit.unit_data.team == UnitData.Team.PLAYER else player_units
	var result: Array[Unit] = []
	for tile in tiles:
		var occupant := grid.get_occupant(tile)
		if occupant and opponents.has(occupant):
			result.append(occupant)
	return result

## Whether `unit` could act on SOMEBODY right now for `action` using ANY of
## its class-usable, action-capable inventory weapons — not just whichever
## happens to be currently equipped. This is what the Attack/Heal/Support
## button's ENABLED state should mean now that choosing the action can open
## the weapon-picker first (see start_targeting): the real question isn't
## "can my current weapon reach someone", it's "is there SOME weapon in my
## inventory I could pick that would let me do this". Once a specific
## weapon is actually chosen/equipped, the corresponding targeting state
## still reads the real range off get_attackable_targets/get_healable_
## targets/get_support_targets as before — those stay equipped-weapon-only,
## unchanged, since the weapon is fixed by that point.
func has_action_target(unit: Unit, action: String) -> bool:
	var unit_data := unit.unit_data
	var opponents := enemy_units if unit_data.team == UnitData.Team.PLAYER else player_units
	var allies := player_units if unit_data.team == UnitData.Team.PLAYER else enemy_units
	var target_pool := allies if action == "heal" else opponents
	for weapon in unit_data.inventory:
		if not unit_data.can_use_weapon(weapon.weapon_type):
			continue
		if not weapon.matches_action(action):
			continue
		var tiles := grid.get_tiles_in_range(unit.grid_pos, weapon.min_range, weapon.max_range)
		for tile in tiles:
			var occupant := grid.get_occupant(tile)
			if occupant == null or not target_pool.has(occupant):
				continue
			if action == "heal" and occupant.unit_data.get_current_hp() >= occupant.unit_data.get_max_hp():
				continue
			return true
	return false

func has_attackable_target(unit: Unit) -> bool:
	return has_action_target(unit, "attack")

## Whether `unit` owns ANY class-usable heal-capable weapon (see
## WeaponData.can_heal) — not just whichever's currently equipped, now that
## choosing Heal can open the weapon-picker to any of them (see
## start_targeting). Decides whether the Heal button shows up on the menu
## at all, independent of whether a valid target's actually in range right
## now (see has_healable_target above, now has_action_target-backed too).
func weapon_can_heal(unit: Unit) -> bool:
	return count_action_weapons(unit, "heal") > 0

## Tiles `unit` can reach this turn — normally BattleGrid.compute_move_range,
## but a frozen unit (see UnitData.is_frozen) can't reach anywhere but its
## own tile, per the user's call that Freeze blocks movement only, not
## acting. Single chokepoint so MoveState, the hover-range preview, and
## EnemyAI all agree on what a unit can actually do this turn.
func get_move_range(unit: Unit) -> Dictionary:
	if unit.unit_data.is_frozen():
		return {unit.grid_pos: 0}
	return grid.compute_move_range(unit.grid_pos, unit.unit_data.get_mov(), unit.unit_data.team, unit.unit_data.get_movement_type())

## Whether the unit has anything at all to show in the Equip menu — hidden
## only for the edge case of a completely empty inventory. Shown even with
## just one weapon (user's explicit call: still useful to check its stats,
## and a button that's always there beats one that appears/disappears
## depending on inventory size).
func can_switch_weapon(unit: Unit) -> bool:
	return unit.unit_data.inventory.size() > 0

## How many of `unit`'s inventory weapons are both class-usable AND fit
## `action` (see WeaponData.matches_action) — used by start_targeting below
## to tell "no real choice" (0 or 1 match) from "a genuine choice exists"
## (2+), since a weapon the class can't even use isn't a real option.
func count_action_weapons(unit: Unit, action: String) -> int:
	var unit_data := unit.unit_data
	var count := 0
	for weapon in unit_data.inventory:
		if not unit_data.can_use_weapon(weapon.weapon_type):
			continue
		if weapon.matches_action(action):
			count += 1
	return count

## Classic Fire Emblem "choose weapon, then choose target" flow: if `unit`
## actually has more than one usable weapon for `action` ("attack"/"heal"/
## "support"), open the weapon-picker first (see WeaponPickerState) instead
## of jumping straight to targeting with whatever happens to be equipped —
## picking a weapon there re-equips it AND proceeds into the right
## targeting state, replacing the old "open Equip, switch, back out, click
## the action again" round-trip. Skipped when there's 0 or 1 real option,
## same reasoning MoveState's pre-move Attack/Heal/Support shortcuts
## already use: don't cost an extra click for a choice that isn't one.
func start_targeting(unit: Unit, action: String) -> void:
	var eligible := count_action_weapons(unit, action)
	if eligible > 1:
		pending_weapon_picker_action = action
		state_machine.change_state("weapon_picker")
		return
	if eligible == 1:
		# The one real option still needs to actually BE equipped — skipping
		# the picker only saves a click if it does. Real bug caught live:
		# Martin (fire_tome equipped, heal_tome the only heal-capable
		# weapon) clicking Soigner used to jump straight to heal_targeting
		# with fire_tome still equipped (can't heal — heal_amount 0), so
		# nothing was ever a valid target and Soigner silently did nothing.
		_equip_sole_action_weapon(unit, action)
	match action:
		"attack":
			state_machine.change_state("targeting")
		"heal":
			state_machine.change_state("heal_targeting")
		"support":
			state_machine.change_state("support_targeting")

## Equips the single weapon that fits `action` (see count_action_weapons)
## when it isn't already equipped — see start_targeting. No-op if the
## currently equipped weapon already fits (the common case: a unit with
## only one attack-capable weapon, which is almost always the one already
## equipped), so this doesn't spam SignalBus.unit_selected on every attack.
func _equip_sole_action_weapon(unit: Unit, action: String) -> void:
	var unit_data := unit.unit_data
	var current := unit_data.get_equipped_weapon()
	if current != null and current.matches_action(action):
		return
	for i in unit_data.inventory.size():
		var weapon := unit_data.inventory[i]
		if not unit_data.can_use_weapon(weapon.weapon_type):
			continue
		if weapon.matches_action(action):
			unit_data.equipped_index = i
			SignalBus.unit_selected.emit(unit)
			return

## Allies (self included — targeting yourself is a valid choice) within the
## healer's equipped weapon's range who aren't already at full HP. Empty if
## the weapon can't heal at all.
func get_healable_targets(unit: Unit) -> Array[Unit]:
	var weapon := unit.unit_data.get_equipped_weapon()
	if weapon == null or not weapon.can_heal():
		return []
	var tiles := grid.get_tiles_in_range(unit.grid_pos, weapon.min_range, weapon.max_range)
	var allies := player_units if unit.unit_data.team == UnitData.Team.PLAYER else enemy_units
	var result: Array[Unit] = []
	for tile in tiles:
		var occupant := grid.get_occupant(tile)
		if occupant and allies.has(occupant) and occupant.unit_data.get_current_hp() < occupant.unit_data.get_max_hp():
			result.append(occupant)
	return result

func has_healable_target(unit: Unit) -> bool:
	return has_action_target(unit, "heal")

## Resolves a heal: plays the healer's cast animation (a no-op for a rig
## that doesn't have one, e.g. anyone but Martin — see
## Unit.play_heal_animation), then restores `healer`'s equipped weapon's
## heal_amount to `target`'s current HP (clamped at max) and consumes the
## healer's turn. No combat-scene camera staging (unlike execute_attack) —
## just the animation plus a floating "+N" over the target, reusing
## _show_strike_message's existing convention. `target` can be `healer`
## itself (self-heal is allowed — see get_healable_targets).
func execute_heal(healer: Unit, target: Unit) -> void:
	var weapon := healer.unit_data.get_equipped_weapon()
	var amount: int = weapon.heal_amount if weapon else 0
	await healer.play_heal_animation()
	var new_hp: int = mini(target.unit_data.get_max_hp(), target.unit_data.get_current_hp() + amount)
	target.unit_data.set_current_hp(new_hp)
	_play_heal_effect(target)
	_show_strike_message(target, "+%d" % amount, Color(0.4, 1.0, 0.4))
	await _grant_action_exp(healer)
	healer.has_acted = true

## Spawns the green sparkle burst (see HealEffect) on `target` the instant
## the heal actually lands — mirrors _play_impact_effect's placement
## (get_impact_point, not raw global_position, so it reads centered on the
## body rather than at the feet).
func _play_heal_effect(target: Unit) -> void:
	if not is_instance_valid(target):
		return
	var effect: HealEffect = HEAL_EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.global_position = target.get_impact_point()
	effect.play()

## Whether `unit` owns ANY class-usable support gauntlet (see
## WeaponData.can_support) — not just whichever's currently equipped, same
## reasoning as weapon_can_heal above. Decides whether the Support button
## shows up on the menu at all.
func weapon_can_support(unit: Unit) -> bool:
	return count_action_weapons(unit, "support") > 0

## Enemies (never allies — support gauntlets only ever target the opposing
## side, unlike Heal's allies-only pool) within the user's equipped weapon's
## range. No HP or other filter — unlike get_healable_targets, any enemy in
## range is a valid target regardless of what Freeze/Knockback would
## actually do to them.
func get_support_targets(unit: Unit) -> Array[Unit]:
	var weapon := unit.unit_data.get_equipped_weapon()
	if weapon == null or not weapon.can_support():
		return []
	var tiles := grid.get_tiles_in_range(unit.grid_pos, weapon.min_range, weapon.max_range)
	var opponents := enemy_units if unit.unit_data.team == UnitData.Team.PLAYER else player_units
	var result: Array[Unit] = []
	for tile in tiles:
		var occupant := grid.get_occupant(tile)
		if occupant and opponents.has(occupant):
			result.append(occupant)
	return result

func has_support_target(unit: Unit) -> bool:
	return has_action_target(unit, "support")

## Resolves a support gauntlet use: applies whichever effect the equipped
## weapon has (see WeaponData.gauntlet_effect) to `target` and consumes
## `user`'s turn. Like Heal, never rolls to hit — a support gauntlet always
## lands.
func execute_support(user: Unit, target: Unit) -> void:
	var weapon := user.unit_data.get_equipped_weapon()
	# Fired at target's position BEFORE the effect resolves — reads as "the
	# gauntlet connects here" the same instant as everything else, whether
	# that's Freeze (target doesn't move) or Knockback (about to slide away
	# from this exact spot). Fire-and-forget, same as _play_heal_effect.
	_play_support_effect(target, weapon.gauntlet_effect)
	match weapon.gauntlet_effect:
		WeaponData.GauntletEffect.FREEZE:
			target.unit_data.apply_freeze(weapon.freeze_duration)
			_show_strike_message(target, "Gelé (%dt)" % weapon.freeze_duration, Color(0.55, 0.85, 1.0))
		WeaponData.GauntletEffect.KNOCKBACK:
			await _apply_knockback(user, target, weapon.knockback_distance)
	await _grant_action_exp(user)
	user.has_acted = true

## Spawns the gauntlet-support burst (see SupportEffect) on `target` —
## mirrors _play_heal_effect's placement (get_impact_point, not raw
## global_position, so it reads centered on the body rather than the feet).
func _play_support_effect(target: Unit, effect: WeaponData.GauntletEffect) -> void:
	if not is_instance_valid(target):
		return
	var effect_node: SupportEffect = SUPPORT_EFFECT_SCENE.instantiate()
	add_child(effect_node)
	effect_node.global_position = target.get_impact_point()
	effect_node.play(effect)

## Pushes `target` up to `distance` tiles directly away from `user`, along
## whichever grid axis (horizontal/vertical) the offset between them leans
## more on — targets are rarely on a perfectly cardinal line (weapon range
## is Manhattan distance, so a diagonal-ish offset is possible), and this
## is the simplest rule that always yields a real push direction. Stops
## early at the last free tile (BattleGrid.is_free) if a wall, another
## unit, or the map edge blocks the rest of the distance — per the user's
## call, partial knockback beats an all-or-nothing push. A fully boxed-in
## target just doesn't move at all; still a valid (if uneventful) use.
func _apply_knockback(user: Unit, target: Unit, distance: int) -> void:
	var delta := target.grid_pos - user.grid_pos
	var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	if dir == Vector2i.ZERO:
		return
	var path: Array[Vector2i] = []
	var pos := target.grid_pos
	for i in distance:
		var next: Vector2i = pos + dir
		if not grid.is_free(next):
			break
		path.append(next)
		pos = next
	if path.is_empty():
		return
	grid.clear_occupant(target.grid_pos)
	await target.move_along_path(path, grid)
	grid.set_occupant(target.grid_pos, target)

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
	revert_equipped_weapon(unit)

## Restores unit_data.equipped_index to whatever it was at selection time —
## equipping is a free action with no commit step of its own (see
## EquipMenuState), so cancelling the whole turn attempt needs to undo it
## explicitly, same as position. Called from undo_move (ActionMenuState's
## cancel path) AND directly from MoveState.handle_cancel (which has no
## position to undo — nothing's moved yet at that point — but a pre-move
## equip swap still needs reverting on a full cancel).
func revert_equipped_weapon(unit: Unit) -> void:
	if unit.unit_data.equipped_index != selected_unit_start_equipped_index:
		unit.unit_data.equipped_index = selected_unit_start_equipped_index
		SignalBus.unit_selected.emit(unit)

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
	await _award_combat_exp(attacker, defender, result["log"])
	apply_combat_aftermath(attacker, defender)
	if is_instance_valid(attacker):
		attacker.has_acted = true

## Awards XP to whichever of `attacker`/`defender` are PLAYER-team units
## that actually swung (appear as a `source` entry in `log`) and are still
## alive — a unit that died in this exchange doesn't get XP for its own
## last swing, same as real Fire Emblem never shows a level-up for a unit
## about to be removed. Called BEFORE apply_combat_aftermath's death/
## removal on purpose: HP and death are already final by this point
## (CombatResolver.resolve_combat applies every strike synchronously), this
## is purely about showing the level-up reveal before the corpse
## disappears from player_units/enemy_units, not about ordering HP itself.
func _award_combat_exp(attacker: Unit, defender: Unit, log: Array) -> void:
	for unit in [attacker, defender]:
		if not is_instance_valid(unit) or unit.unit_data.team != UnitData.Team.PLAYER or not unit.unit_data.is_alive():
			continue
		var opponent := defender if unit == attacker else attacker
		var swung := false
		var killed_opponent := false
		for entry in log:
			if entry["source"] != unit.unit_data:
				continue
			swung = true
			if entry["target"] == opponent.unit_data and not opponent.unit_data.is_alive():
				killed_opponent = true
		if not swung:
			continue
		var amount := clampi(UnitData.EXP_BASE + (opponent.unit_data.level - unit.unit_data.level) * UnitData.EXP_LEVEL_DIFF_MULT, UnitData.EXP_MIN, UnitData.EXP_MAX)
		if killed_opponent:
			amount += UnitData.EXP_KILL_BONUS
		await _grant_exp_and_show_level_ups(unit, amount)

## Flat EXP_BASE for a PLAYER-team unit successfully using Heal/Support —
## no opponent-level reference point for a non-damage action, unlike
## _award_combat_exp's per-attack formula. No-op for an enemy (or ally-team)
## unit.
func _grant_action_exp(unit: Unit) -> void:
	if unit.unit_data.team != UnitData.Team.PLAYER:
		return
	await _grant_exp_and_show_level_ups(unit, UnitData.EXP_BASE)

## Applies the XP, playing the fill animation on the big centered
## ExpGainOverlay (2026-09-10: moved off UnitInfoPanel's small corner bar —
## user preferred the animating bar be center-screen; the corner bar is
## still there as a static reference, just doesn't animate itself anymore)
## and awaiting the level-up screen once per level actually gained (see
## UnitData.gain_exp). No-op for a character_class != null unit — regular
## enemies never level up mid-battle, gain_exp already returns empty for
## them, so there's nothing to animate. A multi-level grant plays as
## several fill-to-100 segments, snapping back to 0 between each (real Fire
## Emblem doesn't animate the bar draining backward on a level-up, it just
## resets) with the overlay hidden right before each LevelUpScreen reveal,
## then one final fill for whatever's left over after the last level.
## Re-emits SignalBus.unit_selected once done if any level was gained, so
## UnitInfoPanel's stats/level number/corner EXP bar all catch up too —
## same "mutated unit_data, re-emit to refresh" convention EquipMenuState
## already established for weapon switches.
func _grant_exp_and_show_level_ups(unit: Unit, amount: int) -> void:
	var unit_data := unit.unit_data
	if unit_data.character_class != null:
		return
	var starting_exp := unit_data.exp
	var level_ups := unit_data.gain_exp(amount)
	if level_ups.is_empty():
		await exp_gain_overlay.animate_fill(unit_data, starting_exp, unit_data.exp)
		exp_gain_overlay.hide_overlay()
		return
	var segment_start := starting_exp
	for entry in level_ups:
		await exp_gain_overlay.animate_fill(unit_data, segment_start, 100)
		exp_gain_overlay.set_immediate(0)
		segment_start = 0
		exp_gain_overlay.hide_overlay()
		await level_up_screen.show_level_up(unit_data, entry)
	if unit_data.exp > 0:
		await exp_gain_overlay.animate_fill(unit_data, 0, unit_data.exp)
	exp_gain_overlay.hide_overlay()
	SignalBus.unit_selected.emit(unit)

## Dmg/Hit/Crit each combatant would deal against the other at their
## current positions — used both for the real combat scene and for the
## hover preview in TargetingState (see _update_targeting_hover), so both
## show exactly the same numbers.
## "*_dmg" is the TOTAL across every hit that combatant will land this
## engagement (single hit, or doubled per CombatResolver.can_double) — not
## the per-swing might. "*_hits" (1, or 2 if doubling; 0 for a defender that
## can't counter at all) is kept alongside so the HUD's arrow sequence can
## recover the per-swing number and lay out the real strike order.
func _compute_combat_stats(attacker: Unit, defender: Unit) -> Dictionary:
	var distance := absi(attacker.grid_pos.x - defender.grid_pos.x) + absi(attacker.grid_pos.y - defender.grid_pos.y)
	var attacker_terrain := grid.get_terrain_combat_bonus(attacker.grid_pos)
	var defender_terrain := grid.get_terrain_combat_bonus(defender.grid_pos)
	var defender_can_counter := CombatResolver.is_in_weapon_range(distance, defender.unit_data.get_combat_weapon())
	var attacker_hits := 2 if CombatResolver.can_double(attacker.unit_data, defender.unit_data) else 1
	var defender_hits := 0
	if defender_can_counter:
		defender_hits = 2 if CombatResolver.can_double(defender.unit_data, attacker.unit_data) else 1
	var attacker_swing := CombatResolver.get_damage(attacker.unit_data, defender.unit_data, defender_terrain["def"])
	var defender_swing := CombatResolver.get_damage(defender.unit_data, attacker.unit_data, attacker_terrain["def"]) if defender_can_counter else 0
	return {
		"attacker_hit": CombatResolver.get_hit_chance(attacker.unit_data, defender.unit_data, defender_terrain["avoid"]),
		"attacker_dmg": attacker_swing * attacker_hits,
		"attacker_hits": attacker_hits,
		"attacker_crit": CombatResolver.get_crit_chance(attacker.unit_data, defender.unit_data),
		"defender_hit": CombatResolver.get_hit_chance(defender.unit_data, attacker.unit_data, attacker_terrain["avoid"]) if defender_can_counter else 0,
		"defender_dmg": defender_swing * defender_hits,
		"defender_hits": defender_hits,
		"defender_crit": CombatResolver.get_crit_chance(defender.unit_data, attacker.unit_data) if defender_can_counter else 0,
		"defender_can_counter": defender_can_counter,
	}

## Bow/tome users don't close the distance for a clash the way melee weapons
## do — used both to skip the initial stage-approach step and each strike's
## forward lunge for whichever side is equipped this way.
func _is_ranged(unit: Unit) -> bool:
	# get_combat_weapon (not get_equipped_weapon) — a unit countering with a
	# support gauntlet equipped should stage/lunge based on the REAL weapon
	# it's fighting with, not the gauntlet it happens to be holding.
	var weapon := unit.unit_data.get_combat_weapon()
	return weapon != null and weapon.weapon_type in [WeaponData.WeaponType.BOW, WeaponData.WeaponType.TOME]

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

	# Ranged units (bow/tome) stand their ground for the clash — closing the
	# gap only makes sense for melee weapons. Ilsa-with-a-tome vs. a swordsman
	# still has the swordsman step in; the tome user never does.
	var attacker_ranged := _is_ranged(attacker)
	var defender_ranged := _is_ranged(defender)

	var stage_tween := create_tween().set_parallel(true)
	stage_tween.tween_property(camera, "position", (attacker_start + defender_start) / 2.0, STAGE_TWEEN_DURATION)
	stage_tween.tween_property(camera, "zoom", COMBAT_SCENE_ZOOM, STAGE_TWEEN_DURATION)
	if not attacker_ranged:
		stage_tween.tween_property(attacker, "position", attacker_start + approach * APPROACH_FRACTION, STAGE_TWEEN_DURATION)
	if not defender_ranged:
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
		var target: Unit = attacker if strike["target"] == attacker.unit_data else defender
		if not is_instance_valid(source):
			continue
		await get_tree().create_timer(PRE_STRIKE_DELAY).timeout
		# get_combat_weapon — see CombatResolver's own doc comment; the hit
		# VFX/SFX picked from this must match whatever weapon the strike was
		# actually resolved with, which may be a counter-attacker's real
		# weapon rather than a support gauntlet they still have equipped.
		var source_weapon := source.unit_data.get_combat_weapon()
		if _is_ranged(source):
			# No forward lunge for a ranged strike — casting/shooting in
			# place, the projectile (spawned by the rig itself, synced to a
			# frame in its own attack animation) is what covers the distance
			# AND plays the impact sound/particles on arrival — doing it here
			# too would double up and land before the projectile even gets
			# there.
			await source.play_attack_animation(target.get_impact_point(), strike["hit"], source_weapon, strike["crit"])
		else:
			var bump_dir := approach.normalized() if source == attacker else -approach.normalized()
			var bump_start := source.position
			# Lunge forward and HOLD there for the whole swing (rather than
			# bouncing back on its own fixed timer) so a rigged unit's ~1s
			# animation doesn't finish standing back at rest — the two used to
			# run on unrelated clocks and looked disconnected.
			var lunge_out := create_tween()
			lunge_out.tween_property(source, "position", bump_start + bump_dir * BUMP_DISTANCE, 0.1)
			await lunge_out.finished
			# Play the impact/miss VFX/SFX right when the blade actually lands
			# (source.attack_contact, forwarded from the rig's own
			# ATTACK_CONTACT_FRAME_INDEX — see AuroraBattleSprite), not after
			# the whole swing including recovery/follow-through has finished
			# playing, which read as noticeably late — a miss gets the exact
			# same treatment as a landed hit here (a whoosh instead of an
			# impact burst), not delayed to the floating-text stage. A
			# plain-sprite source (every current enemy — no
			# rigged_battle_sprite yet, so play_attack_animation is a no-op
			# and attack_contact would never fire) instead gets it right
			# here, at the bump's forward peak — the only "contact" moment a
			# non-rigged unit actually has.
			var did_hit: bool = strike["hit"]
			var did_crit: bool = strike["crit"]
			var contact_target := target
			var contact_weapon := source_weapon
			var contact_source_pos := source.get_impact_point()
			if source.supports_attack_contact():
				var on_contact := func() -> void:
					if did_hit:
						if did_crit:
							await _play_crit_portrait(source)
						_play_impact_effect(contact_target, contact_weapon, did_crit)
						if did_crit:
							_play_crit_hitstop()
					else:
						_play_miss_sound(contact_source_pos)
				source.attack_contact.connect(on_contact, CONNECT_ONE_SHOT)
				await source.play_attack_animation(target.get_impact_point(), strike["hit"], source_weapon)
				if source.attack_contact.is_connected(on_contact):
					source.attack_contact.disconnect(on_contact)
			else:
				if did_hit:
					if did_crit:
						await _play_crit_portrait(source)
					_play_impact_effect(contact_target, contact_weapon, did_crit)
					if did_crit:
						_play_crit_hitstop()
				else:
					_play_miss_sound(contact_source_pos)
				await source.play_attack_animation(target.get_impact_point(), strike["hit"], source_weapon)
			var lunge_back := create_tween()
			lunge_back.tween_property(source, "position", bump_start, 0.15)
			await lunge_back.finished
		combat_stats.update_hp(strike["target"], strike["target_hp_after"])

		if not strike["hit"]:
			_show_strike_message(target, "Rate !", Color.WHITE)
		elif strike["crit"]:
			_show_strike_message(target, "Critique ! -%d" % strike["damage"], Color(1.0, 0.85, 0.2))
		else:
			_show_strike_message(target, "-%d" % strike["damage"], Color(1.0, 0.4, 0.4))
		var debuff_weapon: WeaponData = strike["debuff_weapon"]
		if debuff_weapon:
			var stat_label := WeaponData.DEBUFF_STAT_LABELS[debuff_weapon.debuff_stat]
			# Below the damage/crit/miss message (a less negative y_offset —
			# closer to the target — reads as "underneath" it) and smaller, per
			# the user's call: the debuff is a secondary detail, not as
			# important as the damage number it accompanies.
			_show_strike_message(target, "%s -%d" % [stat_label, debuff_weapon.debuff_amount], Color(0.75, 0.55, 1.0), -40.0, 16)

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

## Spawns a one-shot hit-spark/sound burst at `target`'s position, weapon-typed
## via `weapon` (metal clang, wood thock, or a magic chime — see
## ImpactEffect.play) unless `is_crit` is true, which overrides that entirely
## with the weapon-agnostic red crit burst/sound. Only ever called for a
## strike that actually connected; a ranged source's own impact instead
## comes from Projectile on arrival — see the `_is_ranged` branch in
## _play_combat_scene.
func _play_impact_effect(target: Unit, weapon: WeaponData, is_crit: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var effect: ImpactEffect = IMPACT_EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.global_position = target.get_impact_point()
	effect.play(weapon, is_crit)

## Plays SOUND_MISS at `position` — no particle burst (nothing landed to
## show a burst at), and no weapon-type branching (unlike _play_impact_effect,
## a miss sounds the same regardless of weapon). A throwaway node rather
## than a scene like ImpactEffect since there's nothing else to it.
func _play_miss_sound(position: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.global_position = position
	player.stream = SOUND_MISS
	player.play()
	player.finished.connect(player.queue_free)

## Shows a tight eye/brow crop of the attacker's "mad" VN portrait in a
## horizontal letterbox band for CRIT_PORTRAIT_DURATION real seconds, then
## hides it again — AWAITED by callers (unlike _play_crit_hitstop below),
## since this is meant to happen BEFORE the impact effect/hit-stop, not
## alongside them: crit lands → cut to portrait (brief) → cut back → THEN
## the normal burst/flash/hit-stop plays as the payoff. No-op if `source`'s
## character isn't in CRIT_PORTRAIT_DATA (every current enemy) — falls back
## to just the flash+hit-stop, same as a normal named-companion crit minus
## the cut-in.
func _play_crit_portrait(source: Unit) -> void:
	var data: Dictionary = CRIT_PORTRAIT_DATA.get(source.unit_data.character_id, {})
	if data.is_empty():
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load(data["path"])
	atlas.region = data["crop"]
	_crit_portrait_rect.texture = atlas
	_crit_portrait_layer.visible = true
	_crit_portrait_sound.stream = SOUND_CRIT_PORTRAIT
	_crit_portrait_sound.play()
	await get_tree().create_timer(CRIT_PORTRAIT_DURATION, false, false, true).timeout
	_crit_portrait_layer.visible = false

## Fire-and-forget: dips Engine.time_scale (a global multiplier on every
## _process/_physics_process delta project-wide — deliberately NOT the pause
## system, so combat's own tweens/timers slow down along with everything
## else instead of freezing solid) and flashes CritFlash gray, both timed to
## a real-time HITSTOP_DURATION. Not awaited by callers on purpose: the
## caller (already inside a slowed time_scale once this runs) just keeps
## going, which is what makes the REST of the strike's presentation (the
## lunge-back tween, the next strike's PRE_STRIKE_DELAY) read as part of the
## same slow-motion beat instead of a separate, blocking pause.
##
## Audio is unaffected by Engine.time_scale in Godot (the mixer runs on its
## own real-time thread, not the scaled per-frame delta) — SOUND_CRIT plays
## at normal pitch/speed through the dip with no special handling needed.
##
## Melee-only for now — see Battle.gd's did_crit branches. Projectile.gd
## (ranged/Martin) does its own separate, simpler time_scale-only dip on a
## ranged crit (no screen flash there yet, since Projectile has no easy
## reference back to this node — not worth a shared singleton for a first
## pass). Revisit if ranged crits need the same flash.
func _play_crit_hitstop() -> void:
	Engine.time_scale = HITSTOP_TIME_SCALE
	_crit_flash.color.a = 0.0
	var flash_tween := create_tween()
	# Ignores time_scale so its timing stays predictable in real seconds
	# regardless of the slowdown window above — without this, the tween's
	# own delta shrinks along with everything else, badly tangling how long
	# the flash actually takes to visually finish with how long the
	# slowdown lasts (confirmed: this is why the first version read as
	# "too short" — the fade-in alone needed longer than HITSTOP_DURATION
	# to complete at the slowed rate, so time_scale reset mid-fade).
	flash_tween.set_ignore_time_scale(true)
	flash_tween.tween_property(_crit_flash, "color:a", CRIT_FLASH_PEAK_ALPHA, CRIT_FLASH_IN_DURATION)
	flash_tween.tween_property(_crit_flash, "color:a", 0.0, CRIT_FLASH_OUT_DURATION)
	await get_tree().create_timer(HITSTOP_DURATION, false, false, true).timeout
	Engine.time_scale = 1.0

## Brief floating text over `target`: "Rate !" on a miss, "-N" on an
## ordinary hit, "Critique ! -N" on a crit — so damage and the two special
## cases are all readable at a glance instead of only inferable from how
## much the HP bar moved.
const STRIKE_MESSAGE_WIDTH := 220.0

## `y_offset` lets a second, simultaneous message (the debuff notice — see
## the strike loop) start lower than the default -70 (i.e. closer to the
## target, reading as "below" the damage number) so it doesn't render
## directly on top of it; `font_size` lets that same message read as a
## smaller, secondary notice rather than as important as the damage itself.
func _show_strike_message(target: Unit, text: String, color: Color, y_offset: float = -70.0, font_size: int = 24) -> void:
	if not is_instance_valid(target):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
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
	label.position = target.position + Vector2(-STRIKE_MESSAGE_WIDTH / 2.0, y_offset)
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
