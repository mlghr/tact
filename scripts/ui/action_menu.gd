## Pop-up action menu shown when the player selects their unit.
## Emits signals for Move, Attack (basic), Ability, and Wait.
class_name ActionMenu
extends PanelContainer

signal move_pressed()
signal attack_pressed()
signal ability_pressed(ability: AbilityData)
signal wait_pressed()

var _button_container: VBoxContainer
var _move_button: Button
var _attack_button: Button
var _ability_buttons: Array[Button] = []
var _wait_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(140, 0)
	_build_layout()
	hide()

func _build_layout() -> void:
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 2)
	add_child(_button_container)

	_move_button = _make_button("Move", _on_move_pressed)
	_attack_button = _make_button("Attack", _on_attack_pressed)
	_wait_button = _make_button("Wait", _on_wait_pressed)

func _make_button(label: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(callback)
	_button_container.add_child(btn)
	return btn

# ── Public API ────────────────────────────────────────────────────────────────

## Show the menu for `unit`, enabling/disabling options based on turn state.
func show_for_unit(unit: Unit) -> void:
	_clear_ability_buttons()

	_move_button.disabled = not unit.can_move()
	_move_button.modulate = Color.WHITE if unit.can_move() else Color(0.5, 0.5, 0.5)

	# Basic attack (innate ability from job)
	var has_innate := unit.current_job != null \
		and not unit.current_job.innate_abilities.is_empty()
	_attack_button.disabled = not unit.can_act()
	_attack_button.modulate = Color.WHITE if unit.can_act() else Color(0.5, 0.5, 0.5)
	_attack_button.visible = has_innate or unit.equipped_action == null

	# Equipped action ability (if different from the innate one)
	if unit.can_act() and unit.equipped_action != null:
		var btn := _make_button(unit.equipped_action.ability_name,
			func(): _on_ability_pressed(unit.equipped_action))
		_ability_buttons.append(btn)

	_wait_button.get_parent().move_child(_wait_button, _button_container.get_child_count())
	show()

func hide_menu() -> void:
	hide()

# ── Private ───────────────────────────────────────────────────────────────────

func _clear_ability_buttons() -> void:
	for btn in _ability_buttons:
		_button_container.remove_child(btn)
		btn.queue_free()
	_ability_buttons.clear()

func _on_move_pressed() -> void:
	hide()
	move_pressed.emit()

func _on_attack_pressed() -> void:
	hide()
	attack_pressed.emit()

func _on_ability_pressed(ability: AbilityData) -> void:
	hide()
	ability_pressed.emit(ability)

func _on_wait_pressed() -> void:
	hide()
	wait_pressed.emit()
