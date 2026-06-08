## Describes the layout of a battle map as an editable Resource.
## Assign this to a BattleMap node's map_data property to populate the grid.
## Heights are stored as a flat PackedInt32Array in row-major order:
##   index = row * width + col
@tool
class_name BattleMapData
extends Resource

@export var width: int = 10
@export var depth: int = 10

## Flat array of integer height levels (0 = ground, higher = elevated).
## Must contain exactly width * depth entries.
@export var heights: PackedInt32Array = []

## Tiles that block movement entirely (walls, water, etc.).
@export var blocked_tiles: Array[Vector2i] = []

# ── Helpers ───────────────────────────────────────────────────────────────────

func get_height(col: int, row: int) -> int:
	var idx: int = row * width + col
	if heights.is_empty() or idx < 0 or idx >= heights.size():
		return 0
	return heights[idx]

func is_blocked(col: int, row: int) -> bool:
	return Vector2i(col, row) in blocked_tiles

## Fills the heights array with zeroes to match the current width × depth.
func reset_to_flat() -> void:
	heights = PackedInt32Array()
	heights.resize(width * depth)

## Returns a copy with heights filled from a 2-D Array[Array[int]] (row-major).
static func from_2d_array(grid: Array) -> BattleMapData:
	var data := BattleMapData.new()
	data.depth = grid.size()
	data.width = grid[0].size() if data.depth > 0 else 0
	data.heights = PackedInt32Array()
	for row in grid:
		for h in row:
			data.heights.append(h)
	return data
