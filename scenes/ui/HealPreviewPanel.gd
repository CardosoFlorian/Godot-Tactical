class_name HealPreviewPanel
extends PanelContainer
## Small forecast panel shown while choosing a heal target (hover during
## HealState — see Battle._update_heal_hover). Target's name, current HP
## with a green "ghost" preview of the HP they'd gain, and the flat heal
## amount. Much simpler than CombatStatsPanel (no Dmg/Hit/Crit — healing
## doesn't roll anything) and reuses the same ghost-bar-behind-opaque-bar
## trick but INVERTED: CombatStatsPanel's ghost (behind, translucent) is the
## higher CURRENT hp and the opaque HPBar (front) is the lower post-hit
## value, so the translucent tail poking out reads as "about to be lost".
## Here it's the other way round — ghost (behind) is the higher POST-HEAL
## value, HPBar (front, opaque) is the lower current value, so the
## translucent excess reads as "about to be gained".

const ALLY_BANNER_COLOR := Color(0.16, 0.5, 0.22)

@onready var name_banner: Panel = $VBox/NameBanner
@onready var name_label: Label = $VBox/NameBanner/NameLabel
@onready var hp_value_label: Label = $VBox/HPRow/HPValueLabel
@onready var ghost_bar: ProgressBar = $VBox/HPRow/HPBarStack/GhostBar
@onready var hp_bar: ProgressBar = $VBox/HPRow/HPBarStack/HPBar
@onready var ghost_value_label: Label = $VBox/HPRow/GhostValueLabel
@onready var hp_max_label: Label = $VBox/HPRow/HPMaxLabel
@onready var heal_value: Label = $VBox/HealRow/HealValue

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = ALLY_BANNER_COLOR
	style.set_corner_radius_all(4)
	name_banner.add_theme_stylebox_override("panel", style)

func show_preview(target_data: UnitData, heal_amount: int) -> void:
	name_label.text = target_data.display_name

	var max_hp := target_data.get_max_hp()
	var current_hp := target_data.get_current_hp()
	var projected := mini(max_hp, current_hp + heal_amount)

	hp_bar.max_value = max_hp
	ghost_bar.max_value = max_hp
	hp_bar.value = current_hp
	ghost_bar.value = projected
	hp_value_label.text = str(current_hp)
	hp_max_label.text = "/ %d" % max_hp
	ghost_value_label.text = str(projected) if projected > current_hp else ""
	heal_value.text = "+%d" % heal_amount

	show()

func hide_preview() -> void:
	hide()
