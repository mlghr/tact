## Global signal bus for decoupled communication between battle systems.
## Autoloaded as "GameEvents" — emit and connect anywhere without direct references.
extends Node

# ── Battle lifecycle ────────────────────────────────────────────────────────

signal battle_started()
signal battle_ended(winning_faction: int)

# ── Turn management ─────────────────────────────────────────────────────────

## Emitted when a unit's turn begins (before they choose any action).
signal turn_started(unit: Node)
## Emitted after a unit's turn fully resolves (move + action complete or Wait chosen).
signal turn_ended(unit: Node)
## Emitted each time any unit's CT value changes.
signal ct_updated(unit: Node, new_ct: int)

# ── Unit events ──────────────────────────────────────────────────────────────

signal unit_moved(unit: Node, from_tile: Node, to_tile: Node)
signal unit_damaged(unit: Node, damage: int, source: Node)
signal unit_healed(unit: Node, amount: int, source: Node)
signal unit_died(unit: Node)
signal unit_status_applied(unit: Node, status_name: String)
signal unit_status_removed(unit: Node, status_name: String)

# ── Action events ─────────────────────────────────────────────────────────────

signal ability_used(user: Node, ability: Resource, targets: Array)
## Fired during damage resolution so reaction abilities can intercept.
signal reaction_opportunity(attacker: Node, defender: Node, ability: Resource)
signal reaction_triggered(unit: Node, reaction_ability: Resource, trigger_source: Node)

# ── Input / UI events ────────────────────────────────────────────────────────

signal tile_hovered(tile: Node)
signal tile_clicked(tile: Node)
signal unit_selected(unit: Node)
signal unit_deselected()
## Emitted whenever the battle state machine changes phase.
signal battle_phase_changed(new_phase: int)
## Emitted after move/act state changes so the action menu refreshes.
signal active_unit_state_changed(unit: Node)
