## Computes damage and healing values using FFT-inspired stat formulas.
## All methods are static — no instance needed.
class_name DamageCalculator
extends RefCounted

## Random variance band applied to all damage results.
const DAMAGE_VARIANCE_MIN: float = 0.88
const DAMAGE_VARIANCE_MAX: float = 1.12

# ── Physical Damage ────────────────────────────────────────────────────────────

## Physical hit:  base = attacker.phys_atk * power/100
##                reduced by (defender.phys_def * 0.5)
##                multiplied by a random variance factor
static func calculate_physical_damage(
	attacker: Unit,
	defender: Unit,
	ability: AbilityData
) -> int:
	var base: float = attacker.physical_attack * (ability.power / 100.0)
	var reduction: float = defender.physical_defense * 0.5
	var raw: float = max(1.0, base - reduction)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	return int(raw * variance)

# ── Magical Damage ─────────────────────────────────────────────────────────────

static func calculate_magical_damage(
	attacker: Unit,
	defender: Unit,
	ability: AbilityData
) -> int:
	var base: float = attacker.magical_attack * (ability.power / 100.0)
	var reduction: float = defender.magical_defense * 0.4
	var raw: float = max(1.0, base - reduction)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	return int(raw * variance)

# ── Healing ────────────────────────────────────────────────────────────────────

static func calculate_heal_amount(
	caster: Unit,
	ability: AbilityData
) -> int:
	var base: float = caster.magical_attack * (ability.power / 100.0)
	var variance: float = randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	return int(base * variance)

# ── Hit / Evade Resolution ─────────────────────────────────────────────────────

## Returns true if the attack lands (simplified: always hits for now;
## extend with Accuracy/Evasion stats when ready).
static func roll_hit(_attacker: Unit, _defender: Unit) -> bool:
	return true

## Returns true for a random reaction ability activation.
static func roll_reaction_trigger(reaction_ability: AbilityData) -> bool:
	return randf() < reaction_ability.trigger_chance
