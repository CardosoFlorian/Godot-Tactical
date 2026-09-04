class_name SkillData
extends Resource
## Data-driven skill/ability stub. Instances live as .tres files in
## data/skills/. Effect resolution is intentionally minimal for the MVP —
## this is a slot to expand later (see brief: refine content after the core
## loop works), not a full skill engine.

enum Trigger { PASSIVE, ON_ATTACK, ON_DEFEND, ON_TURN_START }

@export var display_name: String = "Skill"
@export_multiline var description: String = ""
@export var trigger: Trigger = Trigger.PASSIVE
## Flat modifiers applied when the skill triggers. Keys match UnitData stat
## getters ("str", "skl", "spd", "lck", "def", "res", "hit", "crit", "avoid").
@export var stat_modifiers: Dictionary = {}
