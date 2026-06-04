## Defines a single learnable ability: active skill, reaction, support passive, or movement passive.
## Stored as a Resource (.tres) so abilities can be shared between job definitions.
class_name AbilityData
extends Resource

# ── Enumerations ─────────────────────────────────────────────────────────────

enum AbilityType {
	ACTIVE,    ## Used on the unit's turn (attack, spell, skill).
	REACTION,  ## Triggered automatically when specific conditions are met.
	SUPPORT,   ## Passive bonus that is always active when equipped.
	MOVEMENT,  ## Passive that enhances movement or traversal.
}

enum TargetType {
	SINGLE_ENEMY,   ## One enemy unit within range.
	SINGLE_ALLY,    ## One allied unit within range.
	SELF,           ## The user only.
	ALL_ENEMIES,    ## Every living enemy on the map.
	ALL_ALLIES,     ## Every living ally on the map.
	AOE,            ## All units within a radius around the chosen tile.
	EMPTY_TILE,     ## A vacant tile (e.g., teleport destination).
}

enum EffectType {
	DAMAGE_PHYSICAL,  ## Deals physical damage (uses PhysAtk vs PhysDef).
	DAMAGE_MAGICAL,   ## Deals magical damage (uses MagAtk vs MagDef).
	HEAL,             ## Restores HP to the target.
	STATUS_APPLY,     ## Applies a named status effect.
	BUFF_STAT,        ## Temporarily raises one of the target's stats.
	MOVE_BONUS,       ## (Support) Permanently adds stat_bonus to Move.
	JUMP_BONUS,       ## (Support) Permanently adds stat_bonus to Jump.
	HP_BONUS,         ## (Support) Multiplies max HP by stat_multiplier.
	MP_BONUS,         ## (Support) Multiplies max MP by stat_multiplier.
	COUNTER_PHYSICAL, ## (Reaction) Counter with a physical attack when hit.
	COUNTER_MAGICAL,  ## (Reaction) Counter with a magical attack when hit.
	EVADE_PHYSICAL,   ## (Reaction) Chance to completely evade a physical attack.
	NEGATE_MAGIC,     ## (Reaction) Chance to nullify a magical attack.
}

# ── Exported Fields ──────────────────────────────────────────────────────────

@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var ability_type: AbilityType = AbilityType.ACTIVE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var effect_type: EffectType = EffectType.DAMAGE_PHYSICAL

## Range in tiles (Chebyshev distance, 0 = adjacent only, 1 = 1 tile away, etc.).
@export_range(0, 10) var range: int = 1
## AoE blast radius around the chosen target tile (0 = single target).
@export_range(0, 5) var area: int = 0
## Damage/heal expressed as percentage of the relevant attack stat.
@export_range(1, 500) var power: int = 100
## MP required to use this ability.
@export_range(0, 99) var mp_cost: int = 0
## Job Points needed to learn this ability from the parent job.
@export_range(0, 9999) var jp_cost: int = 100

## For REACTION abilities: probability [0.0–1.0] that the reaction fires.
@export_range(0.0, 1.0) var trigger_chance: float = 0.5
## For MOVE_BONUS / JUMP_BONUS / HP_BONUS / MP_BONUS: the integer bonus amount.
@export_range(0, 10) var stat_bonus: int = 1
## For HP_BONUS / MP_BONUS: multiplier applied to the base stat (e.g. 1.2 = +20%).
@export_range(1.0, 3.0) var stat_multiplier: float = 1.0

# ── Convenience Helpers ───────────────────────────────────────────────────────

func is_reaction() -> bool:
	return ability_type == AbilityType.REACTION

func is_support() -> bool:
	return ability_type == AbilityType.SUPPORT

func is_movement() -> bool:
	return ability_type == AbilityType.MOVEMENT

func is_active() -> bool:
	return ability_type == AbilityType.ACTIVE

func targets_enemies() -> bool:
	return target_type == TargetType.SINGLE_ENEMY \
		or target_type == TargetType.ALL_ENEMIES \
		or target_type == TargetType.AOE

func targets_allies() -> bool:
	return target_type == TargetType.SINGLE_ALLY \
		or target_type == TargetType.ALL_ALLIES \
		or target_type == TargetType.SELF
