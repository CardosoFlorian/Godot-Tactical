class_name ActionMenu
extends PanelContainer

signal attack_pressed
signal wait_pressed
signal promote_pressed

@onready var attack_button: Button = $VBox/AttackButton
@onready var wait_button: Button = $VBox/WaitButton
@onready var promote_button: Button = $VBox/PromoteButton

func _ready() -> void:
	attack_button.pressed.connect(func(): attack_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	promote_button.pressed.connect(func(): promote_pressed.emit())

func set_attack_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled

func set_promote_visible(visible_: bool) -> void:
	promote_button.visible = visible_
