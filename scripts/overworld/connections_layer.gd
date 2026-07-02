## Transparent overlay that draws the lines between map nodes.
## Call queue_redraw() whenever node reachability changes.
class_name ConnectionsLayer
extends Control

## Set by OverworldMap after instantiating this node.
var overworld_map: Node = null

func _draw() -> void:
	if overworld_map != null:
		overworld_map._on_draw_connections()
