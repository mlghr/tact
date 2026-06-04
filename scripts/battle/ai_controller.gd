## Simple AI for enemy units.
## Strategy: find the nearest player unit → move as close as possible → attack
## if in range.  Falls back to waiting if no action is possible.
class_name AIController
extends RefCounted

# ── Public API ────────────────────────────────────────────────────────────────

## Decide and execute one full turn for `unit`.  The battle manager should
## await the returned Signal (or just call this synchronously).
static func take_turn(unit: Unit, battle_map: BattleMap) -> void:
	var target := _find_nearest_enemy(unit, battle_map)
	if target == null:
		return  # No targets — nothing to do.

	# Determine the ability to use (prefer equipped action, fall back to Attack).
	var ability := _choose_ability(unit, target)
	if ability == null:
		return

	# Check if target is already in ability range without moving.
	if _is_in_ability_range(unit, target, ability):
		_execute_attack(unit, target, ability)
		unit.has_acted = true
		return

	# Move toward target (try to end up in ability range).
	var move_destination := _find_best_move_toward(unit, target, ability, battle_map)
	if move_destination != null and move_destination != unit.current_tile:
		_move_unit(unit, move_destination, battle_map)
		unit.has_moved = true

	# Attack if now in range.
	if _is_in_ability_range(unit, target, ability) and not unit.has_acted:
		_execute_attack(unit, target, ability)
		unit.has_acted = true

# ── Private ───────────────────────────────────────────────────────────────────

static func _find_nearest_enemy(unit: Unit, battle_map: BattleMap) -> Unit:
	var enemy_faction: int = GameConstants.FACTION_PLAYER \
		if unit.faction == GameConstants.FACTION_ENEMY \
		else GameConstants.FACTION_ENEMY

	var enemies := battle_map.get_units_by_faction(enemy_faction)
	if enemies.is_empty():
		return null

	var nearest: Unit = null
	var nearest_dist: int = 999
	for enemy: Unit in enemies:
		var dist: int = _manhattan(unit.current_tile.grid_position,
			enemy.current_tile.grid_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest

static func _choose_ability(unit: Unit, _target: Unit) -> AbilityData:
	# Use the equipped action ability if it exists and targets enemies.
	if unit.equipped_action != null and unit.equipped_action.targets_enemies():
		return unit.equipped_action
	# Fall back to the innate Attack from the job (first innate ability).
	if unit.current_job != null and not unit.current_job.innate_abilities.is_empty():
		return unit.current_job.innate_abilities[0]
	return null

static func _is_in_ability_range(attacker: Unit, target: Unit, ability: AbilityData) -> bool:
	if attacker.current_tile == null or target.current_tile == null:
		return false
	var dist: int = _manhattan(
		attacker.current_tile.grid_position,
		target.current_tile.grid_position
	)
	return dist <= ability.range

static func _find_best_move_toward(
	unit: Unit,
	target: Unit,
	ability: AbilityData,
	battle_map: BattleMap
) -> Tile:
	var reachable := PathFinder.get_reachable_tiles(unit.current_tile, unit, battle_map)
	# Also include the unit's current tile (stay put is a valid "move").
	reachable.append(unit.current_tile)

	var best_tile: Tile = unit.current_tile
	var best_dist: int = _manhattan(
		unit.current_tile.grid_position,
		target.current_tile.grid_position
	)

	for candidate: Tile in reachable:
		if candidate.occupant != null and candidate != unit.current_tile:
			continue  # Can't end movement on an occupied tile
		var dist_to_target: int = _manhattan(
			candidate.grid_position,
			target.current_tile.grid_position
		)
		# Prefer tiles that put us within ability range; otherwise minimize distance.
		if dist_to_target <= ability.range:
			return candidate
		if dist_to_target < best_dist:
			best_dist = dist_to_target
			best_tile = candidate

	return best_tile

static func _move_unit(unit: Unit, destination: Tile, battle_map: BattleMap) -> void:
	var from_tile := unit.current_tile
	battle_map.place_unit(unit, destination)
	GameEvents.unit_moved.emit(unit, from_tile, destination)

static func _execute_attack(user: Unit, target: Unit, ability: AbilityData) -> void:
	AbilityExecutor.execute(user, ability, [target])

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
