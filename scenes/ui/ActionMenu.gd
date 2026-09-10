class_name ActionMenu
extends PanelContainer
## Single panel reused for both the move phase (only Cancel is clickable,
## Attack/Heal/Support/Wait/Promote sit there greyed out or hidden so the
## button layout doesn't jump around) and the post-move action phase.

signal attack_pressed
signal heal_pressed
signal support_pressed
signal equip_pressed
signal wait_pressed
signal promote_pressed
signal cancel_pressed

@onready var attack_button: Button = $VBox/AttackButton
@onready var heal_button: Button = $VBox/HealButton
@onready var support_button: Button = $VBox/SupportButton
@onready var equip_button: Button = $VBox/EquipButton
@onready var wait_button: Button = $VBox/WaitButton
@onready var promote_button: Button = $VBox/PromoteButton
@onready var cancel_button: Button = $VBox/CancelButton

func _ready() -> void:
	attack_button.pressed.connect(func(): attack_pressed.emit())
	heal_button.pressed.connect(func(): heal_pressed.emit())
	support_button.pressed.connect(func(): support_pressed.emit())
	equip_button.pressed.connect(func(): equip_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	promote_button.pressed.connect(func(): promote_pressed.emit())
	cancel_button.pressed.connect(func(): cancel_pressed.emit())

## Move phase: Cancel is always clickable, and Wait/Attack/Heal/Support too
## when the unit can already wait/reach/heal/support a target without
## moving at all — otherwise the player is forced through a "click my own
## tile to confirm not moving, THEN click Attack/..." detour for something
## that doesn't need a move at all (see MoveState.handle_action_chosen,
## which is what actually acts on these buttons when enabled here). Equip
## is also available here (unlike Promote, which genuinely needs a real
## move/confirm first) — picking a different weapon than the unit started
## its turn with locks it in place instead of ending its move privilege
## silently; see EquipMenuState.handle_weapon_selected.
##
## This same panel is ALSO reused, via a bare show_move_menu() call with
## every param left at its default, by TargetingState/HealState/
## SupportTargetingState purely for their "only Cancel is clickable" look
## while picking a target — `can_wait` defaulting to false (rather than
## MoveState's real "Wait is always available" rule) is what keeps Wait
## correctly disabled there too, since none of those states implement a
## "wait" action and it used to sit there clickable-but-inert.
func show_for_move(can_attack: bool = false, weapon_can_heal: bool = false, can_heal: bool = false, weapon_can_support: bool = false, can_support: bool = false, can_switch_weapon: bool = false, can_wait: bool = false) -> void:
	attack_button.disabled = not can_attack
	heal_button.visible = weapon_can_heal
	heal_button.disabled = not can_heal
	support_button.visible = weapon_can_support
	support_button.disabled = not can_support
	equip_button.visible = can_switch_weapon
	wait_button.disabled = not can_wait
	promote_button.visible = false
	cancel_button.visible = true
	show()

## Post-move action phase: real choices, plus Cancel (undoes the move and
## goes back to picking a tile — see ActionMenuState.handle_cancel).
## `weapon_can_heal`/`weapon_can_support` control whether the Heal/Support
## buttons show up at all (most units never carry either); `can_heal`/
## `can_support` control whether they're clickable once shown (same
## "visible vs. enabled" split as `can_attack`). `can_switch_weapon` (a unit
## with more than one weapon in inventory) works the same way as
## `weapon_can_heal` — visible-only, no disabled state, since switching is
## always either possible or pointless, nothing in between.
func show_for_action(can_attack: bool, weapon_can_heal: bool, can_heal: bool, weapon_can_support: bool, can_support: bool, can_promote: bool, can_switch_weapon: bool = false) -> void:
	attack_button.disabled = not can_attack
	heal_button.visible = weapon_can_heal
	heal_button.disabled = not can_heal
	support_button.visible = weapon_can_support
	support_button.disabled = not can_support
	equip_button.visible = can_switch_weapon
	wait_button.disabled = false
	promote_button.visible = can_promote
	cancel_button.visible = true
	show()
