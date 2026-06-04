## Manages the full grid of Tile nodes and exposes spatial queries used by the
## pathfinder, ability system, and battle manager.
class_name BattleMap
extends Node3D

# ── State ─────────────────────────────────────────────────────────────────────

## All tiles keyed by their Vector2i grid position.
var tiles: Dictionary = {}  # Vector2i → Tile

## Node that holds all Tile children (keeps the scene tree tidy).
var _tiles_root: Node3D

# ── Map Generation ────────────────────────────────────────────────────────────

func _ready() -> void:
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)

## Procedurally build an (width × depth) test map with hand-crafted height data.
func generate_test_map(width: int, depth: int) -> void:
	# Height layout: 0 = flat ground, 1 = low platform, 2 = raised center
	var height_map: Array = _build_test_height_map(width, depth)

	for col in range(width):
		for row in range(depth):
			var tile_height: int = height_map[row][col]
			_add_tile(col, row, tile_height)

## Load an arbitrary list of tile descriptors: Array of {col, row, height, walkable}.
func load_map_data(tile_data: Array) -> void:
	for entry in tile_data:
		_add_tile(entry.col, entry.row, entry.get("height", 0), entry.get("walkable", true))

# ── Tile Queries ──────────────────────────────────────────────────────────────

func get_tile(grid_pos: Vector2i) -> Tile:
	return tiles.get(grid_pos, null)

func has_tile(grid_pos: Vector2i) -> bool:
	return tiles.has(grid_pos)

## Returns the four orthogonally adjacent tiles that exist on the map.
func get_orthogonal_neighbors(grid_pos: Vector2i) -> Array[Tile]:
	var neighbors: Array[Tile] = []
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
	]
	for offset in offsets:
		var neighbor := get_tile(grid_pos + offset)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors

## Returns tiles within Chebyshev distance `range_val`, optionally including
## the origin tile itself.
func get_tiles_in_range(
	origin: Vector2i,
	range_val: int,
	include_origin: bool = false
) -> Array[Tile]:
	var result: Array[Tile] = []
	for dx in range(-range_val, range_val + 1):
		for dz in range(-range_val, range_val + 1):
			if abs(dx) + abs(dz) > range_val:
				continue  # Manhattan distance limit
			if dx == 0 and dz == 0 and not include_origin:
				continue
			var pos := origin + Vector2i(dx, dz)
			var tile := get_tile(pos)
			if tile != null:
				result.append(tile)
	return result

## Returns all tiles currently occupied by a unit of `faction`.
func get_occupied_tiles_by_faction(faction: int) -> Array[Tile]:
	var result: Array[Tile] = []
	for tile: Tile in tiles.values():
		if tile.occupant != null and tile.occupant.faction == faction:
			result.append(tile)
	return result

## Returns all living units on the map belonging to `faction`.
func get_units_by_faction(faction: int) -> Array:
	var result: Array = []
	for tile: Tile in tiles.values():
		if tile.occupant != null and not tile.occupant.is_dead \
				and tile.occupant.faction == faction:
			result.append(tile.occupant)
	return result

## Returns all living units on the map regardless of faction.
func get_all_units() -> Array:
	var result: Array = []
	for tile: Tile in tiles.values():
		if tile.occupant != null and not tile.occupant.is_dead:
			result.append(tile.occupant)
	return result

## Clear all tile highlights.
func clear_all_highlights() -> void:
	for tile: Tile in tiles.values():
		tile.set_highlight(GameConstants.HIGHLIGHT_NONE)

## Highlight a set of tiles with the given highlight type.
func highlight_tiles(tile_list: Array, highlight_type: int) -> void:
	for tile: Tile in tile_list:
		tile.set_highlight(highlight_type)

# ── Unit Placement ────────────────────────────────────────────────────────────

## Place a unit on the given tile and update both the tile's occupant ref
## and the unit's current_tile ref.
func place_unit(unit: Node, target_tile: Tile) -> void:
	if unit.current_tile != null:
		unit.current_tile.occupant = null
	unit.current_tile = target_tile
	target_tile.occupant = unit
	unit.global_position = target_tile.get_surface_position()

# ── Private ───────────────────────────────────────────────────────────────────

func _add_tile(col: int, row: int, tile_height: int, walkable: bool = true) -> void:
	var tile := Tile.new()
	tile.grid_position = Vector2i(col, row)
	tile.height = tile_height
	tile.is_walkable = walkable
	_tiles_root.add_child(tile)
	tiles[Vector2i(col, row)] = tile

func _build_test_height_map(width: int, depth: int) -> Array:
	# Returns a 2-D array [row][col] of integers.
	# Layout for a 10×10 map:
	#   • Central 2×2 plateau at height 2
	#   • A diagonal ridge at height 1
	#   • Everywhere else at height 0
	var height_map: Array = []
	for row in range(depth):
		var row_data: Array = []
		for col in range(width):
			var h: int = 0
			# Central plateau
			if col in [4, 5] and row in [4, 5]:
				h = 2
			# Low ridge
			elif col == row and col in [2, 3, 6, 7]:
				h = 1
			elif col in [2, 3] and row in [6, 7]:
				h = 1
			row_data.append(h)
		height_map.append(row_data)
	return height_map
