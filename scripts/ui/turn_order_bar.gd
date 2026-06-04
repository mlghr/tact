## Horizontal bar showing the next N upcoming turns as colored unit portraits.
## Player units = blue, enemy units = red.  The first slot is the active unit.
class_name TurnOrderBar
extends HBoxContainer

const SLOT_SIZE: Vector2 = Vector2(40, 40)
const PLAYER_COLOR: Color = Color(0.25, 0.50, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.25, 0.25)
const ACTIVE_BORDER: Color = Color(1.0, 0.85, 0.1)
const INACTIVE_BORDER: Color = Color(0.3, 0.3, 0.3)

var _slots: Array[PanelContainer] = []

func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots(GameConstants.TURN_PREVIEW_COUNT)

func _build_slots(count: int) -> void:
	for i in range(count):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		var inner := VBoxContainer.new()
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(inner)
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		inner.add_child(name_label)
		add_child(slot)
		_slots.append(slot)
		_set_slot_style(slot, Color(0.15, 0.15, 0.15), INACTIVE_BORDER)

## Update the bar to reflect a new predicted turn order.
func refresh(ordered_units: Array) -> void:
	for idx in range(_slots.size()):
		var slot := _slots[idx]
		var inner := slot.get_child(0) as VBoxContainer
		var name_label := inner.get_child(0) as Label

		if idx < ordered_units.size():
			var unit: Unit = ordered_units[idx]
			var bg_color := PLAYER_COLOR if unit.faction == GameConstants.FACTION_PLAYER else ENEMY_COLOR
			var border_color := ACTIVE_BORDER if idx == 0 else INACTIVE_BORDER
			_set_slot_style(slot, bg_color, border_color)
			name_label.text = _short_name(unit.unit_name)
			slot.modulate.a = 1.0
		else:
			_set_slot_style(slot, Color(0.12, 0.12, 0.12), INACTIVE_BORDER)
			name_label.text = ""
			slot.modulate.a = 0.4

func _set_slot_style(slot: PanelContainer, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)

func _short_name(full_name: String) -> String:
	# Shorten to first 5 characters or first word
	var parts := full_name.split(" ")
	return parts[0].left(5) if parts.size() > 0 else full_name.left(5)
