extends Control

@onready var start_button: Button = $CenterContainer/VBox/StartButton
@onready var permadeath_check: CheckBox = $CenterContainer/VBox/PermadeathCheck

func _ready() -> void:
	permadeath_check.button_pressed = GameState.permadeath_enabled
	start_button.pressed.connect(_on_start_pressed)
	permadeath_check.toggled.connect(func(value: bool): GameState.permadeath_enabled = value)

func _on_start_pressed() -> void:
	CampaignFlow.start_campaign()
