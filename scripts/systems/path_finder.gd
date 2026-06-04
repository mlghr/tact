## Grid pathfinder using Dijkstra's algorithm.
## Height differences affect movement cost; the unit's Jump stat limits
## how large a height gap it can cross in a single step.
class_name PathFinder
extends RefCounted

# ── Public API ────────────────────────────────────────────────────────────────

## Returns every Tile reachable by `unit` from `start_tile` within the unit's
## move_range.  Tiles occupied by any unit are impassable, but we include tiles
## occupied by ENEMIES so the caller can show them as attack-range targets.
static func get_reachable_tiles(
	start_tile: Tile,
	unit: Unit,
	battle_map: BattleMap,
	ignore_occupants: bool = false
) -> Array[Tile]:
	var cost_map: Dictionary = _dijkstra(start_tile, unit, battle_map, ignore_occupants)
	var reachable: Array[Tile] = []
	for tile: Tile in cost_map.keys():
		if tile != start_tile and cost_map[tile] <= unit.move_range:
			reachable.append(tile)
	return reachable

## Finds the cheapest path from `start_tile` to `end_tile` for `unit`.
## Returns an ordered Array[Tile] including start and end, or [] if unreachable.
static func find_path(
	start_tile: Tile,
	end_tile: Tile,
	unit: Unit,
	battle_map: BattleMap
) -> Array[Tile]:
	var cost_map: Dictionary = _dijkstra(start_tile, unit, battle_map, false)
	if not cost_map.has(end_tile):
		return []

	# Back-trace via a simple predecessor map rebuilt from cost_map + neighbors.
	var predecessor: Dictionary = _build_predecessor_map(
		start_tile, unit, battle_map, cost_map
	)

	var path: Array[Tile] = []
	var current: Tile = end_tile
	while current != null:
		path.push_front(current)
		current = predecessor.get(current, null)
	return path

# ── Private ───────────────────────────────────────────────────────────────────

## Runs Dijkstra from `start_tile` and returns {Tile → cost} for all tiles
## reachable within move_range.  The start tile itself maps to cost 0.
static func _dijkstra(
	start_tile: Tile,
	unit: Unit,
	battle_map: BattleMap,
	ignore_occupants: bool
) -> Dictionary:
	# Godot 4 has no built-in priority queue; we use a simple sorted Array
	# of [cost, Tile] pairs.  Fine for typical tactical map sizes (≤ 20×20).
	var dist: Dictionary = { start_tile: 0 }
	var frontier: Array = [[0, start_tile]]

	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return a[0] < b[0])
		var entry: Array = frontier.pop_front()
		var current_cost: int = entry[0]
		var current_tile: Tile = entry[1]

		if current_cost > unit.move_range:
			break
		if current_cost > int(dist.get(current_tile, 99999)):
			continue  # Stale entry

		for neighbor: Tile in battle_map.get_orthogonal_neighbors(current_tile.grid_position):
			if not _can_enter(current_tile, neighbor, unit, ignore_occupants):
				continue
			var step_cost: int = _movement_cost(current_tile, neighbor)
			var new_cost: int = current_cost + step_cost
			if new_cost <= unit.move_range and new_cost < int(dist.get(neighbor, 99999)):
				dist[neighbor] = new_cost
				frontier.append([new_cost, neighbor])

	return dist

static func _build_predecessor_map(
	start_tile: Tile,
	unit: Unit,
	battle_map: BattleMap,
	cost_map: Dictionary
) -> Dictionary:
	var predecessor: Dictionary = { start_tile: null }
	for tile: Tile in cost_map.keys():
		if tile == start_tile:
			continue
		for neighbor: Tile in battle_map.get_orthogonal_neighbors(tile.grid_position):
			if not cost_map.has(neighbor):
				continue
			var expected_cost: int = int(cost_map[neighbor]) + _movement_cost(neighbor, tile)
			if expected_cost == int(cost_map[tile]):
				predecessor[tile] = neighbor
				break
	return predecessor

## Cost to move from `from_tile` to `to_tile` in a single step.
## Going uphill costs (height_diff + 1); going flat or downhill costs 1.
static func _movement_cost(from_tile: Tile, to_tile: Tile) -> int:
	var height_diff: int = to_tile.height - from_tile.height
	return 1 + max(0, height_diff)

## Whether `unit` can legally step from `from_tile` onto `to_tile`.
static func _can_enter(
	from_tile: Tile,
	to_tile: Tile,
	unit: Unit,
	ignore_occupants: bool
) -> bool:
	if not to_tile.is_walkable:
		return false
	if not ignore_occupants and to_tile.occupant != null:
		return false  # Occupied tiles block passage
	var height_diff: int = abs(to_tile.height - from_tile.height)
	return height_diff <= unit.jump_height
