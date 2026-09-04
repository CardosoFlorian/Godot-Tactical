class_name TargetingState
extends BattleState
## Highlights valid attack targets for the selected unit and resolves
## combat when one is clicked.

var valid_targets: Array[Unit] = []

func enter(_previous_state_name: String = "") -> void:
	valid_targets = battle.get_attackable_targets(battle.selected_unit)
	var tiles: Array[Vector2i] = []
	for target in valid_targets:
		tiles.append(target.grid_pos)
	battle.grid.clear_highlight()
	battle.grid.show_highlight(tiles, battle.grid.HIGHLIGHT_ATTACK)
	SignalBus.targeting_started.emit("attack", valid_targets)

func exit() -> void:
	battle.grid.clear_highlight()

func handle_unit_clicked(unit: Unit) -> void:
	if not valid_targets.has(unit):
		return
	var attacker := battle.selected_unit
	SignalBus.target_selected.emit(unit)
	SignalBus.combat_started.emit(attacker, unit)
	var distance := absi(attacker.grid_pos.x - unit.grid_pos.x) + absi(attacker.grid_pos.y - unit.grid_pos.y)
	var attacker_terrain := battle.grid.get_terrain_combat_bonus(attacker.grid_pos)
	var defender_terrain := battle.grid.get_terrain_combat_bonus(unit.grid_pos)
	var result := CombatResolver.resolve_combat(attacker.unit_data, unit.unit_data, distance, battle.rng, attacker_terrain, defender_terrain)
	SignalBus.combat_resolved.emit(result)
	battle.apply_combat_aftermath(attacker, unit)
	if is_instance_valid(attacker):
		attacker.has_acted = true
	if battle.check_battle_end():
		state_machine.change_state("game_over")
	else:
		state_machine.change_state("unit_select")

func handle_cancel() -> void:
	state_machine.change_state("action_menu")
