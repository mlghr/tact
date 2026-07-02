## Move confirmation modal shown before committing a selected movement tile.
extends ConfirmationDialog

const UI_SCALE: float = 1.0

const BASE_SIZE: Vector2i = Vector2i(320, 130)
const BASE_BUTTON_FONT_SIZE: int = 18
const BASE_DIALOG_FONT_SIZE: int = 18

func _ready() -> void:
	size = Vector2i(
		int(BASE_SIZE.x * UI_SCALE),
		int(BASE_SIZE.y * UI_SCALE)
	)
	add_theme_font_size_override("font_size", int(BASE_DIALOG_FONT_SIZE * UI_SCALE))
	get_ok_button().add_theme_font_size_override(
		"font_size",
		int(BASE_BUTTON_FONT_SIZE * UI_SCALE)
	)
	get_cancel_button().add_theme_font_size_override(
		"font_size",
		int(BASE_BUTTON_FONT_SIZE * UI_SCALE)
	)
