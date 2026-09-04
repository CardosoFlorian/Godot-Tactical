extends Node
## Autoload orchestrating the campaign sequence: dialogue -> battle ->
## dialogue -> battle -> dialogue, per the brief. An autoload (rather than a
## node living under Main) so it survives the scene changes it triggers.
## Talks to Battle only through SignalBus + the node it just instantiated,
## and to Dialogic only through its public Dialogic.start() API.

const BATTLE_SCENE := preload("res://scenes/battle/Battle.tscn")
const CHAPTER_2_MAP := preload("res://data/maps/chapter2.tres")
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

const ROSTER_UNIT_PATHS := [
	"res://data/units/aria.tres",
	"res://data/units/doran.tres",
	"res://data/units/kessa.tres",
	"res://data/units/elyn.tres",
]

var _current_battle: Battle
var _steps: Array[Dictionary] = []
var _step_index := -1

func _ready() -> void:
	DialogueCharacters.register_all()

func start_campaign() -> void:
	GameState.player_roster.clear()
	for path in ROSTER_UNIT_PATHS:
		var template: UnitData = load(path)
		GameState.add_unit(template.duplicate())

	_steps = [
		{"type": "dialogue", "timeline": "res://dialogue/timelines/intro.dtl"},
		{"type": "battle", "map": null},
		{"type": "dialogue", "timeline": "res://dialogue/timelines/interlude.dtl"},
		{"type": "battle", "map": CHAPTER_2_MAP},
		{"type": "dialogue", "timeline": "res://dialogue/timelines/victory.dtl"},
		{"type": "end"},
	]
	_step_index = -1

	var current := get_tree().current_scene
	if current:
		current.queue_free()

	_advance()

func _advance() -> void:
	_step_index += 1
	if _step_index >= _steps.size():
		return
	var step: Dictionary = _steps[_step_index]
	match step["type"]:
		"dialogue":
			_play_dialogue(step["timeline"])
		"battle":
			_start_battle(step.get("map"))
		"end":
			_return_to_main()

func _play_dialogue(timeline_path: String) -> void:
	SignalBus.dialogue_requested.emit(timeline_path)
	if not Dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		Dialogic.timeline_ended.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	Dialogic.start(timeline_path)

func _on_dialogue_finished() -> void:
	SignalBus.dialogue_finished.emit(_steps[_step_index]["timeline"])
	_advance()

func _start_battle(map_override: BattleMapData) -> void:
	GameState.reset_for_new_battle()
	_current_battle = BATTLE_SCENE.instantiate()
	if map_override:
		_current_battle.map_data = map_override
	SignalBus.battle_won.connect(_on_battle_won, CONNECT_ONE_SHOT)
	SignalBus.battle_lost.connect(_on_battle_lost, CONNECT_ONE_SHOT)
	add_child(_current_battle)

func _on_battle_won() -> void:
	if SignalBus.battle_lost.is_connected(_on_battle_lost):
		SignalBus.battle_lost.disconnect(_on_battle_lost)
	_current_battle.queue_free()
	_current_battle = null
	_advance()

func _on_battle_lost() -> void:
	if SignalBus.battle_won.is_connected(_on_battle_won):
		SignalBus.battle_won.disconnect(_on_battle_won)
	_current_battle.queue_free()
	_current_battle = null
	_return_to_main()

func _return_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
