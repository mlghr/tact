## Runtime 3D preview for a unit's movement path.
## Draws colored cylinders along each tile-to-tile segment and a cone arrowhead
## at the destination, hovering just above the tile surfaces.
class_name MovePathArrow
extends Node3D

const PLAYER_COLOR: Color = Color(0.10, 0.42, 1.00, 0.88)
const ENEMY_COLOR: Color = Color(1.00, 0.12, 0.10, 0.88)
const NEUTRAL_COLOR: Color = Color(0.85, 0.85, 0.85, 0.88)

const LINE_RADIUS: float = 0.045
const LINE_SURFACE_OFFSET: float = 0.12
const ARROW_HEAD_RADIUS: float = 0.14
const ARROW_HEAD_HEIGHT: float = 0.32

var _segment_materials: Dictionary = {}

func _ready() -> void:
	visible = false

func show_path(path_tiles: Array[Tile], faction: int) -> void:
	clear_path()
	if path_tiles.size() < 2:
		hide_path()
		return

	var path_color := _color_for_faction(faction)
	var path_material := _get_material(path_color)

	for tile_index in range(path_tiles.size() - 1):
		var from_position := _path_point_for_tile(path_tiles[tile_index])
		var to_position := _path_point_for_tile(path_tiles[tile_index + 1])
		_add_line_segment(from_position, to_position, path_material)

	var previous_position := _path_point_for_tile(path_tiles[path_tiles.size() - 2])
	var destination_position := _path_point_for_tile(path_tiles[path_tiles.size() - 1])
	_add_arrow_head(previous_position, destination_position, path_material)
	visible = true

func hide_path() -> void:
	visible = false
	clear_path()

func clear_path() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func _path_point_for_tile(tile: Tile) -> Vector3:
	return tile.get_surface_position() + Vector3.UP * LINE_SURFACE_OFFSET

func _add_line_segment(from_position: Vector3, to_position: Vector3, material: StandardMaterial3D) -> void:
	var segment_vector := to_position - from_position
	var segment_length := segment_vector.length()
	if segment_length <= 0.001:
		return

	var segment_mesh := CylinderMesh.new()
	segment_mesh.top_radius = LINE_RADIUS
	segment_mesh.bottom_radius = LINE_RADIUS
	segment_mesh.height = segment_length
	segment_mesh.radial_segments = 10
	segment_mesh.rings = 1

	var segment_instance := MeshInstance3D.new()
	segment_instance.name = "MoveArrowSegment"
	segment_instance.mesh = segment_mesh
	segment_instance.set_surface_override_material(0, material)
	add_child(segment_instance)

	segment_instance.global_position = from_position + segment_vector * 0.5
	_orient_y_axis_to_direction(segment_instance, segment_vector.normalized())

func _add_arrow_head(from_position: Vector3, destination_position: Vector3, material: StandardMaterial3D) -> void:
	var direction := destination_position - from_position
	if direction.length() <= 0.001:
		return

	var arrow_mesh := CylinderMesh.new()
	arrow_mesh.bottom_radius = ARROW_HEAD_RADIUS
	arrow_mesh.top_radius = 0.0
	arrow_mesh.height = ARROW_HEAD_HEIGHT
	arrow_mesh.radial_segments = 16

	var arrow_instance := MeshInstance3D.new()
	arrow_instance.name = "MoveArrowHead"
	arrow_instance.mesh = arrow_mesh
	arrow_instance.set_surface_override_material(0, material)
	add_child(arrow_instance)

	var normalized_direction := direction.normalized()
	arrow_instance.global_position = destination_position - normalized_direction * (ARROW_HEAD_HEIGHT * 0.35)
	_orient_y_axis_to_direction(arrow_instance, normalized_direction)

func _orient_y_axis_to_direction(node: Node3D, direction: Vector3) -> void:
	var basis := Basis()
	basis.y = direction.normalized()
	basis.x = basis.y.cross(Vector3.UP)
	if basis.x.length_squared() < 0.001:
		basis.x = basis.y.cross(Vector3.FORWARD)
	basis.x = basis.x.normalized()
	basis.z = basis.x.cross(basis.y).normalized()
	node.global_transform = Transform3D(basis, node.global_position)

func _get_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _segment_materials.has(key):
		return _segment_materials[key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.75
	material.roughness = 0.35
	_segment_materials[key] = material
	return material

func _color_for_faction(faction: int) -> Color:
	if faction == GameConstants.FACTION.PLAYER or faction == GameConstants.FACTION_PLAYER:
		return PLAYER_COLOR
	if faction == GameConstants.FACTION.ENEMY or faction == GameConstants.FACTION_ENEMY:
		return ENEMY_COLOR
	return NEUTRAL_COLOR
