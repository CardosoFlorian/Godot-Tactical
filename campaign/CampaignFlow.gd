extends Node
## Autoload orchestrating the campaign sequence: dialogue -> battle ->
## dialogue -> battle -> dialogue, per the brief. An autoload (rather than a
## node living under Main) so it survives the scene changes it triggers.
## Talks to Battle only through SignalBus + the node it just instantiated,
## and to Dialogic only through its public Dialogic.start() API.

const BATTLE_SCENE := preload("res://scenes/battle/Battle.tscn")
const PREP_PHASE_SCENE := preload("res://scenes/prep/PrepPhase.tscn")
const CHAPTER_1_MAP := preload("res://data/maps/chapter1.tres")
const CHAPTER_2_MAP := preload("res://data/maps/chapter2.tres")
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"

const ROSTER_UNIT_PATHS := [
	"res://data/units/aurora.tres",
	"res://data/units/lycith.tres",
	"res://data/units/kessa.tres",
	"res://data/units/martin.tres",
]

var _current_battle: Battle
var _current_prep: PrepPhase
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
		{"type": "battle", "map": CHAPTER_1_MAP},
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
			_start_prep(step.get("map"))
		"end":
			_return_to_main()

func _play_dialogue(timeline_path: String) -> void:
	SignalBus.dialogue_requested.emit(timeline_path)
	if not Dialogic.timeline_ended.is_connected(_on_dialogue_finished):
		Dialogic.timeline_ended.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	# Deferred to here (rather than _ready(), alongside register_all())
	# because Dialogic's own subsystems aren't initialized yet during
	# autoload _ready() — CampaignFlow is registered before Dialogic in
	# project.godot. Safe to call every time; only connects once.
	DialogueCharacters.connect_speaker_dimming()
	DialogueCharacters.reset_appearance_tracking()
	Dialogic.start(timeline_path)

func _on_dialogue_finished() -> void:
	SignalBus.dialogue_finished.emit(_steps[_step_index]["timeline"])
	_advance()

## Prep phase (squad selection, deployment, convoy) always runs before a
## battle now — see PrepPhase. Its map is passed explicitly rather than
## relying on Battle.tscn's own scene-default map_data (the old "map": null
## step-1 special case), since PrepPhase needs a map to read before any
## Battle instance exists.
func _start_prep(map_data: BattleMapData) -> void:
	_current_prep = PREP_PHASE_SCENE.instantiate()
	_current_prep.map_data = map_data
	_current_prep.prep_confirmed.connect(_on_prep_confirmed, CONNECT_ONE_SHOT)
	add_child(_current_prep)

func _on_prep_confirmed(deployment: Dictionary) -> void:
	var map_data := _current_prep.map_data
	_current_prep.queue_free()
	_current_prep = null
	# One frame's grace so PrepPhase's own grid/rigged-unit nodes are actually
	# gone (queue_free only marks them for deletion at end of frame) before
	# Battle's own heavy spawn (BattleGrid setup + every unit's rig) runs —
	# real stutter caught live from both scenes' setup cost landing in the
	# same frame otherwise. free() instead of queue_free() would dodge this
	# too but isn't safe here: _current_prep is mid-way through emitting the
	# very signal this handler is responding to, and freeing an object while
	# it's still on the call stack is a real crash risk in Godot.
	await get_tree().process_frame
	_start_battle(map_data, deployment)

func _start_battle(map_data: BattleMapData, deployment: Dictionary) -> void:
	GameState.reset_for_new_battle()
	_current_battle = BATTLE_SCENE.instantiate()
	_current_battle.map_data = map_data
	_current_battle.player_deployment = deployment
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
