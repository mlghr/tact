## HUD layer for the overworld map.
## Shows the current location, a hover info panel, and navigation buttons.
class_name OverworldHUD
extends Control

signal troupe_pressed

const C_PANEL_BG:  Color = Color(0.07, 0.08, 0.13, 0.92)
const C_BORDER:    Color = Color(0.22, 0.27, 0.44)
const C_TEXT:      Color = Color(0.92, 0.93, 0.97)
const C_TEXT_DIM:  Color = Color(0.55, 0.60, 0.74)
const C_GOLD:      Color = Color(0.90, 0.72, 0.16)

const NODE_TYPE_NAMES: Dictionary = {
	0: "Town",
	1: "Battle",
	2: "Story Event",
}

@onready var _location_label:   Label         = $TopLeft/Margin/VBox/LocationLabel
@onready var _type_label:       Label         = $TopLeft/Margin/VBox/TypeLabel
@onready var _troupe_button:    Button        = $BottomLeft/TroupeButton
@onready var _node_info_panel:  PanelContainer = $NodeInfoPanel
@onready var _info_name_label:  Label         = $NodeInfoPanel/Margin/VBox/InfoNameLabel
@onready var _info_desc_label:  Label         = $NodeInfoPanel/Margin/VBox/InfoDescLabel
@onready var _info_hint_label:  Label         = $NodeInfoPanel/Margin/VBox/InfoHintLabel

func _ready() -> void:
	_style_top_panel()
	_style_button(_troupe_button, Color(0.55, 0.40, 0.72))
	_style_node_info_panel()
	_troupe_button.pressed.connect(func(): troupe_pressed.emit())
	_node_info_panel.hide()

# ── Public API ────────────────────────────────────────────────────────────────

func update_location(data: MapNodeData) -> void:
	_location_label.text = data.node_name
	_type_label.text     = "● " + NODE_TYPE_NAMES.get(int(data.node_type), "Unknown")
	_type_label.add_theme_color_override("font_color", _type_color(data.node_type))

func show_node_info(data: MapNodeData, is_current: bool, is_reachable: bool) -> void:
	_info_name_label.text = data.node_name
	_info_desc_label.text = data.description

	if is_current:
		_info_hint_label.text = "— Current Location —"
		_info_hint_label.add_theme_color_override("font_color", C_GOLD)
	elif is_reachable:
		_info_hint_label.text = "Click to travel here"
		_info_hint_label.add_theme_color_override("font_color", Color(0.60, 0.88, 0.60))
	else:
		_info_hint_label.text = "Not yet reachable"
		_info_hint_label.add_theme_color_override("font_color", C_TEXT_DIM)

	_node_info_panel.show()

func hide_node_info() -> void:
	_node_info_panel.hide()

# ── Styling ───────────────────────────────────────────────────────────────────

func _style_top_panel() -> void:
	var panel: PanelContainer = $TopLeft
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

func _style_node_info_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	_node_info_panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_stylebox_override("normal",  _make_button_style(accent, Color(0.08, 0.09, 0.15)))
	button.add_theme_stylebox_override("hover",   _make_button_style(accent, Color(0.13, 0.16, 0.26)))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent, Color(accent, 0.22)))
	button.add_theme_stylebox_override("focus",   _make_button_style(accent, Color(0.13, 0.16, 0.26)))

func _make_button_style(accent: Color, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = accent
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left   = 18.0
	style.content_margin_right  = 18.0
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	return style

func _type_color(node_type: MapNodeData.NodeType) -> Color:
	match node_type:
		MapNodeData.NodeType.TOWN:   return Color(0.50, 0.78, 1.00)
		MapNodeData.NodeType.BATTLE: return Color(1.00, 0.55, 0.50)
		MapNodeData.NodeType.STORY:  return Color(1.00, 0.88, 0.40)
		_: return C_TEXT_DIM
