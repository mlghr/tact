## Bottom-left HUD panel — shows the active unit's name, job, HP, MP, and CT.
class_name UnitInfoPanel
extends PanelContainer

const C_PANEL_BG:  Color = Color(0.07, 0.08, 0.13, 0.92)
const C_BORDER:    Color = Color(0.22, 0.27, 0.44)
const C_TEXT:      Color = Color(0.92, 0.93, 0.97)
const C_TEXT_DIM:  Color = Color(0.55, 0.60, 0.74)
const C_TRACK:     Color = Color(0.10, 0.11, 0.17)
const C_HP:        Color = Color(0.18, 0.80, 0.40)
const C_MP:        Color = Color(0.28, 0.55, 0.98)
const C_CT:        Color = Color(0.90, 0.72, 0.16)
const C_PLAYER:    Color = Color(0.30, 0.55, 1.00)
const C_ENEMY:     Color = Color(0.90, 0.25, 0.25)

const UI_SCALE: float = 4.0

var _faction_stripe: ColorRect
var _name_label:     Label
var _job_label:      Label
var _hp_bar:         ProgressBar
var _hp_label:       Label
var _mp_bar:         ProgressBar
var _mp_label:       Label
var _ct_bar:         ProgressBar

func _ready() -> void:
	custom_minimum_size = Vector2(480 * UI_SCALE, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_style()
	_build_layout()
	hide()

func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_BORDER
	style.set_border_width_all(int(1 * UI_SCALE))
	style.set_corner_radius_all(int(8 * UI_SCALE))
	style.content_margin_left   = 0.0
	style.content_margin_right  = 18.0 * UI_SCALE
	style.content_margin_top    = 14.0 * UI_SCALE
	style.content_margin_bottom = 16.0 * UI_SCALE
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	add_child(outer)

	_faction_stripe = ColorRect.new()
	_faction_stripe.custom_minimum_size = Vector2(6 * UI_SCALE, 0)
	_faction_stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_faction_stripe.color = C_PLAYER
	outer.add_child(_faction_stripe)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14 * UI_SCALE, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(gap)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", int(8 * UI_SCALE))
	outer.add_child(vbox)

	# Name + Job row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(8 * UI_SCALE))
	vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = "—"
	_name_label.add_theme_font_size_override("font_size", int(26 * UI_SCALE))
	_name_label.add_theme_color_override("font_color", C_TEXT)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_job_label = Label.new()
	_job_label.text = ""
	_job_label.add_theme_font_size_override("font_size", int(17 * UI_SCALE))
	_job_label.add_theme_color_override("font_color", C_TEXT_DIM)
	_job_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_row.add_child(_job_label)

	# Bars
	var hp_row := _make_bar_row("HP", C_HP)
	_hp_bar = hp_row[0]; _hp_label = hp_row[1]
	vbox.add_child(hp_row[2])

	var mp_row := _make_bar_row("MP", C_MP)
	_mp_bar = mp_row[0]; _mp_label = mp_row[1]
	vbox.add_child(mp_row[2])

	var ct_row := _make_bar_row("CT", C_CT, false)
	_ct_bar = ct_row[0]
	vbox.add_child(ct_row[2])

func _make_bar_row(prefix: String, fill_color: Color, show_value: bool = true) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * UI_SCALE))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var prefix_label := Label.new()
	prefix_label.text = prefix
	prefix_label.custom_minimum_size = Vector2(32 * UI_SCALE, 0)
	prefix_label.add_theme_font_size_override("font_size", int(17 * UI_SCALE))
	prefix_label.add_theme_color_override("font_color", fill_color)
	prefix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prefix_label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 22 * UI_SCALE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track := StyleBoxFlat.new()
	track.bg_color = C_TRACK
	track.set_corner_radius_all(int(4 * UI_SCALE))
	bar.add_theme_stylebox_override("background", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(int(4 * UI_SCALE))
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = ""
	value_label.custom_minimum_size = Vector2(90 * UI_SCALE, 0)
	value_label.add_theme_font_size_override("font_size", int(17 * UI_SCALE))
	value_label.add_theme_color_override("font_color", C_TEXT_DIM)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.visible = show_value
	row.add_child(value_label)

	return [bar, value_label, row]

# ── Public API ────────────────────────────────────────────────────────────────

func display_unit(unit: Unit) -> void:
	show()
	_name_label.text = unit.unit_name
	_job_label.text  = unit.current_job.job_name if unit.current_job else ""
	_faction_stripe.color = C_PLAYER if unit.faction == GameConstants.FACTION_PLAYER else C_ENEMY
	_refresh_bars(unit)
	if not unit.hp_changed.is_connected(_on_hp_changed):
		unit.hp_changed.connect(_on_hp_changed)
	if not unit.mp_changed.is_connected(_on_mp_changed):
		unit.mp_changed.connect(_on_mp_changed)

func clear() -> void:
	hide()

func refresh_ct(unit: Unit) -> void:
	if visible:
		_ct_bar.value = clampf(float(unit.ct) / float(GameConstants.CT_THRESHOLD), 0.0, 1.0)

func _refresh_bars(unit: Unit) -> void:
	_hp_bar.value  = float(unit.current_hp) / float(unit.max_hp)
	_hp_label.text = "%d / %d" % [unit.current_hp, unit.max_hp]
	_mp_bar.value  = float(unit.current_mp) / float(unit.max_mp) if unit.max_mp > 0 else 0.0
	_mp_label.text = "%d / %d" % [unit.current_mp, unit.max_mp]
	_ct_bar.value  = clampf(float(unit.ct) / float(GameConstants.CT_THRESHOLD), 0.0, 1.0)

func _on_hp_changed(new_hp: int, max_hp_val: int) -> void:
	_hp_bar.value  = float(new_hp) / float(max_hp_val)
	_hp_label.text = "%d / %d" % [new_hp, max_hp_val]

func _on_mp_changed(new_mp: int, max_mp_val: int) -> void:
	_mp_bar.value  = float(new_mp) / float(max_mp_val) if max_mp_val > 0 else 0.0
	_mp_label.text = "%d / %d" % [new_mp, max_mp_val]
