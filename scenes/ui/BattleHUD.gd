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
@onready var unit_info_panel: UnitInfoPanel = $UnitInfoPanel
@onready var hover_info_panel: UnitInfoPanel = $HoverInfoPanel
@onready var action_menu: ActionMenu = $ActionMenu
@onready var equip_menu: EquipMenu = $EquipMenu
@onready var end_turn_button: Button = $EndTurnButton

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
	SignalBus.player_phase_started.connect(func(): turn_banner.text = "Phase Joueur")
	SignalBus.enemy_phase_started.connect(func(): turn_banner.text = "Phase Ennemie")
	SignalBus.unit_selected.connect(_on_unit_selected)
	SignalBus.unit_deselected.connect(func(): unit_info_panel.hide_panel())

func _on_unit_selected(unit) -> void:
	unit_info_panel.show_unit(unit.unit_data)

func show_hover_unit(unit_data: UnitData) -> void:
	hover_info_panel.show_unit(unit_data)

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
