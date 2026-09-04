class_name BattleHUD
extends CanvasLayer
## Battle HUD: turn banner, selected-unit info panel, action menu and the
## end-turn button. Listens to SignalBus for broadcast events (phase
## changes, selection) and is driven directly by the active BattleState for
## one-off presentation (opening/closing the action menu), which knows
## things like "can this unit attack from here" that no one else needs.

signal attack_pressed
signal wait_pressed
signal promote_pressed
signal cancel_move_pressed
signal end_turn_pressed

@onready var turn_banner: Label = $TurnBanner
@onready var unit_info_panel: UnitInfoPanel = $UnitInfoPanel
@onready var hover_info_panel: UnitInfoPanel = $HoverInfoPanel
@onready var action_menu: ActionMenu = $ActionMenu
@onready var cancel_move_button: Button = $CancelMoveButton
@onready var end_turn_button: Button = $EndTurnButton

func _ready() -> void:
	hover_info_panel.hide_panel()
	action_menu.hide()
	cancel_move_button.hide()
	action_menu.attack_pressed.connect(func(): attack_pressed.emit())
	action_menu.wait_pressed.connect(func(): wait_pressed.emit())
	action_menu.promote_pressed.connect(func(): promote_pressed.emit())
	cancel_move_button.pressed.connect(func(): cancel_move_pressed.emit())
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

func show_action_menu(_unit, can_attack: bool, can_promote: bool = false) -> void:
	action_menu.set_attack_enabled(can_attack)
	action_menu.set_promote_visible(can_promote)
	action_menu.show()

func hide_action_menu() -> void:
	action_menu.hide()

## Shown while choosing where to move — an explicit, discoverable way to
## back out and reselect a different unit (also reachable via right-click
## or Escape, but a button beats a hidden keybind).
func show_cancel_move() -> void:
	cancel_move_button.show()

func hide_cancel_move() -> void:
	cancel_move_button.hide()
