class_name UnitDetailPanel
extends CanvasLayer
## Full "stat sheet" overlay, opened from UnitInfoPanel's new "Détails"
## button — the user's own simplification: instead of cramming techniques
## (and their effects) into the small always-visible corner panel (which
## made it too tall and hard to read), show them here instead, alongside
## stats no other screen shows at all: Critique/Esquive/Précision, computed
## via CombatResolver's "baseline" helpers (get_base_hit/crit/avoid — no
## specific opponent in mind, same as everything else on a general info
## screen; the real per-target number still only ever comes from the actual
## targeting/forecast panel elsewhere). Self-contained: instantiated at the
## SceneTree root by UnitInfoPanel and frees itself when closed, same
## "spawn at root, no other node needs to track it" pattern already used
## for Projectile/ImpactEffect. MUST be a CanvasLayer (not a bare Control)
## like every other Battle overlay (LevelUpLayer, CritPortraitLayer, ...) —
## real bug caught live: a bare Control added to root sits on the default
## render layer, which is still subject to Battle's active Camera2D
## position/zoom, so the panel rendered shrunk and shoved into a corner
## instead of centered on screen.
##
## Two-column layout: stats + techniques on the left, full inventory on the
## right (`_show_inventory` below) — the user's own call, to fit every
## inventory item without cramping the technique text.
##
## Technique sections show only what's ACTUALLY active in combat: equipped
## conditional techniques (gold) and unconditional always-on ones (blue),
## each with full effect text. A learned-but-not-currently-equipped
## conditional technique (possible once a unit outlevels
## MAX_EQUIPPED_TECHNIQUES slots) is deliberately NOT shown here — it does
## nothing in combat while unequipped, so listing it just adds noise; a
## version of this panel briefly did show it and got immediately and
## correctly rejected by the user ("ça sert à rien si tu peux pas la mettre
## en combat").

const EQUIPPED_TECHNIQUE_NAME_COLOR := Color(1.0, 0.85, 0.3, 1)
const ALWAYS_ACTIVE_NAME_COLOR := Color(0.6, 0.8, 1.0, 1)
const TECHNIQUE_EFFECT_COLOR := Color(0.85, 0.85, 0.85, 1)
const EQUIPPED_WEAPON_COLOR := Color(1.0, 0.85, 0.3, 1)
const INVENTORY_WEAPON_COLOR := Color(0.85, 0.85, 0.85, 1)

@onready var dim: ColorRect = $Dim
@onready var name_label: Label = $Center/Panel/Margin/VBox/NameLabel
@onready var stat_str: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatStr
@onready var stat_mag: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatMag
@onready var stat_skl: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatSkl
@onready var stat_spd: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatSpd
@onready var stat_lck: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatLck
@onready var stat_def: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatDef
@onready var stat_res: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatRes
@onready var stat_con: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatCon
@onready var stat_mov: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/StatGrid/StatMov
@onready var stat_hit: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/CombatStatsRow/StatHit
@onready var stat_crit: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/CombatStatsRow/StatCrit
@onready var stat_avoid: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/CombatStatsRow/StatAvoid
@onready var equipped_header: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/EquippedHeader
@onready var equipped_technique_list: VBoxContainer = $Center/Panel/Margin/VBox/Columns/LeftColumn/EquippedTechniqueList
@onready var always_active_header: Label = $Center/Panel/Margin/VBox/Columns/LeftColumn/AlwaysActiveHeader
@onready var always_active_list: VBoxContainer = $Center/Panel/Margin/VBox/Columns/LeftColumn/AlwaysActiveList
@onready var inventory_list: VBoxContainer = $Center/Panel/Margin/VBox/Columns/RightColumn/InventoryList
@onready var close_button: Button = $Center/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	close_button.pressed.connect(func(): queue_free())
	dim.gui_input.connect(_on_dim_gui_input)

## Click-anywhere-outside-the-panel-to-close, same modal pattern used
## elsewhere in this project's overlays — Dim covers the full screen behind
## Center/Panel, so any click that reaches it is necessarily outside the panel.
func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()

