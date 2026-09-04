extends Node
## Autoload event bus. Every cross-system communication (UI <-> battle logic
## <-> mission flow <-> Dialogic transitions) goes through here instead of
## direct references, so systems stay decoupled.

# --- Battle turn flow ---
signal player_phase_started
signal enemy_phase_started
signal turn_ended

# --- Unit selection / movement ---
signal unit_selected(unit: Node)
signal unit_deselected
signal move_range_shown(reachable: Dictionary)
signal move_confirmed(unit: Node, path: Array)
signal move_cancelled

# --- Action / targeting ---
signal action_menu_opened(unit: Node)
signal action_chosen(action_name: String)
signal targeting_started(action_name: String, valid_targets: Array)
signal target_selected(target: Node)
signal action_cancelled

# --- Combat resolution ---
signal combat_started(attacker: Node, defender: Node)
signal combat_resolved(result: Dictionary)
signal unit_died(unit: Node)

# --- Battle outcome ---
signal battle_won
signal battle_lost

# --- Campaign / dialogue transitions ---
signal dialogue_requested(timeline_name: String)
signal dialogue_finished(timeline_name: String)
signal battle_requested(battle_scene_path: String)
