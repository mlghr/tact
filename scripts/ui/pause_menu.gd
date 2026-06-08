## Pause overlay — shown over the battle scene when the player presses Escape
## during their turn (or between turns).  Handles its own Return-to-Title fade.
extends Control

signal resume_requested

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

const C_PANEL_BG:      Color = Color(0.07, 0.08, 0.13, 0.96)
const C_BORDER:        Color = Color(0.22, 0.27, 0.44)
const C_SEPARATOR:     Color = Color(0.20, 0.24, 0.38)
const C_ACCENT_RESUME: Color = Color(0.28, 0.55, 1.00)
const C_ACCENT_TITLE:  Color = Color(0.55, 0.40, 0.72)

@onready var _menu_panel:    PanelContainer = $Center/MenuPanel
@onready var _resume_button: Button         = $Center/MenuPanel/Margin/ContentBox/ResumeButton
@onready var _title_button:  Button         = $Center/MenuPanel/Margin/ContentBox/ReturnToTitleButton
@onready var _separator:     HSeparator     = $Center/MenuPanel/Margin/ContentBox/Separator
@onready var _fade_overlay:  ColorRect      = $FadeOverlay

func _ready() -> void:
	_style_panel()
	_style_separator()
	_style_button(_resume_button, C_ACCENT_RESUME)
	_style_button(_title_button,  C_ACCENT_TITLE)
	_resume_button.pressed.connect(_on_resume)
	_title_button.pressed.connect(_on_return_to_title)
	hide()

# ── Public API ────────────────────────────────────────────────────────────────

func open_menu() -> void:
	show()
	_resume_button.disabled = false
	_title_button.disabled  = false
	_fade_overlay.color     = Color(0.0, 0.0, 0.0, 0.0)
	_menu_panel.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_menu_panel, "scale", Vector2.ONE, 0.18)

func close_menu() -> void:
	hide()
	resume_requested.emit()

# ── Private ───────────────────────────────────────────────────────────────────

func _on_resume() -> void:
	close_menu()

func _on_return_to_title() -> void:
	_resume_button.disabled = true
	_title_button.disabled  = true
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.50).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))

# ── Styling ───────────────────────────────────────────────────────────────────

func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color     = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	_menu_panel.add_theme_stylebox_override("panel", style)

func _style_separator() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_SEPARATOR
	_separator.add_theme_stylebox_override("separator", style)
	_separator.add_theme_constant_override("separation", 1)

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color",          Color(0.90, 0.92, 0.97))
	button.add_theme_color_override("font_disabled_color", Color(0.40, 0.42, 0.50))
	button.add_theme_stylebox_override("normal",   _make_button_style(accent, Color(0.08, 0.09, 0.15)))
	button.add_theme_stylebox_override("hover",    _make_button_style(accent, Color(0.13, 0.16, 0.26)))
	button.add_theme_stylebox_override("pressed",  _make_button_style(accent, Color(accent, 0.22)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.28, 0.30, 0.38), Color(0.06, 0.07, 0.10)))
	button.add_theme_stylebox_override("focus",    _make_button_style(accent, Color(0.13, 0.16, 0.26)))

func _make_button_style(accent: Color, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color            = bg
	style.border_color        = accent
	style.border_width_left   = 4
	style.set_corner_radius_all(5)
	style.content_margin_left   = 24.0
	style.content_margin_right  = 24.0
	style.content_margin_top    = 14.0
	style.content_margin_bottom = 14.0
	return style
