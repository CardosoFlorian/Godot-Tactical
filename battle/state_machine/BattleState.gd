class_name BattleState
extends RefCounted
## Base class for BattleStateMachine states. Concrete states live in
## battle/state_machine/states/ and override the handle_* hooks they care
## about; the rest are no-ops by default.

var battle: Battle
var state_machine: BattleStateMachine

func _init(p_battle: Battle, p_state_machine: BattleStateMachine) -> void:
	battle = p_battle
	state_machine = p_state_machine

func enter(_previous_state_name: String = "") -> void:
	pass

func exit() -> void:
	pass

func handle_unit_clicked(_unit: Unit) -> void:
	pass

func handle_tile_clicked(_pos: Vector2i) -> void:
	pass

func handle_action_chosen(_action_name: String) -> void:
	pass

func handle_cancel() -> void:
	pass
