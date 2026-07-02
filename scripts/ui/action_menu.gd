## Action menu shown in the bottom-right when the player's unit is selected.
class_name ActionMenu
extends PanelContainer

signal move_pressed()
signal attack_pressed()
signal ability_pressed(ability: AbilityData)
signal wait_pressed()

const C_PANEL_BG: Color = Color(0.07, 0.08, 0.13, 0.93)
const C_BORDER: Color = Color(0.22, 0.27, 0.44)
const C_HEADER: Color = Color(0.55, 0.60, 0.74)
const C_TEXT: Color = Color(0.90, 0.92, 0.97)
const C_TEXT_DIM: Color = Color(0.45, 0.48, 0.58)
const C_SEPARATOR: Color = Color(0.20, 0.24, 0.36)
const C_ACCENT_MOVE: Color = Color(0.28, 0.55, 1.00)
const C_ACCENT_ATTACK: Color = Color(0.95, 0.42, 0.15)
const C_ACCENT_SKILL: Color = Color(0.68, 0.28, 0.95)
const C_ACCENT_WAIT: Color = Color(0.40, 0.42, 0.50)

const UI_SCALE: float = 2.0

var _button_container: VBoxContainer
var _move_button: Button
var _attack_button: Button
var _ability_buttons: Array[Button] = []
var _wait_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(340 * UI_SCALE, 0)
	_apply_panel_style()
	_build_layout()
	hide()

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(int(1 * UI_SCALE))
	style.set_corner_radius_all(int(8 * UI_SCALE))
	style.set_content_margin_all(12.0 * UI_SCALE)
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", int(5 * UI_SCALE))
	add_child(_button_container)

	var header := Label.new()
	header.text = "ACTIONS"
	header.add_theme_font_size_override("font_size", int(16 * UI_SCALE))
	header.add_theme_color_override("font_color", C_HEADER)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_container.add_child(header)

	_button_container.add_child(_make_separator())

	_move_button = _make_action_button("Move", C_ACCENT_MOVE, _on_move_pressed)
	_attack_button = _make_action_button("Attack", C_ACCENT_ATTACK, _on_attack_pressed)

	_button_container.add_child(_make_separator())
	_wait_button = _make_action_button("Wait", C_ACCENT_WAIT, _on_wait_pressed)

func _make_action_button(label_text: String, accent: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", int(22 * UI_SCALE))
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_color_override("font_disabled_color", C_TEXT_DIM)
	button.add_theme_stylebox_override("normal", _make_button_style(accent, Color(0.09, 0.10, 0.16)))
	button.add_theme_stylebox_override("hover", _make_button_style(accent, Color(0.14, 0.17, 0.26)))
	button.add_theme_stylebox_override("pressed", _make_button_style(accent, Color(0.18, 0.22, 0.34)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.22, 0.24, 0.30), Color(0.07, 0.08, 0.11)))
	button.add_theme_stylebox_override("focus", _make_button_style(accent, Color(0.14, 0.17, 0.26)))
	button.pressed.connect(callback)
	_button_container.add_child(button)
	return button

func _make_button_style(accent: Color, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = accent
	style.border_width_left = int(5 * UI_SCALE)
	style.set_corner_radius_all(int(5 * UI_SCALE))
	style.content_margin_left = 16.0 * UI_SCALE
	style.content_margin_right = 16.0 * UI_SCALE
	style.content_margin_top = 11.0 * UI_SCALE
	style.content_margin_bottom = 11.0 * UI_SCALE
	return style

func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	var separator_style := StyleBoxFlat.new()
	separator_style.bg_color = C_SEPARATOR
	separator.add_theme_stylebox_override("separator", separator_style)
	separator.add_theme_constant_override("separation", int(1 * UI_SCALE))
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator

# ── Public API ────────────────────────────────────────────────────────────────

func show_for_unit(unit: Unit) -> void:
	_clear_ability_buttons()

	_move_button.disabled = not unit.can_move()

	var has_innate := unit.current_job != null \
		and not unit.current_job.innate_abilities.is_empty()
	_attack_button.disabled = not unit.can_act()
	_attack_button.visible = has_innate or unit.equipped_action == null

	if unit.can_act() and unit.equipped_action != null:
		var ability_button := _make_action_button(
			unit.equipped_action.ability_name,
			C_ACCENT_SKILL,
			func(): _on_ability_pressed(unit.equipped_action)
		)
		_ability_buttons.append(ability_button)
		_button_container.move_child(
			_button_container.get_child(_button_container.get_child_count() - 2),
			_button_container.get_child_count() - 1
		)
		_button_container.move_child(_wait_button, _button_container.get_child_count() - 1)

	show()

func hide_menu() -> void:
	hide()

func _clear_ability_buttons() -> void:
	for button in _ability_buttons:
		_button_container.remove_child(button)
		button.queue_free()
	_ability_buttons.clear()

func _on_move_pressed() -> void:
	hide(); move_pressed.emit()

func _on_attack_pressed() -> void:
	hide(); attack_pressed.emit()

func _on_ability_pressed(ability: AbilityData) -> void:
	hide(); ability_pressed.emit(ability)

func _on_wait_pressed() -> void:
	hide(); wait_pressed.emit()
