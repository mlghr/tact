## Overworld map screen — shown between the title and battles.
## Map nodes are spawned from data, connected by drawn lines, and the player
## marker animates smoothly between nodes on travel.
extends Control

# ── Scene refs ────────────────────────────────────────────────────────────────

@onready var _connections_layer: Control    = $MapArea/ConnectionsLayer
@onready var _nodes_container:   Control    = $MapArea/NodesContainer
@onready var _player_marker:     Control    = $MapArea/PlayerMarker
@onready var _overworld_hud:     Control    = $OverworldHUD
@onready var _troupe_overlay:    Control    = $TroupeOverlay
@onready var _fade_overlay:      ColorRect  = $FadeOverlay

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG:           Color = Color(0.06, 0.07, 0.10)
const C_CONN_IDLE:    Color = Color(0.28, 0.35, 0.48, 0.60)
const C_CONN_REACH:   Color = Color(0.55, 0.65, 0.85, 0.90)
const C_NODE_TOWN:    Color = Color(0.22, 0.44, 0.72)
const C_NODE_BATTLE:  Color = Color(0.72, 0.22, 0.22)
const C_NODE_STORY:   Color = Color(0.72, 0.58, 0.18)
const C_NODE_CURRENT: Color = Color(0.90, 0.72, 0.16)
const C_NODE_REACH:   Color = Color(0.85, 0.88, 0.95)
const C_NODE_DIM:     Color = Color(0.28, 0.30, 0.35)
const C_MARKER:       Color = Color(0.30, 0.55, 1.00)

# ── Map data ──────────────────────────────────────────────────────────────────

const BATTLE_SCENE:    String = "res://scenes/battle/battle_scene.tscn"
const STARTING_NODE:   String = "gariland"
## Uniform scale applied to the entire map area.  Increase to zoom in.
const MAP_SCALE:       float  = 1.75

var _map_nodes: Array[MapNodeData] = []
## id → MapNodeData
var _node_data_map: Dictionary = {}
## id → Control (the clickable node widget on screen)
var _node_widgets: Dictionary = {}

# ── State ─────────────────────────────────────────────────────────────────────

var _current_node_id: String = STARTING_NODE
var _hovered_node_id: String = ""
var _is_traveling: bool = false

# ── Pause state ───────────────────────────────────────────────────────────────

var _pause_menu: Control = null
var _is_paused: bool = false

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_map_data()
	_spawn_node_widgets()
	_connections_layer.overworld_map = self
	_connections_layer.queue_redraw()

	# Scale the whole map area uniformly. Adjust MAP_SCALE to taste.
	var map_area: Control = $MapArea
	map_area.scale = Vector2(MAP_SCALE, MAP_SCALE)
	_place_player_marker(_current_node_id, false)
	_refresh_node_visuals()
	_style_player_marker()
	_style_troupe_overlay()

	# Pause menu (reuse the battle pause menu scene)
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	_pause_menu = pause_scene.instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func(): _is_paused = false)

	# HUD signals
	_overworld_hud.troupe_pressed.connect(_on_troupe_pressed)
	_overworld_hud.update_location(_get_node(_current_node_id))

	# Fade in
	_fade_overlay.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _is_paused:
				_pause_menu.close_menu()
			elif _troupe_overlay.visible:
				_troupe_overlay.hide()
			else:
				_is_paused = true
				_pause_menu.open_menu()
			return

# ── Map data construction ─────────────────────────────────────────────────────

func _build_map_data() -> void:
	_map_nodes = [
		MapNodeData.make("gariland",  "Gariland",         MapNodeData.NodeType.TOWN,
			Vector2(280, 500), ["mandalia", "sweegy"],
			"The royal capital. Your journey begins here."),

		MapNodeData.make("mandalia",  "Mandalia Plains",  MapNodeData.NodeType.BATTLE,
			Vector2(560, 360), ["gariland", "dorter"],
			"Windswept grasslands where brigands lurk.",
			BATTLE_SCENE),

		MapNodeData.make("sweegy",    "Sweegy Woods",     MapNodeData.NodeType.BATTLE,
			Vector2(480, 660), ["gariland", "dorter"],
			"A dark forest thick with monsters.",
			BATTLE_SCENE),

		MapNodeData.make("dorter",    "Dorter Trade City",MapNodeData.NodeType.TOWN,
			Vector2(820, 500), ["mandalia", "sweegy", "araguay", "zirekile"],
			"A bustling merchant hub at the crossroads."),

		MapNodeData.make("araguay",   "Araguay Woods",    MapNodeData.NodeType.BATTLE,
			Vector2(1060, 340), ["dorter"],
			"Ancient trees hide ancient dangers.",
			BATTLE_SCENE),

		MapNodeData.make("zirekile",  "Zirekile Falls",   MapNodeData.NodeType.STORY,
			Vector2(1080, 640), ["dorter"],
			"A great waterfall — something stirs here."),
	]

	for data in _map_nodes:
		_node_data_map[data.node_id] = data

