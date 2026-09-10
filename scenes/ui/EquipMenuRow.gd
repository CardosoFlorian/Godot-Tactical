class_name EquipMenuRow
extends Button
## One row in EquipMenu, one per inventory slot — instanced at runtime by
## EquipMenu.show_for_unit rather than existing as fixed nodes in that
## scene, since inventory size varies per unit. Wraps a whole (non-flat, so
## each row has a visible border/background of its own — legibility was the
## user's #1 complaint on the first version) Button, with a margin-padded
## HBoxContainer of visuals (all mouse_filter IGNORE) laid on top so clicks
## pass through to the Button underneath rather than being eaten by a child
## control.

signal row_selected(index: int)

@onready var icon_rect: TextureRect = $Margin/Content/Icon
@onready var name_label: Label = $Margin/Content/TextCol/NameLabel
@onready var stats_label: Label = $Margin/Content/TextCol/StatsLabel
@onready var equipped_badge: Label = $Margin/Content/EquippedBadge

var index: int = -1

func _ready() -> void:
	pressed.connect(func(): row_selected.emit(index))

## `is_usable` dims the whole row the same way UnitInfoPanel dims an
## unusable weapon-type icon (modulate alpha, not just Godot's native
## disabled greyout) and disables the button itself as a belt-and-suspenders
## guard — a disabled Button never fires `pressed`, so EquipMenuState never
## even receives an index for a weapon this unit's class can't use.
func setup(weapon: WeaponData, slot_index: int, is_equipped: bool, is_usable: bool) -> void:
	index = slot_index
	icon_rect.texture = weapon.icon
	name_label.text = weapon.display_name
	stats_label.text = "Pui %d  Pré %d%%  Crit %d%%  Por %d-%d" % [weapon.might, weapon.hit, weapon.crit, weapon.min_range, weapon.max_range]
	if weapon.can_debuff():
		var stat_label := WeaponData.DEBUFF_STAT_LABELS[weapon.debuff_stat]
		stats_label.text += "  ·  %s -%d (%dt)" % [stat_label, weapon.debuff_amount, weapon.debuff_duration]
	if weapon.gauntlet_effect == WeaponData.GauntletEffect.FREEZE:
		stats_label.text += "  ·  Gèle (%dt)" % weapon.freeze_duration
	elif weapon.gauntlet_effect == WeaponData.GauntletEffect.KNOCKBACK:
		stats_label.text += "  ·  Repousse %d" % weapon.knockback_distance
	equipped_badge.visible = is_equipped
	modulate = Color.WHITE if is_usable else Color(1, 1, 1, 0.25)
	disabled = not is_usable
