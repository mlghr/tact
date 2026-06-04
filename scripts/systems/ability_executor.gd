## Resolves the effects of an ability and emits the relevant GameEvents signals.
## Handles damage, healing, and hooks into the reaction system.
class_name AbilityExecutor
extends RefCounted

# ── Public API ────────────────────────────────────────────────────────────────

## Execute `ability` used by `user` against `targets` (Array[Unit]).
## Reactions are checked and resolved here as well.
static func execute(user: Unit, ability: AbilityData, targets: Array) -> void:
	GameEvents.ability_used.emit(user, ability, targets)

	# Deduct MP cost
	if ability.mp_cost > 0 and not user.spend_mp(ability.mp_cost):
		return  # Not enough MP (should have been checked before calling)

	for target: Unit in targets:
		if target.is_dead:
			continue
		_apply_to_target(user, target, ability)

## Check and resolve the defender's reaction ability (if any).
## Called by execute() after each hit, and can also be called directly by
## the battle manager if it wants manual control.
static func check_reaction(attacker: Unit, defender: Unit, triggering_ability: AbilityData) -> void:
	if defender.equipped_reaction == null or defender.is_dead:
		return

	GameEvents.reaction_opportunity.emit(attacker, defender, triggering_ability)

	if not DamageCalculator.roll_reaction_trigger(defender.equipped_reaction):
		return

	var reaction := defender.equipped_reaction
	GameEvents.reaction_triggered.emit(defender, reaction, attacker)

	match reaction.effect_type:
		AbilityData.EffectType.COUNTER_PHYSICAL:
			# Counter-attack with a basic physical hit
			if not attacker.is_dead:
				var counter_damage := DamageCalculator.calculate_physical_damage(
					defender, attacker, reaction
				)
				attacker.take_damage(counter_damage)
				GameEvents.unit_damaged.emit(attacker, counter_damage, defender)

		AbilityData.EffectType.COUNTER_MAGICAL:
			if not attacker.is_dead:
				var counter_damage := DamageCalculator.calculate_magical_damage(
					defender, attacker, reaction
				)
				attacker.take_damage(counter_damage)
				GameEvents.unit_damaged.emit(attacker, counter_damage, defender)

		AbilityData.EffectType.EVADE_PHYSICAL:
			# Retroactively undo the damage (handled via flag in _apply_to_target)
			pass  # Full evasion is handled in _apply_to_target before damage is dealt.

		AbilityData.EffectType.NEGATE_MAGIC:
			pass  # Same as evade for magic sources.

# ── Private ───────────────────────────────────────────────────────────────────

static func _apply_to_target(user: Unit, target: Unit, ability: AbilityData) -> void:
	# Give the defender a pre-emptive chance to evade
	if _check_evade(user, target, ability):
		return

	match ability.effect_type:
		AbilityData.EffectType.DAMAGE_PHYSICAL:
			var damage := DamageCalculator.calculate_physical_damage(user, target, ability)
			target.take_damage(damage)
			GameEvents.unit_damaged.emit(target, damage, user)
			check_reaction(user, target, ability)

		AbilityData.EffectType.DAMAGE_MAGICAL:
			var damage := DamageCalculator.calculate_magical_damage(user, target, ability)
			target.take_damage(damage)
			GameEvents.unit_damaged.emit(target, damage, user)
			check_reaction(user, target, ability)

		AbilityData.EffectType.HEAL:
			var amount := DamageCalculator.calculate_heal_amount(user, ability)
			target.restore_hp(amount)
			GameEvents.unit_healed.emit(target, amount, user)

		AbilityData.EffectType.STATUS_APPLY:
			GameEvents.unit_status_applied.emit(target, ability.ability_name)

static func _check_evade(user: Unit, target: Unit, ability: AbilityData) -> bool:
	if target.equipped_reaction == null:
		return false
	var reaction := target.equipped_reaction
	var is_physical_attack := ability.effect_type == AbilityData.EffectType.DAMAGE_PHYSICAL
	var is_magical_attack := ability.effect_type == AbilityData.EffectType.DAMAGE_MAGICAL

	if reaction.effect_type == AbilityData.EffectType.EVADE_PHYSICAL and is_physical_attack:
		if DamageCalculator.roll_reaction_trigger(reaction):
			GameEvents.reaction_triggered.emit(target, reaction, user)
			return true  # Completely dodged
	elif reaction.effect_type == AbilityData.EffectType.NEGATE_MAGIC and is_magical_attack:
		if DamageCalculator.roll_reaction_trigger(reaction):
			GameEvents.reaction_triggered.emit(target, reaction, user)
			return true
	return false