# ── Widget creation ───────────────────────────────────────────────────────────

func _spawn_node_widgets() -> void:
	for data: MapNodeData in _map_nodes:
		var widget := _make_node_widget(data)
		_nodes_container.add_child(widget)
		_node_widgets[data.node_id] = widget

func _make_node_widget(data: MapNodeData) -> Control:
	const NODE_SIZE: float = 90.0

	var root := Control.new()
	root.name = "Node_" + data.node_id
	root.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	# Centre the widget on the map position
	root.position = data.map_position - Vector2(NODE_SIZE * 0.5, NODE_SIZE * 0.5)

	# Circle panel
	var circle := PanelContainer.new()
	circle.name = "Circle"
	circle.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(circle)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = _type_color(data.node_type)
	panel_style.set_corner_radius_all(int(NODE_SIZE * 0.5))
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color.WHITE
	circle.add_theme_stylebox_override("panel", panel_style)

	# Type glyph label inside circle
	var glyph := Label.new()
	glyph.text = _type_glyph(data.node_type)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.add_theme_font_size_override("font_size", 22)
	glyph.add_theme_color_override("font_color", Color(0.92, 0.93, 0.97))
	circle.add_child(glyph)

	# Name label below the circle
	var name_label := Label.new()
	name_label.text = data.node_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.96))
	name_label.position = Vector2(-(120 - NODE_SIZE) * 0.5, NODE_SIZE + 4)
	name_label.custom_minimum_size = Vector2(120, 0)
	root.add_child(name_label)

	# Invisible full-rect button for click / hover detection
	var button := Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	var transparent := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, transparent)
	root.add_child(button)

	button.mouse_entered.connect(func(): _on_node_hovered(data.node_id))
	button.mouse_exited.connect(func(): _on_node_unhovered(data.node_id))
	button.pressed.connect(func(): _on_node_clicked(data.node_id))

	return root

# ── Connections drawing ───────────────────────────────────────────────────────

func _on_draw_connections() -> void:
	var reachable_ids: Array[String] = _get_node(_current_node_id).connected_ids

	# Draw all connections, highlighting reachable ones
	var drawn_pairs: Array = []
	for data: MapNodeData in _map_nodes:
		for connected_id: String in data.connected_ids:
			var pair_key := [data.node_id, connected_id] if data.node_id < connected_id \
				else [connected_id, data.node_id]
			if pair_key in drawn_pairs:
				continue
			drawn_pairs.append(pair_key)

			var from_pos: Vector2 = data.map_position
			var to_pos: Vector2   = _get_node(connected_id).map_position
			var is_reachable: bool = (data.node_id == _current_node_id \
				or connected_id == _current_node_id)

			_connections_layer.draw_line(
				from_pos, to_pos,
				C_CONN_REACH if is_reachable else C_CONN_IDLE,
				3.0 if is_reachable else 2.0,
				true
			)

# ── Hover / click ─────────────────────────────────────────────────────────────

func _on_node_hovered(node_id: String) -> void:
	if _is_traveling or _is_paused:
		return
	_hovered_node_id = node_id
	_refresh_node_visuals()
	var data: MapNodeData = _get_node(node_id)
	_overworld_hud.show_node_info(data, node_id == _current_node_id,
		node_id in _get_node(_current_node_id).connected_ids)

func _on_node_unhovered(_node_id: String) -> void:
	_hovered_node_id = ""
	_refresh_node_visuals()
	_overworld_hud.hide_node_info()

func _on_node_clicked(node_id: String) -> void:
	if _is_traveling or _is_paused or node_id == _current_node_id:
		return
	if node_id not in _get_node(_current_node_id).connected_ids:
		return
	_travel_to(node_id)

