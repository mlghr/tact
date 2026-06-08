## Title screen controller.
## Handles fade-in on load, button styling, and transition to the battle scene.
extends Control

const BATTLE_SCENE: String = "res://scenes/battle/battle_scene.tscn"

const C_BG:          Color = Color(0.04, 0.05, 0.09, 1.0)
const C_TITLE:       Color = Color(0.92, 0.93, 0.97, 1.0)
const C_SUBTITLE:    Color = Color(0.50, 0.56, 0.72, 1.0)
const C_ACCENT_NEW:  Color = Color(0.28, 0.55, 1.00)
const C_ACCENT_QUIT: Color = Color(0.55, 0.40, 0.72)
const C_BTN_BG:      Color = Color(0.08, 0.09, 0.15)
const C_BTN_HOVER:   Color = Color(0.13, 0.16, 0.26)
const C_BTN_TEXT:    Color = Color(0.90, 0.92, 0.97)

@onready var _fade_overlay: ColorRect  = $FadeOverlay
@onready var _new_game_btn: Button     = $Center/ContentBox/NewGameButton
@onready var _quit_btn: Button         = $Center/ContentBox/QuitButton
@onready var _subtitle_lbl: Label      = $Center/ContentBox/SubtitleLabel

func _ready() -> void:
	_style_button(_new_game_btn, C_ACCENT_NEW)
	_style_button(_quit_btn, C_ACCENT_QUIT)

	_new_game_btn.pressed.connect(_on_new_game)
	_quit_btn.pressed.connect(_on_quit)

	# Fade in from black
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	var fade_in := create_tween()
	fade_in.tween_property(_fade_overlay, "color:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)

	# Subtle subtitle pulse
	_animate_subtitle()

func _animate_subtitle() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_subtitle_lbl, "modulate:a", 0.55, 2.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_subtitle_lbl, "modulate:a", 1.0,  2.2).set_ease(Tween.EASE_IN_OUT)

func _on_new_game() -> void:
	_new_game_btn.disabled = true
	_quit_btn.disabled = true
	var fade_out := create_tween()
	fade_out.tween_property(_fade_overlay, "color:a", 1.0, 0.55).set_ease(Tween.EASE_IN)
	fade_out.tween_callback(
		func(): get_tree().change_scene_to_file(BATTLE_SCENE)
	)

func _on_quit() -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_fade_overlay, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	fade_out.tween_callback(func(): get_tree().quit())

# ── Button styling ────────────────────────────────────────────────────────────

func _style_button(btn: Button, accent: Color) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(C_BTN_TEXT, 0.35))
	btn.add_theme_stylebox_override("normal",   _btn_box(accent, C_BTN_BG))
	btn.add_theme_stylebox_override("hover",    _btn_box(accent, C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed",  _btn_box(accent, Color(accent, 0.25)))
	btn.add_theme_stylebox_override("disabled", _btn_box(Color(0.3, 0.3, 0.4), Color(0.06, 0.07, 0.10)))
	btn.add_theme_stylebox_override("focus",    _btn_box(accent, C_BTN_HOVER))

func _btn_box(accent: Color, bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = accent
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left   = 28.0
	style.content_margin_right  = 28.0
	style.content_margin_top    = 14.0
	style.content_margin_bottom = 14.0
	return style
