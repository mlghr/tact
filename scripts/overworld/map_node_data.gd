## Data describing a single location on the overworld map.
class_name MapNodeData
extends Resource

enum NodeType { TOWN, BATTLE, STORY }

@export var node_id:   String   = ""
@export var node_name: String   = ""
@export var node_type: NodeType = NodeType.BATTLE
@export var map_position: Vector2   = Vector2.ZERO
@export var connected_ids: Array[String] = []
@export var description:   String   = ""
## Path to the PackedScene to load when entering this node (blank = no transition).
@export var scene_path:    String   = ""
@export var is_cleared:    bool     = false

static func make(
	id: String,
	display_name: String,
	type: NodeType,
	pos: Vector2,
	connections: Array[String],
	desc: String = "",
	scene: String = ""
) -> MapNodeData:
	var data := MapNodeData.new()
	data.node_id       = id
	data.node_name     = display_name
	data.node_type     = type
	data.map_position  = pos
	data.connected_ids = connections
	data.description   = desc
	data.scene_path    = scene
	return data
