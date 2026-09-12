class_name BattleHUD
extends CanvasLayer
## Battle HUD: turn banner, selected-unit info panel, action menu and the
## end-turn button. Listens to SignalBus for broadcast events (phase
## changes, selection) and is driven directly by the active BattleState for
## one-off presentation (opening/closing the action menu), which knows
## things like "can this unit attack from here" that no one else needs.

signal attack_pressed
signal heal_pressed
signal support_pressed
signal equip_pressed
signal weapon_selected(index: int)
signal wait_pressed
signal cancel_pressed
signal end_turn_pressed

@onready var turn_banner: Label = $TurnBanner
@onready var _phase_banner_flash: ColorRect = $PhaseBannerFlash
@onready var unit_info_panel: UnitInfoPanel = $UnitInfoPanel
@onready var hover_info_panel: UnitInfoPanel = $HoverInfoPanel
@onready var action_menu: ActionMenu = $ActionMenu
@onready var equip_menu: EquipMenu = $EquipMenu
@onready var end_turn_button: Button = $EndTurnButton
@onready var _player_phase_sound: AudioStreamPlayer = $PlayerPhaseSound
@onready var _enemy_phase_sound: AudioStreamPlayer = $EnemyPhaseSound

const SOUND_PLAYER_PHASE := preload("res://assets/audio/sfx/player_phase.mp3")
const SOUND_ENEMY_PHASE := preload("res://assets/audio/sfx/enemy_phase.mp3")

## First-pass colors, per the user's own call ("bleu pour joueur et rouge
## pour ennemi pour commencer") — outline is a dark shade of the same hue,
## same relationship LevelUpScreen's gold-on-dark-brown "LEVEL UP !" uses.
const PLAYER_PHASE_COLOR := Color(0.4, 0.7, 1.0, 1)
const PLAYER_PHASE_OUTLINE := Color(0.03, 0.1, 0.3, 1)
const ENEMY_PHASE_COLOR := Color(1.0, 0.3, 0.3, 1)
const ENEMY_PHASE_OUTLINE := Color(0.3, 0.03, 0.03, 1)

## Same flash+pop timings as LevelUpScreen's "LEVEL UP !" banner — reusing
## the exact toolkit already established there, per the user's own request
## ("un screen comme le level up").
const BANNER_POP_DURATION := 0.3
const BANNER_HOLD_DURATION := 0.5
const BANNER_FADE_DURATION := 0.2
const FLASH_IN_DURATION := 0.15
const FLASH_OUT_DURATION := 0.5
const FLASH_ALPHA := 0.16

func _ready() -> void:
	hover_info_panel.hide_panel()
	action_menu.hide()
	equip_menu.hide()
	action_menu.attack_pressed.connect(func(): attack_pressed.emit())
	action_menu.heal_pressed.connect(func(): heal_pressed.emit())
	action_menu.support_pressed.connect(func(): support_pressed.emit())
	action_menu.equip_pressed.connect(func(): equip_pressed.emit())
	action_menu.wait_pressed.connect(func(): wait_pressed.emit())
	action_menu.cancel_pressed.connect(func(): cancel_pressed.emit())
	equip_menu.weapon_selected.connect(func(i: int): weapon_selected.emit(i))
	equip_menu.cancel_pressed.connect(func(): cancel_pressed.emit())
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	_player_phase_sound.stream = SOUND_PLAYER_PHASE
	_enemy_phase_sound.stream = SOUND_ENEMY_PHASE
	SignalBus.unit_selected.connect(_on_unit_selected)
	SignalBus.unit_deselected.connect(func(): unit_info_panel.hide_panel())

func _on_unit_selected(unit) -> void:
	unit_info_panel.show_unit(unit.unit_data)

## Awaited by StartTurnState — units on either side must not be able to act
## while this is playing (the user's own call: "pendant que l'écran du tour
## apparaît, les unités ne peuvent pas bouger"). StartTurnState only calls
## state_machine.change_state("unit_select"/"enemy_phase") AFTER this
## resolves, so player clicks hit BattleState's no-op default handlers
## (still sitting in StartTurnState) and EnemyPhaseState's own AI-driving
## enter() simply hasn't run yet — no separate "input locked" flag needed,
## just not being in a state that accepts input yet.
func play_player_phase_banner() -> void:
	_player_phase_sound.play()
	await _play_phase_banner("Phase Joueur", PLAYER_PHASE_COLOR, PLAYER_PHASE_OUTLINE)

