class_name CombatStatsPanel
extends PanelContainer
## One side of the combat scene's stat display (see CombatStatsHUD) —
## colored name banner, weapon, a big current-HP number + bar with a ghost
## preview of the incoming hit, and this unit's Dmg/Hit/Crit against the
## other combatant. Dmg/Hit/Crit are fixed for the whole engagement
## (computed once by Battle.execute_attack); HP updates as strikes land.
##
## The ghost preview: GhostBar (behind, translucent) always shows the real
## current HP; HPBar (in front, opaque) shows the *projected* HP after the
## next incoming hit. Since HPBar's value is always <= GhostBar's, the
## opaque front bar covers the "safe" remainder and the translucent tail
## poking out past it reads as "this much is about to be lost". Once a
## strike actually lands, set_hp collapses both bars to the same real
## value — there's no per-strike lookahead past the first hit.

const PLAYER_COLOR := Color(0.16, 0.32, 0.62)
const ENEMY_COLOR := Color(0.62, 0.16, 0.16)
const HP_DRAIN_DURATION := 0.6

@onready var name_banner: Panel = $VBox/NameBanner
@onready var name_label: Label = $VBox/NameBanner/NameLabel
@onready var weapon_icon: TextureRect = $VBox/WeaponRow/WeaponIcon
@onready var weapon_label: Label = $VBox/WeaponRow/WeaponLabel
@onready var hp_value_label: Label = $VBox/HPRow/HPValueLabel
@onready var ghost_bar: ProgressBar = $VBox/HPRow/HPBarStack/GhostBar
@onready var hp_bar: ProgressBar = $VBox/HPRow/HPBarStack/HPBar
@onready var ghost_value_label: Label = $VBox/HPRow/GhostValueLabel
@onready var hp_max_label: Label = $VBox/HPRow/HPMaxLabel
@onready var dmg_value: Label = $VBox/StatsGrid/DmgBlock/DmgValue
@onready var hit_value: Label = $VBox/StatsGrid/HitBlock/HitValue
@onready var crit_value: Label = $VBox/StatsGrid/CritBlock/CritValue

## `can_act` is false when this unit has no way to strike back (out of
## weapon range, or unarmed) — Dmg/Hit/Crit show as "-" rather than a
## misleading 0. `incoming_dmg` is the other combatant's Dmg stat against
## this unit (0 if they can't act), used only for the ghost preview.
## `hp_override`: -1 (default) reads current HP straight off `data`; pass a
## real value to show that instead — see CombatStatsHUD.show_combat.
func show_unit(data: UnitData, dmg: int, hit: int, crit: int, can_act: bool, incoming_dmg: int, hp_override: int = -1) -> void:
	name_label.text = data.display_name

	var style := StyleBoxFlat.new()
	style.bg_color = PLAYER_COLOR if data.team == UnitData.Team.PLAYER else ENEMY_COLOR
	style.set_corner_radius_all(4)
	name_banner.add_theme_stylebox_override("panel", style)

	var weapon := data.get_equipped_weapon()
	weapon_label.text = weapon.display_name if weapon else "A mains nues"
	weapon_icon.texture = weapon.icon if weapon else null
	weapon_icon.visible = weapon_icon.texture != null

	var max_hp := data.get_max_hp()
	var current_hp := hp_override if hp_override >= 0 else data.get_current_hp()
	ghost_bar.max_value = max_hp
	hp_bar.max_value = max_hp
	ghost_bar.value = current_hp
	hp_value_label.text = str(current_hp)
	hp_max_label.text = "/ %d" % max_hp
	_set_projected_hp(current_hp, incoming_dmg)

	dmg_value.text = str(dmg) if can_act else "-"
	hit_value.text = "%d%%" % hit if can_act else "-"
	crit_value.text = "%d%%" % crit if can_act else "-"

func _set_projected_hp(current_hp: int, incoming_dmg: int) -> void:
	var projected := maxi(0, current_hp - incoming_dmg)
	hp_bar.value = projected
	ghost_value_label.text = str(projected) if projected < current_hp else ""

## Called as real strikes land — collapses the ghost preview onto reality
## (no lookahead to whatever strike might come after this one). Bar and
## number are driven off one tween_method so they visibly drain together
## instead of the bar easing while the number jumps straight to the end value.
func set_hp(current: int) -> void:
	ghost_value_label.text = ""
	var tween := create_tween()
	tween.tween_method(_update_hp_display, hp_bar.value, float(current), HP_DRAIN_DURATION)

func _update_hp_display(value: float) -> void:
	var rounded := roundi(value)
	ghost_bar.value = rounded
	hp_bar.value = rounded
	hp_value_label.text = str(rounded)
