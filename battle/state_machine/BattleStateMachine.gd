class_name BattleStateMachine
extends Node
## Drives the battle turn flow. Owns one BattleState instance per named
## state and forwards player input events to whichever is current. States
## communicate results via SignalBus so the UI/grid don't need direct
## references to the state machine.

var battle: Battle
var current_state: BattleState
var current_state_name: String = ""
var _states: Dictionary = {}

func setup(p_battle: Battle) -> void:
	battle = p_battle
	_states = {
		"start_turn": StartTurnState.new(battle, self),
		"unit_select": UnitSelectState.new(battle, self),
		"move": MoveState.new(battle, self),
		"action_menu": ActionMenuState.new(battle, self),
		"targeting": TargetingState.new(battle, self),
		"enemy_phase": EnemyPhaseState.new(battle, self),
		"game_over": BattleState.new(battle, self),
	}

func start(initial_state: String = "start_turn") -> void:
	change_state(initial_state)

func change_state(name: String) -> void:
	if not _states.has(name):
		push_error("BattleStateMachine: unknown state '%s'" % name)
		return
	var previous_name := current_state_name
	if current_state:
		current_state.exit()
	current_state = _states[name]
	current_state_name = name
	current_state.enter(previous_name)

func handle_unit_clicked(unit: Unit) -> void:
	if current_state:
		current_state.handle_unit_clicked(unit)

func handle_tile_clicked(pos: Vector2i) -> void:
	if current_state:
		current_state.handle_tile_clicked(pos)

func handle_action_chosen(action_name: String) -> void:
	if current_state:
		current_state.handle_action_chosen(action_name)

func handle_cancel() -> void:
	if current_state:
		current_state.handle_cancel()
