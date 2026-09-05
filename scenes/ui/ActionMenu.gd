class_name ActionMenu
extends PanelContainer
## Single panel reused for both the move phase (only Cancel is clickable,
## Attack/Wait/Promote sit there greyed out so the button layout doesn't
## jump around) and the post-move action phase.

signal attack_pressed
signal wait_pressed
signal promote_pressed
signal cancel_pressed

@onready var attack_button: Button = $VBox/AttackButton
@onready var wait_button: Button = $VBox/WaitButton
@onready var promote_button: Button = $VBox/PromoteButton
@onready var cancel_button: Button = $VBox/CancelButton

func _ready() -> void:
	attack_button.pressed.connect(func(): attack_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	promote_button.pressed.connect(func(): promote_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())

## Move phase: nothing but Cancel is clickable yet.
func show_for_move() -> void:
	attack_button.disabled = true
	wait_button.disabled = true
	promote_button.visible = false
	cancel_button.visible = true
	show()

## Post-move action phase: real choices, plus Cancel (undoes the move and
## goes back to picking a tile — see ActionMenuState.handle_cancel).
func show_for_action(can_attack: bool, can_promote: bool) -> void:
	attack_button.disabled = not can_attack
	wait_button.disabled = false
	promote_button.visible = can_promote
	cancel_button.visible = true
	show()
