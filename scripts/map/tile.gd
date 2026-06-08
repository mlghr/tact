## A single tile on the battle map.
## Lives as a StaticBody3D in the 3D world.  Its column mesh fills from Y=0 up
## to (height + 1) * HEIGHT_STEP, so the top surface is the walkable surface.
## Terrain type is derived automatically from height and drives both the
## procedural texture and optional boulder decorations.
@tool
class_name Tile
extends StaticBody3D

const HEIGHT_STEP: float = GameConstants.HEIGHT_STEP
const TILE_SIZE: float = GameConstants.TILE_SIZE

# ── Terrain Types ─────────────────────────────────────────────────────────────

enum TerrainType {
	GRASS,  ## Height 0 — lush green ground.
	DIRT,   ## Height 1 — raised earthy platform.
	ROCK,   ## Height 2+ — stone outcrop with boulder props.
}

# ── Grid Data ─────────────────────────────────────────────────────────────────

## Grid column and row — set this before the tile enters the scene tree.
@export var grid_position: Vector2i = Vector2i.ZERO
## Integer height level; drives mesh height and terrain type.
@export var height: int = 0
## If false, no unit may enter this tile.
@export var is_walkable: bool = true

## Runtime only — not exported.  Cleared automatically on unit death.
var terrain_type: TerrainType = TerrainType.GRASS
var occupant: Node = null

# ── Visual Nodes ──────────────────────────────────────────────────────────────

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D
var _highlight_mesh: MeshInstance3D
var _highlight_material: StandardMaterial3D

# ── Static Material Cache (shared across all Tile instances) ──────────────────

static var _terrain_materials: Array[StandardMaterial3D] = []
static var _materials_initialized: bool = false

# ── Highlight Color Table ─────────────────────────────────────────────────────

const COLOR_TABLE: Dictionary = {
	GameConstants.HIGHLIGHT_MOVE:          Color(0.20, 0.45, 0.95, 0.55),
	GameConstants.HIGHLIGHT_ATTACK:        Color(0.95, 0.20, 0.20, 0.55),
	GameConstants.HIGHLIGHT_HOVER:         Color(0.95, 0.90, 0.20, 0.70),
	GameConstants.HIGHLIGHT_SELECTED:      Color(0.20, 0.95, 0.30, 0.80),
	GameConstants.HIGHLIGHT_SKILL:         Color(0.80, 0.20, 0.95, 0.55),
	GameConstants.HIGHLIGHT_HOVER_VALID:   Color(0.05, 1.00, 0.15, 0.90),
	GameConstants.HIGHLIGHT_HOVER_INVALID: Color(1.00, 0.08, 0.08, 0.80),
}

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	collision_layer = GameConstants.TILE_COLLISION_LAYER
	collision_mask = 0
	terrain_type = _height_to_terrain(height)
	_ensure_materials()
	_build_mesh()
	_build_collision()
	_build_highlight()
	_apply_geometry()
	_add_decorations()

# ── Public API ────────────────────────────────────────────────────────────────

func get_surface_position() -> Vector3:
	return Vector3(
		float(grid_position.x) * TILE_SIZE,
		float(height + 1) * HEIGHT_STEP,
		float(grid_position.y) * TILE_SIZE
	)

func is_passable() -> bool:
	return is_walkable and occupant == null

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

# ── Private – geometry ────────────────────────────────────────────────────────

func _build_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TileMesh"
	add_child(_mesh_instance)
	_mesh_instance.mesh = BoxMesh.new()
	_mesh_instance.set_surface_override_material(0, _terrain_materials[int(terrain_type)])

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

# ── Decorations ───────────────────────────────────────────────────────────────

func _add_decorations() -> void:
	var surface_y: float = float(height + 1) * HEIGHT_STEP
	var rng := RandomNumberGenerator.new()
	# Seed is deterministic per tile so the map looks the same every run.
	rng.seed = grid_position.x * 97 + grid_position.y * 43 + height * 17

	match terrain_type:
		TerrainType.ROCK:
			# 2–4 boulders clustered on rocky outcrops.
			var count := rng.randi_range(2, 4)
			for _i in range(count):
				_spawn_boulder(rng, surface_y)
		TerrainType.DIRT:
			# Occasionally one small rock on dirt platforms.
			if rng.randf() < 0.45:
				_spawn_boulder(rng, surface_y)

