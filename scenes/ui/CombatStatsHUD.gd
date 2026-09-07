class_name CombatStatsHUD
extends CanvasLayer
## Shown only during Battle._play_combat_scene. The player's unit is always
## LeftPanel and the enemy's always RightPanel (see Battle._play_combat_scene)
## — fixed sides regardless of attacker/defender role or map position.

@onready var left_panel: CombatStatsPanel = $LeftPanel
@onready var right_panel: CombatStatsPanel = $RightPanel

## Center damage-flow arrows (2026-09-07, Fire Emblem Engage-style forecast
## reference; 2026-09-08 reworked into a chronological strike-by-strike
## sequence instead of one fixed row per side) — up to 3 rows, one per
## actual strike this engagement will contain in the order it'll happen:
## first striker, then the other side's counter (if any), then a double
## attack's extra hit (if either side is fast enough — see
## CombatResolver.can_double). Unused rows are just hidden.
const LEFT_COLOR := Color(0.55, 0.75, 1, 1)
const RIGHT_COLOR := Color(1, 0.6, 0.4, 1)

@onready var _arrow_rows: Array[Label] = [
	$ArrowsCenter/ArrowsVBox/Row1,
	$ArrowsCenter/ArrowsVBox/Row2,
	$ArrowsCenter/ArrowsVBox/Row3,
]

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
## `left_dmg`/`right_dmg` are each side's TOTAL damage across every hit they
## land this engagement (see Battle._compute_combat_stats) — what the Dmg
## stat block shows. `left_hits`/`right_hits` (0/1/2) is how many of those
## hits it took to add up to that total, needed to recover the per-swing
## number for the arrow rows below. `first_strike_is_left` says which side
## throws the chronological first hit (the actual attacker, not necessarily
## the left/player panel — see Battle._display_combat_stats).
func show_combat(left_data: UnitData, left_dmg: int, left_hit: int, left_crit: int, left_can_act: bool,
		right_data: UnitData, right_dmg: int, right_hit: int, right_crit: int, right_can_act: bool,
		show_ghost: bool = true, left_hp: int = -1, right_hp: int = -1,
		first_strike_is_left: bool = true, left_hits: int = 1, right_hits: int = 0) -> void:
	_left_data = left_data
	_right_data = right_data
	var right_incoming := right_dmg if show_ghost else 0
	var left_incoming := left_dmg if show_ghost else 0
	left_panel.show_unit(left_data, left_dmg, left_hit, left_crit, left_can_act, right_incoming, left_hp)
	right_panel.show_unit(right_data, right_dmg, right_hit, right_crit, right_can_act, left_incoming, right_hp)
	_update_arrows(left_dmg, left_hits, right_dmg, right_hits, first_strike_is_left)
	show()

## Lays out the arrow rows in real chronological strike order: the first
## striker, then the responder's counter (if it has one), then whichever
## side doubles gets its extra hit appended last — matching
## CombatResolver.resolve_combat's own strike ordering exactly. At most one
## side can ever double (the Spd gap can't favor both at once).
func _update_arrows(left_dmg: int, left_hits: int, right_dmg: int, right_hits: int, first_strike_is_left: bool) -> void:
	var left_per_hit := left_dmg / left_hits if left_hits > 0 else 0
	var right_per_hit := right_dmg / right_hits if right_hits > 0 else 0
	var first_hits := left_hits if first_strike_is_left else right_hits
	var first_per_hit := left_per_hit if first_strike_is_left else right_per_hit
	var second_hits := right_hits if first_strike_is_left else left_hits
	var second_per_hit := right_per_hit if first_strike_is_left else left_per_hit

	var sequence: Array[Dictionary] = [{"is_left": first_strike_is_left, "dmg": first_per_hit}]
	if second_hits > 0:
		sequence.append({"is_left": not first_strike_is_left, "dmg": second_per_hit})
	if first_hits == 2:
		sequence.append({"is_left": first_strike_is_left, "dmg": first_per_hit})
	elif second_hits == 2:
		sequence.append({"is_left": not first_strike_is_left, "dmg": second_per_hit})

	for i in _arrow_rows.size():
		var row := _arrow_rows[i]
		if i < sequence.size():
			var entry: Dictionary = sequence[i]
			var is_left: bool = entry["is_left"]
			row.text = "%d ▶" % entry["dmg"] if is_left else "◀ %d" % entry["dmg"]
			row.add_theme_color_override("font_color", LEFT_COLOR if is_left else RIGHT_COLOR)
			row.visible = true
		else:
			row.visible = false

func update_hp(unit_data: UnitData, new_hp: int) -> void:
	if unit_data == _left_data:
		left_panel.set_hp(new_hp)
	elif unit_data == _right_data:
		right_panel.set_hp(new_hp)

func hide_combat() -> void:
	hide()
