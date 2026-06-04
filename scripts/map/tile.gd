## A single tile on the battle map.
## Lives as a StaticBody3D in the 3D world.  Its column mesh fills from Y=0 up
## to (height + 1) * HEIGHT_STEP, so the top surface is the walkable surface.
class_name Tile
extends StaticBody3D

const HEIGHT_STEP: float = GameConstants.HEIGHT_STEP
const TILE_SIZE: float = GameConstants.TILE_SIZE

# ── Grid Data ─────────────────────────────────────────────────────────────────

## Position in the 2-D grid (column = x, row = y).
var grid_position: Vector2i = Vector2i.ZERO
## Integer height level; 0 = ground floor.
var height: int = 0
## If false, units cannot enter this tile (wall, cliff, etc.).
var is_walkable: bool = true
## The Unit node currently standing here, or null if empty.
var occupant: Node = null

# ── Visuals ───────────────────────────────────────────────────────────────────

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _highlight_mesh: MeshInstance3D
var _highlight_material: StandardMaterial3D

const BASE_COLOR: Color = Color(0.42, 0.37, 0.30)
const COLOR_TABLE: Dictionary = {
	GameConstants.HIGHLIGHT_MOVE:     Color(0.20, 0.45, 0.95, 0.55),
	GameConstants.HIGHLIGHT_ATTACK:   Color(0.95, 0.20, 0.20, 0.55),
	GameConstants.HIGHLIGHT_HOVER:    Color(0.95, 0.90, 0.20, 0.70),
	GameConstants.HIGHLIGHT_SELECTED: Color(0.20, 0.95, 0.30, 0.80),
	GameConstants.HIGHLIGHT_SKILL:    Color(0.80, 0.20, 0.95, 0.55),
}

# ── Setup ─────────────────────────────────────────────────────────────────────

## Call after setting grid_position and height but BEFORE adding to the tree,
## or rely on _ready() picking up those values if set beforehand.
func _ready() -> void:
	collision_layer = GameConstants.TILE_COLLISION_LAYER
	collision_mask = 0
	_build_mesh()
	_build_collision()
	_build_highlight()
	_apply_geometry()

# ── Public API ────────────────────────────────────────────────────────────────

## World-space position of the top surface (where a unit stands).
func get_surface_position() -> Vector3:
	return Vector3(
		float(grid_position.x) * TILE_SIZE,
		float(height + 1) * HEIGHT_STEP,
		float(grid_position.y) * TILE_SIZE
	)

## True when the tile can currently be entered (walkable and unoccupied).
func is_passable() -> bool:
	return is_walkable and occupant == null

## True when the tile is walkable but is occupied (useful for attack targeting).
func is_occupied() -> bool:
	return is_walkable and occupant != null

func set_highlight(highlight_type: int) -> void:
	if not is_instance_valid(_highlight_mesh):
		return
	if highlight_type == GameConstants.HIGHLIGHT_NONE:
		_highlight_mesh.visible = false
		return
	var color: Color = COLOR_TABLE.get(highlight_type, Color.WHITE)
	_highlight_material.albedo_color = color
	_highlight_mesh.visible = true

# ── Private – geometry construction ──────────────────────────────────────────

func _build_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TileMesh"
	add_child(_mesh_instance)
	_mesh_instance.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BASE_COLOR
	_mesh_instance.set_surface_override_material(0, mat)

func _build_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "TileCollision"
	add_child(_collision_shape)
	_collision_shape.shape = BoxShape3D.new()

func _build_highlight() -> void:
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.name = "Highlight"
	add_child(_highlight_mesh)
	var plane := PlaneMesh.new()
	plane.size = Vector2(TILE_SIZE * 0.88, TILE_SIZE * 0.88)
	_highlight_mesh.mesh = plane
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.albedo_color = Color.TRANSPARENT
	_highlight_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_highlight_material.no_depth_test = true
	_highlight_mesh.set_surface_override_material(0, _highlight_material)
	_highlight_mesh.visible = false

func _apply_geometry() -> void:
	# Node sits at world origin-X/Z for its grid cell; Y stays at 0 so the
	# column always starts from the ground.
	position = Vector3(
		float(grid_position.x) * TILE_SIZE,
		0.0,
		float(grid_position.y) * TILE_SIZE
	)
	var column_height: float = float(height + 1) * HEIGHT_STEP
	var half_h: float = column_height * 0.5

	(_mesh_instance.mesh as BoxMesh).size = Vector3(
		TILE_SIZE * 0.95, column_height, TILE_SIZE * 0.95
	)
	_mesh_instance.position = Vector3(0.0, half_h, 0.0)

	(_collision_shape.shape as BoxShape3D).size = Vector3(
		TILE_SIZE, column_height, TILE_SIZE
	)
	_collision_shape.position = Vector3(0.0, half_h, 0.0)

	_highlight_mesh.position = Vector3(0.0, column_height + 0.005, 0.0)
	name = "Tile_%d_%d" % [grid_position.x, grid_position.y]
