## Manages the full grid of Tile nodes and exposes spatial queries.
## Assign a BattleMapData resource to map_data to populate the grid.
## Decorated with @tool so the map regenerates live inside the Godot editor
## whenever map_data is changed in the Inspector.
@tool
class_name BattleMap
extends Node3D

# ── Map Data ──────────────────────────────────────────────────────────────────

## Assign a BattleMapData resource here (in the Inspector or via code) to build
## the tile grid.  Changing this in the editor regenerates the map immediately.
@export var map_data: BattleMapData:
	set(value):
		map_data = value
		# Only regenerate after _ready() has run (is_node_ready() is false
		# during initial .tscn property assignment, so we let _ready() handle it).
		if is_node_ready():
			_regenerate()

# ── State ─────────────────────────────────────────────────────────────────────

## All tiles keyed by Vector2i grid position.
var tiles: Dictionary = {}  # Vector2i → Tile

var _tiles_root: Node3D

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Always create a clean tiles root.
	if is_instance_valid(_tiles_root):
		_tiles_root.queue_free()
	_tiles_root = Node3D.new()
	_tiles_root.name = "Tiles"
	add_child(_tiles_root)

	if map_data != null:
		_generate_from_data(map_data)
	elif not Engine.is_editor_hint():
		# Fallback: generate the built-in test map if no data was assigned.
		_generate_from_data(_make_default_map_data())

# ── Public API ────────────────────────────────────────────────────────────────

func get_tile(grid_pos: Vector2i) -> Tile:
	return tiles.get(grid_pos, null)

func has_tile(grid_pos: Vector2i) -> bool:
	return tiles.has(grid_pos)

func get_orthogonal_neighbors(grid_pos: Vector2i) -> Array[Tile]:
	var neighbors: Array[Tile] = []
	for offset: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var neighbor := get_tile(grid_pos + offset)
		if neighbor != null:
			neighbors.append(neighbor)
	return neighbors

## Returns tiles within Manhattan distance range_val of origin.
## Set include_origin=true to also return the origin tile itself.
func get_tiles_in_range(
	origin: Vector2i,
	range_val: int,
	include_origin: bool = false
) -> Array[Tile]:
	var result: Array[Tile] = []
	for dx in range(-range_val, range_val + 1):
		for dz in range(-range_val, range_val + 1):
			if abs(dx) + abs(dz) > range_val:
				continue
			if dx == 0 and dz == 0 and not include_origin:
				continue
			var tile := get_tile(origin + Vector2i(dx, dz))
			if tile != null:
				result.append(tile)
	return result

func get_units_by_faction(faction: int) -> Array:
	var result: Array = []
	for tile: Tile in tiles.values():
		if tile.occupant != null and not tile.occupant.is_dead \
				and tile.occupant.faction == faction:
			result.append(tile.occupant)
	return result

func get_all_units() -> Array:
	var result: Array = []
	for tile: Tile in tiles.values():
		if tile.occupant != null and not tile.occupant.is_dead:
			result.append(tile.occupant)
	return result

func clear_all_highlights() -> void:
	for tile: Tile in tiles.values():
		tile.set_highlight(GameConstants.HIGHLIGHT_NONE)

func highlight_tiles(tile_list: Array, highlight_type: int) -> void:
	for tile: Tile in tile_list:
		tile.set_highlight(highlight_type)

func place_unit(unit: Node, target_tile: Tile) -> void:
	if unit.current_tile != null:
		unit.current_tile.occupant = null
	unit.current_tile = target_tile
	target_tile.occupant = unit
	unit.global_position = target_tile.get_surface_position()

## Map dimensions derived from the loaded data (or 0 if none loaded).
func get_width() -> int:
	return map_data.width if map_data != null else 0

func get_depth() -> int:
	return map_data.depth if map_data != null else 0

# ── Private ───────────────────────────────────────────────────────────────────

## Clear existing tiles and rebuild from map_data.
func _regenerate() -> void:
	tiles.clear()
	if is_instance_valid(_tiles_root):
		for child in _tiles_root.get_children():
			child.queue_free()
	else:
		_tiles_root = Node3D.new()
		_tiles_root.name = "Tiles"
		add_child(_tiles_root)

	if map_data != null:
		_generate_from_data(map_data)

func _generate_from_data(data: BattleMapData) -> void:
	for row in range(data.depth):
		for col in range(data.width):
			var tile_height: int = data.get_height(col, row)
			var walkable: bool   = not data.is_blocked(col, row)
			_add_tile(col, row, tile_height, walkable)

func _add_tile(col: int, row: int, tile_height: int, walkable: bool = true) -> void:
	var tile := Tile.new()
	tile.grid_position = Vector2i(col, row)
	tile.height        = tile_height
	tile.is_walkable   = walkable
	_tiles_root.add_child(tile)
	# In @tool context Godot requires owner to be set for the node to
	# appear in the editor scene tree.
	if Engine.is_editor_hint() and get_tree() != null:
		tile.owner = get_tree().edited_scene_root
	tiles[Vector2i(col, row)] = tile

## Built-in 10×10 test layout used when no map_data is assigned at runtime.
func _make_default_map_data() -> BattleMapData:
	var grid: Array = []
	for row in range(10):
		var row_data: Array = []
		for col in range(10):
			var h: int = 0
			if col in [4, 5] and row in [4, 5]:
				h = 2
			elif col == row and col in [2, 3, 6, 7]:
				h = 1
			elif col in [2, 3] and row in [6, 7]:
				h = 1
			row_data.append(h)
		grid.append(row_data)
	return BattleMapData.from_2d_array(grid)
