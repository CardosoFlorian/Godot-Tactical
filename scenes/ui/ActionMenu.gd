class_name ActionMenu
extends PanelContainer

signal attack_pressed
signal wait_pressed

@onready var attack_button: Button = $VBox/AttackButton
@onready var wait_button: Button = $VBox/WaitButton

func _ready() -> void:
	attack_button.pressed.connect(func(): attack_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())

func set_attack_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