# ── Travel ────────────────────────────────────────────────────────────────────

func _travel_to(destination_id: String) -> void:
	_is_traveling = true
	_overworld_hud.hide_node_info()

	var destination: MapNodeData = _get_node(destination_id)

	# Tween player marker
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_player_marker, "position",
		destination.map_position - _player_marker.custom_minimum_size * 0.5,
		0.55)
	await tween.finished

	_current_node_id = destination_id
	_refresh_node_visuals()
	_connections_layer.queue_redraw()
	_overworld_hud.update_location(destination)

	if destination.scene_path != "":
		await get_tree().create_timer(0.35).timeout
		_load_scene(destination.scene_path)
	else:
		_is_traveling = false

func _load_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.55).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))

# ── Visuals ───────────────────────────────────────────────────────────────────

func _refresh_node_visuals() -> void:
	var reachable_ids: Array[String] = _get_node(_current_node_id).connected_ids
	for node_id: String in _node_widgets.keys():
		var widget: Control   = _node_widgets[node_id]
		var circle: PanelContainer = widget.get_node("Circle")
		var style: StyleBoxFlat = circle.get_theme_stylebox("panel") as StyleBoxFlat

		var is_current   := node_id == _current_node_id
		var is_reachable := node_id in reachable_ids
		var is_hovered   := node_id == _hovered_node_id

		if is_current:
			style.border_color = C_NODE_CURRENT
			style.border_width_top    = 4
			style.border_width_bottom = 4
			style.border_width_left   = 4
			style.border_width_right  = 4
			style.bg_color = _type_color(MapNodeData.NodeType.TOWN) \
				if _get_node(node_id).node_type == MapNodeData.NodeType.TOWN \
				else _type_color(_get_node(node_id).node_type)
			widget.scale = Vector2(1.15, 1.15)
		elif is_reachable:
			style.border_color = C_NODE_REACH if not is_hovered else Color.WHITE
			style.set_border_width_all(3)
			style.bg_color = _type_color(_get_node(node_id).node_type)
			widget.scale = Vector2(1.08, 1.08) if is_hovered else Vector2.ONE
		else:
			style.border_color = Color(0.35, 0.38, 0.42)
			style.set_border_width_all(2)
			style.bg_color = C_NODE_DIM
			widget.scale = Vector2.ONE

func _place_player_marker(node_id: String, animate: bool) -> void:
	var target: Vector2 = _get_node(node_id).map_position \
		- _player_marker.custom_minimum_size * 0.5
	if animate:
		var tween := create_tween()
		tween.tween_property(_player_marker, "position", target, 0.4)
	else:
		_player_marker.position = target

# ── Troupe overlay ────────────────────────────────────────────────────────────

func _on_troupe_pressed() -> void:
	_troupe_overlay.show()

func _style_player_marker() -> void:
	var panel: PanelContainer = _player_marker.get_node("MarkerPanel")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.18, 0.95)
	style.border_color = C_MARKER
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

func _style_troupe_overlay() -> void:
	# Style the inner panel (Panel node inside TroupeOverlay)
	var panel: PanelContainer = _troupe_overlay.get_node("Center/TroupePanel")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.13, 0.96)
	style.border_color = Color(0.22, 0.27, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var close_button: Button = _troupe_overlay.get_node(
		"Center/TroupePanel/Margin/ContentBox/CloseButton")
	close_button.pressed.connect(func(): _troupe_overlay.hide())

# ── Helpers ───────────────────────────────────────────────────────────────────

## Typed read from _node_data_map — avoids Variant inference errors on dict access.
func _get_node(node_id: String) -> MapNodeData:
	return _node_data_map[node_id] as MapNodeData

func _type_color(node_type: MapNodeData.NodeType) -> Color:
	match node_type:
		MapNodeData.NodeType.TOWN:   return C_NODE_TOWN
		MapNodeData.NodeType.BATTLE: return C_NODE_BATTLE
		MapNodeData.NodeType.STORY:  return C_NODE_STORY
		_: return C_NODE_BATTLE

func _type_glyph(node_type: MapNodeData.NodeType) -> String:
	match node_type:
		MapNodeData.NodeType.TOWN:   return "⌂"
		MapNodeData.NodeType.BATTLE: return "⚔"
		MapNodeData.NodeType.STORY:  return "★"
		_: return "?"
