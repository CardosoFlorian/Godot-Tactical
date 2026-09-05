class_name CombatStatsHUD
extends CanvasLayer
## Shown only during Battle._play_combat_scene. The player's unit is always
## LeftPanel and the enemy's always RightPanel (see Battle._play_combat_scene)
## — fixed sides regardless of attacker/defender role or map position.

@onready var left_panel: CombatStatsPanel = $LeftPanel
@onready var right_panel: CombatStatsPanel = $RightPanel

var _left_data: UnitData
var _right_data: UnitData

func _ready() -> void:
	hide()

## Each panel's ghost HP preview shows the OTHER unit's Dmg stat landing on
## it (already zeroed out upstream, in Battle._compute_combat_stats, if
## that other unit can't actually act) — unless `show_ghost` is false, in
## which case both bars just show real current HP with no preview at all.
## Battle._play_combat_scene turns it off once strikes are actually about
## to land; the TargetingState hover preview (before you've committed)
## leaves it on.
## `left_hp`/`right_hp`: -1 (default) reads current HP straight off the
## UnitData, for the TargetingState hover preview where nothing has
## happened yet. Battle._play_combat_scene passes an explicit pre-fight
## snapshot instead, since CombatResolver has already applied the whole
## fight's HP changes by the time this is called.
func show_combat(left_data: UnitData, left_dmg: int, left_hit: int, left_crit: int, left_can_act: bool,
		right_data: UnitData, right_dmg: int, right_hit: int, right_crit: int, right_can_act: bool,
		show_ghost: bool = true, left_hp: int = -1, right_hp: int = -1) -> void:
	_left_data = left_data
	_right_data = right_data
	var right_incoming := right_dmg if show_ghost else 0
	var left_incoming := left_dmg if show_ghost else 0
	left_panel.show_unit(left_data, left_dmg, left_hit, left_crit, left_can_act, right_incoming, left_hp)
	right_panel.show_unit(right_data, right_dmg, right_hit, right_crit, right_can_act, left_incoming, right_hp)
	show()

func update_hp(unit_data: UnitData, new_hp: int) -> void:
	if unit_data == _left_data:
		left_panel.set_hp(new_hp)
	elif unit_data == _right_data:
		right_panel.set_hp(new_hp)

func hide_combat() -> void:
	hide()
