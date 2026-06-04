## Template resource that describes a unit's identity, base stats, starting job,
## and initial ability loadout.  Instantiated once per unit spawned on the map.
class_name UnitDefinition
extends Resource

@export var unit_name: String = "Unknown"
@export var starting_job: JobData

## Faction: use GameConstants.FACTION_* values.
@export var faction: int = 0

# ── Base Stats (before job multipliers) ──────────────────────────────────────

@export_range(1, 999) var base_hp: int = 100
@export_range(0, 999) var base_mp: int = 50
## Speed controls how fast CT charges; higher speed → more frequent turns.
@export_range(1, 30) var base_speed: int = 10
@export_range(1, 99) var base_physical_attack: int = 10
@export_range(1, 99) var base_physical_defense: int = 10
@export_range(1, 99) var base_magical_attack: int = 10
@export_range(1, 99) var base_magical_defense: int = 10

# ── Pre-equipped Abilities ────────────────────────────────────────────────────
# Leave null to have no ability in that slot at game start.

## Active ability set (one ability, active on this unit's turn).
@export var equipped_action_ability: AbilityData = null
## Reaction ability (fires automatically in response to being hit, etc.).
@export var equipped_reaction_ability: AbilityData = null
## Support passive (always-on bonus while equipped).
@export var equipped_support_ability: AbilityData = null
## Movement passive (modifies traversal rules while equipped).
@export var equipped_movement_ability: AbilityData = null
