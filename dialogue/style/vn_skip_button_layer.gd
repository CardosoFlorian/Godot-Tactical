@tool
extends DialogicLayoutLayer
## Lets the player skip the current dialogue timeline outright (jump
## straight to whatever CampaignFlow does next) instead of clicking through
## every line — added as the topmost VN style layer so the button always
## receives its own clicks rather than the full-screen advance-input layer
## underneath it.

@onready var _button: Button = $SkipButton

func _ready() -> void:
	super._ready()
	_button.pressed.connect(_on_skip_pressed)

## Fades every joined character out first (the same thing a scripted
## `leave --All--` line at the end of a timeline does), THEN ends the
## timeline. Calling end_timeline() directly used to yank the whole layout
## (textbox included) out instantly while characters were still mid-fade
## from whatever tween was last running on them — looked like portraits
## hanging in the air after the textbox had already vanished.
func _on_skip_pressed() -> void:
	_button.disabled = true
	await Dialogic.Portraits.leave_all_characters()
	Dialogic.end_timeline()
