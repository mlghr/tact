## Defines a job class (Warrior, Black Mage, Archer, …).
## Stat multipliers are applied on top of a unit's base stats when they equip this job.
class_name JobData
extends Resource

@export var job_name: String = ""
@export_multiline var description: String = ""

# ── Stat Multipliers ──────────────────────────────────────────────────────────
# Values >1.0 boost that stat; values <1.0 reduce it.

@export_range(0.5, 2.0) var hp_multiplier: float = 1.0
@export_range(0.5, 2.0) var mp_multiplier: float = 1.0
@export_range(0.5, 2.0) var speed_multiplier: float = 1.0
@export_range(0.5, 2.0) var physical_attack_multiplier: float = 1.0
@export_range(0.5, 2.0) var physical_defense_multiplier: float = 1.0
@export_range(0.5, 2.0) var magical_attack_multiplier: float = 1.0
@export_range(0.5, 2.0) var magical_defense_multiplier: float = 1.0

## Base movement range (tiles per turn) for this job before passives.
@export_range(1, 8) var base_move: int = 3
## Maximum height difference (in levels) this job can jump in one step.
@export_range(1, 8) var base_jump: int = 3

# ── Abilities ─────────────────────────────────────────────────────────────────

## Abilities the unit always has access to as this job (cannot be unequipped).
@export var innate_abilities: Array[AbilityData] = []
## Abilities that can be unlocked by spending JP while in this job.
@export var learnable_abilities: Array[AbilityData] = []

# ── Prerequisites ─────────────────────────────────────────────────────────────
## Dict of { job_name: String → jp_required: int }.
## All listed jobs must have been studied to the required JP amount before
## this job becomes available.
@export var prerequisites: Dictionary = {}