func play_enemy_phase_banner() -> void:
	_enemy_phase_sound.play()
	await _play_phase_banner("Phase Ennemie", ENEMY_PHASE_COLOR, ENEMY_PHASE_OUTLINE)

## Flash + pop-in + hold + fade, same shape as LevelUpScreen's "LEVEL UP !"
## banner (see there for the original) — awaited by the two public methods
## above, which StartTurnState in turn awaits.
func _play_phase_banner(text: String, font_color: Color, outline_color: Color) -> void:
	turn_banner.text = text
	turn_banner.add_theme_color_override("font_color", font_color)
	turn_banner.add_theme_color_override("font_outline_color", outline_color)
	turn_banner.modulate = Color(1, 1, 1, 0)
	turn_banner.scale = Vector2(0.4, 0.4)
	turn_banner.pivot_offset = turn_banner.size / 2.0
	turn_banner.show()

	var flash_color := font_color
	_phase_banner_flash.color = Color(flash_color.r, flash_color.g, flash_color.b, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(_phase_banner_flash, "color:a", FLASH_ALPHA, FLASH_IN_DURATION)
	flash_tween.tween_property(_phase_banner_flash, "color:a", 0.0, FLASH_OUT_DURATION)

	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(turn_banner, "scale", Vector2.ONE, BANNER_POP_DURATION)
	pop_tween.parallel().tween_property(turn_banner, "modulate:a", 1.0, BANNER_POP_DURATION * 0.5)
	await pop_tween.finished

	await get_tree().create_timer(BANNER_HOLD_DURATION).timeout

	var out_tween := create_tween()
	out_tween.tween_property(turn_banner, "modulate:a", 0.0, BANNER_FADE_DURATION)
	await out_tween.finished
	turn_banner.hide()
	turn_banner.scale = Vector2.ONE
	turn_banner.modulate = Color(1, 1, 1, 1)

func show_hover_unit(unit_data: UnitData, extra_def_bonus: int = 0) -> void:
	hover_info_panel.show_unit(unit_data, extra_def_bonus)

func hide_hover_unit() -> void:
	hover_info_panel.hide_panel()

## Move phase: same panel as the action menu, but only Cancel (and
## Attack/Heal/Support, when enabled) is clickable — Wait shows enabled too
## — so the layout doesn't jump between phases.
func show_move_menu(can_attack: bool = false, weapon_can_heal: bool = false, can_heal: bool = false, weapon_can_support: bool = false, can_support: bool = false, can_switch_weapon: bool = false, can_wait: bool = false) -> void:
	action_menu.show_for_move(can_attack, weapon_can_heal, can_heal, weapon_can_support, can_support, can_switch_weapon, can_wait)

## `weapon_can_heal`/`weapon_can_support`: whether the equipped weapon
## supports healing/a gauntlet effect at all (controls whether the
## Heal/Support buttons show up on the menu — see ActionMenuState).
## `can_heal`/`can_support`: whether there's actually a target in range
## right now (controls whether they're clickable, same as `can_attack`).
## `can_switch_weapon`: whether the unit has more than one weapon in
## inventory — controls whether the Equip button shows up at all.
func show_action_menu(_unit, can_attack: bool, weapon_can_heal: bool = false, can_heal: bool = false, weapon_can_support: bool = false, can_support: bool = false, can_switch_weapon: bool = false) -> void:
	action_menu.show_for_action(can_attack, weapon_can_heal, can_heal, weapon_can_support, can_support, can_switch_weapon)

func hide_action_menu() -> void:
	action_menu.hide()

func show_equip_menu(unit_data: UnitData, for_action: String = "") -> void:
	equip_menu.show_for_unit(unit_data, for_action)

func hide_equip_menu() -> void:
	equip_menu.hide()