func show_unit(unit_data: UnitData, extra_def_bonus: int = 0) -> void:
	name_label.text = "%s — Niv.%d" % [unit_data.display_name, unit_data.level]

	var melee_stat_bonus := CombatResolver._technique_melee_stat_bonus(unit_data)
	UnitInfoPanel._set_stat(stat_str, "Force", unit_data.get_str(), unit_data, WeaponData.DebuffStat.STR, CombatResolver._technique_str_bonus(unit_data) + melee_stat_bonus)
	UnitInfoPanel._set_stat(stat_mag, "Magie", unit_data.get_mag(), unit_data, WeaponData.DebuffStat.MAG)
	UnitInfoPanel._set_stat(stat_skl, "Technique", unit_data.get_skl(), unit_data, WeaponData.DebuffStat.SKL, melee_stat_bonus)
	UnitInfoPanel._set_stat(stat_spd, "Vitesse", unit_data.get_spd(), unit_data, WeaponData.DebuffStat.SPD)
	UnitInfoPanel._set_stat(stat_def, "Defense", unit_data.get_def(), unit_data, WeaponData.DebuffStat.DEF, extra_def_bonus)
	UnitInfoPanel._set_stat(stat_res, "Resist.", unit_data.get_res(), unit_data, WeaponData.DebuffStat.RES)
	UnitInfoPanel._set_stat(stat_lck, "Chance", unit_data.get_lck(), unit_data, WeaponData.DebuffStat.LCK)
	stat_con.text = "Constit. %d" % unit_data.get_con()
	stat_mov.text = "Mouv %d" % unit_data.get_mov()

	# No specific opponent here — see this file's own doc comment for why
	# these are "baseline" numbers, not the exact number a real fight would use.
	stat_hit.text = "Précision %d" % CombatResolver.get_base_hit(unit_data)
	stat_crit.text = "Critique %d" % CombatResolver.get_base_crit(unit_data)
	stat_avoid.text = "Esquive %d" % CombatResolver.get_base_avoid(unit_data)

	_show_techniques(unit_data)
	_show_inventory(unit_data)
	show()

## Only techniques actually doing something in combat right now: equipped
## conditional ones (gold) and unconditional always-on ones (blue) — both
## get the full mechanical description (TechniqueData.get_effect_description(),
## the same auto-generated text UnitsScreen's own picker uses). A learned
## conditional technique NOT currently equipped has zero combat effect, so
## it's deliberately left out entirely (see this file's own doc comment).
func _show_techniques(unit_data: UnitData) -> void:
	for child in equipped_technique_list.get_children():
		child.queue_free()
	for child in always_active_list.get_children():
		child.queue_free()

	for technique: TechniqueData in unit_data.equipped_techniques:
		_add_technique_row(equipped_technique_list, technique, EQUIPPED_TECHNIQUE_NAME_COLOR)

	var has_always_active := false
	for technique: TechniqueData in unit_data.techniques:
		if technique.level_required > unit_data.level or technique.is_conditional():
			continue
		_add_technique_row(always_active_list, technique, ALWAYS_ACTIVE_NAME_COLOR)
		has_always_active = true

	equipped_header.visible = not unit_data.equipped_techniques.is_empty()
	always_active_header.visible = has_always_active

func _add_technique_row(list: VBoxContainer, technique: TechniqueData, name_color: Color) -> void:
	var name_label_row := Label.new()
	name_label_row.text = technique.display_name
	name_label_row.add_theme_font_size_override("font_size", 16)
	name_label_row.add_theme_color_override("font_color", name_color)
	list.add_child(name_label_row)
	var effect_label := Label.new()
	effect_label.text = technique.get_effect_description()
	effect_label.add_theme_font_size_override("font_size", 14)
	effect_label.add_theme_color_override("font_color", TECHNIQUE_EFFECT_COLOR)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(effect_label)

## Full inventory, not just the currently-equipped weapon — user's own call,
## moved here from the single "Arme : X" line to free up room for the
## technique lists above while still keeping every item visible somewhere.
## The equipped one is called out by color/prefix rather than sorted apart,
## so the list order still matches what UnitsScreen/EquipMenu show. Icon +
## stat-line format ("Pui/Pré/Crit/Por") matches EquipMenuRow.setup exactly,
## the project's one existing convention for showing a weapon's stats —
## deliberately reused rather than inventing a second abbreviation scheme.
func _show_inventory(unit_data: UnitData) -> void:
	for child in inventory_list.get_children():
		child.queue_free()
	for i in unit_data.inventory.size():
		var weapon: WeaponData = unit_data.inventory[i]
		var is_equipped := i == unit_data.equipped_index
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.texture = weapon.icon
		row.add_child(icon_rect)

		var text_col := VBoxContainer.new()
		text_col.add_theme_constant_override("separation", 0)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label_row := Label.new()
		name_label_row.text = ("► " if is_equipped else "") + weapon.display_name
		name_label_row.add_theme_font_size_override("font_size", 16)
		name_label_row.add_theme_color_override("font_color", EQUIPPED_WEAPON_COLOR if is_equipped else INVENTORY_WEAPON_COLOR)
		text_col.add_child(name_label_row)

		var stats_label := Label.new()
		stats_label.text = "Pui %d  Pré %d%%  Crit %d%%  Por %d-%d" % [weapon.might, weapon.hit, weapon.crit, weapon.min_range, weapon.max_range]
		stats_label.add_theme_font_size_override("font_size", 12)
		stats_label.add_theme_color_override("font_color", TECHNIQUE_EFFECT_COLOR)
		text_col.add_child(stats_label)

		row.add_child(text_col)
		inventory_list.add_child(row)
	if unit_data.inventory.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune arme"
		empty_label.add_theme_color_override("font_color", INVENTORY_WEAPON_COLOR)
		inventory_list.add_child(empty_label)
