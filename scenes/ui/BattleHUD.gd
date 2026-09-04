class_name BattleHUD
extends CanvasLayer
## Battle HUD: turn banner, selected-unit info panel, action menu and the
## end-turn button. Listens to SignalBus for broadcast events (phase
## changes, selection) and is driven directly by the active BattleState for
## one-off presentation (opening/closing the action menu), which knows
## things like "can this unit attack from here" that no one else needs.

signal attack_pressed
signal wait_pressed
signal end_turn_pressed

@onready var turn_banner: Label = $TurnBanner
@onready var unit_info_panel: UnitInfoPanel = $UnitInfoPanel
@onready var hover_info_panel: UnitInfoPanel = $HoverInfoPanel
@onready var action_menu: ActionMenu = $ActionMenu
@onready var end_turn_button: Button = $EndTurnButton

func _ready() -> void:
	hover_info_panel.hide_panel()
	action_menu.hide()
	action_menu.attack_pressed.connect(func(): attack_pressed.emit())
	action_menu.wait_pressed.connect(func(): wait_pressed.emit())
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

func show_action_menu(_unit, can_attack: bool) -> void:
	action_menu.set_attack_enabled(can_attack)
	action_menu.show()

func hide_action_menu() -> void:
	action_menu.hide()