func _spawn_boulder(rng: RandomNumberGenerator, surface_y: float) -> void:
	var boulder := MeshInstance3D.new()
	add_child(boulder)

	# Slightly flattened sphere — feels more like a natural rock than a ball.
	var mesh := SphereMesh.new()
	var radius: float = rng.randf_range(0.06, 0.17)
	mesh.radius = radius
	mesh.height = radius * rng.randf_range(0.9, 1.6)
	mesh.radial_segments = 7
	mesh.rings = 4
	boulder.mesh = mesh

	var mat := StandardMaterial3D.new()
	var gray: float = rng.randf_range(0.34, 0.58)
	# Slight warm/cool tint variation so boulders don't look identical.
	var tint: float = rng.randf_range(-0.04, 0.04)
	mat.albedo_color = Color(gray + tint + 0.04, gray, gray - tint)
	mat.roughness = rng.randf_range(0.85, 0.98)
	mat.metallic = 0.02
	boulder.set_surface_override_material(0, mat)

	var ox: float = rng.randf_range(-0.28, 0.28)
	var oz: float = rng.randf_range(-0.28, 0.28)
	# Bury the bottom half of the sphere slightly into the tile surface.
	boulder.position = Vector3(ox, surface_y + radius * 0.55, oz)
	boulder.rotation_degrees = Vector3(
		rng.randf_range(-18.0, 18.0),
		rng.randf_range(0.0, 360.0),
		rng.randf_range(-18.0, 18.0)
	)

# ── Private – static material/texture generation ──────────────────────────────

static func _height_to_terrain(h: int) -> TerrainType:
	if h <= 0:
		return TerrainType.GRASS
	elif h == 1:
		return TerrainType.DIRT
	else:
		return TerrainType.ROCK

## Builds all three terrain materials once; subsequent calls are no-ops.
static func _ensure_materials() -> void:
	if _materials_initialized:
		return
	_materials_initialized = true
	_terrain_materials.clear()
	for terrain_index in range(3):
		_terrain_materials.append(_build_terrain_material(terrain_index as TerrainType))

static func _build_terrain_material(terrain: TerrainType) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.albedo_texture = _generate_noise_texture(terrain)
	return mat

## Generates a 128×128 coherent-noise texture whose colours match the terrain.
static func _generate_noise_texture(terrain: TerrainType) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.11

	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)

	match terrain:
		TerrainType.GRASS:
			noise.seed = 1001
			for py in range(128):
				for px in range(128):
					var n: float = (noise.get_noise_2d(float(px), float(py)) + 1.0) * 0.5
					# Rich green with subtle yellow-green highlights.
					img.set_pixel(px, py, Color(
						lerpf(0.11, 0.27, n),
						lerpf(0.38, 0.62, n),
						lerpf(0.05, 0.14, n)
					))
		TerrainType.DIRT:
			noise.seed = 2002
			for py in range(128):
				for px in range(128):
					var n: float = (noise.get_noise_2d(float(px), float(py)) + 1.0) * 0.5
					# Warm earthy brown.
					img.set_pixel(px, py, Color(
						lerpf(0.36, 0.55, n),
						lerpf(0.26, 0.40, n),
						lerpf(0.09, 0.18, n)
					))
		TerrainType.ROCK:
			noise.seed = 3003
			for py in range(128):
				for px in range(128):
					var n: float = (noise.get_noise_2d(float(px), float(py)) + 1.0) * 0.5
					# Cool gray stone with slight variation.
					img.set_pixel(px, py, Color(
						lerpf(0.40, 0.60, n),
						lerpf(0.38, 0.57, n),
						lerpf(0.34, 0.53, n)
					))

	return ImageTexture.create_from_image(img)
