class_name ActionMenu
extends PanelContainer
## Single panel reused for both the move phase (only Cancel is clickable,
## Attack/Heal/Wait/Promote sit there greyed out or hidden so the button
## layout doesn't jump around) and the post-move action phase.

signal attack_pressed
signal heal_pressed
signal wait_pressed
signal promote_pressed
signal cancel_pressed

@onready var attack_button: Button = $VBox/AttackButton
@onready var heal_button: Button = $VBox/HealButton
@onready var wait_button: Button = $VBox/WaitButton
@onready var promote_button: Button = $VBox/PromoteButton
@onready var cancel_button: Button = $VBox/CancelButton

func _ready() -> void:
	attack_button.pressed.connect(func(): attack_pressed.emit())
	heal_button.pressed.connect(func(): heal_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	promote_button.pressed.connect(func(): promote_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())

## Move phase: Cancel and Wait are always clickable (skipping a unit's turn
## in place is a valid choice on its own, no move required), and Attack/Heal
## too when the unit can already reach/heal a target without moving at all —
## otherwise the player is forced through a "click my own tile to confirm
## not moving, THEN click Attack/Heal/Wait" detour for something that
## doesn't need a move at all (see MoveState.handle_action_chosen, which is
## what actually acts on these buttons when enabled here). Promote still
## needs a real move/confirm first.
func show_for_move(can_attack: bool = false, weapon_can_heal: bool = false, can_heal: bool = false) -> void:
	attack_button.disabled = not can_attack
	heal_button.visible = weapon_can_heal
	heal_button.disabled = not can_heal
	wait_button.disabled = false
	promote_button.visible = false
	cancel_button.visible = true
	show()

## Post-move action phase: real choices, plus Cancel (undoes the move and
## goes back to picking a tile — see ActionMenuState.handle_cancel).
## `weapon_can_heal` controls whether the Heal button shows up at all (most
## units never carry a healing weapon); `can_heal` controls whether it's
## clickable once shown (same "visible vs. enabled" split as `can_attack`).
func show_for_action(can_attack: bool, weapon_can_heal: bool, can_heal: bool, can_promote: bool) -> void:
	attack_button.disabled = not can_attack
	heal_button.visible = weapon_can_heal
	heal_button.disabled = not can_heal
	wait_button.disabled = false
	promote_button.visible = can_promote
	cancel_button.visible = true
	show()
