## HUD panel showing the active (or hovered) unit's stats.
## Displayed in the bottom-left corner of the screen.
class_name UnitInfoPanel
extends PanelContainer

var _name_label: Label
var _job_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _mp_bar: ProgressBar
var _mp_label: Label
var _ct_bar: ProgressBar

func _ready() -> void:
	custom_minimum_size = Vector2(220, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	hide()

func _build_layout() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.add_theme_constant_override("separation", 2)

	# Name + Job row
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = "—"
	_name_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(_name_label)

	_job_label = Label.new()
	_job_label.text = ""
	_job_label.add_theme_font_size_override("font_size", 11)
	_job_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_job_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_job_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(_job_label)

	# HP row
	vbox.add_child(_make_bar_row("HP", Color(0.2, 0.8, 0.3), 1.0,
		func(bar, lbl): _hp_bar = bar; _hp_label = lbl))
	# MP row
	vbox.add_child(_make_bar_row("MP", Color(0.3, 0.5, 1.0), 1.0,
		func(bar, lbl): _mp_bar = bar; _mp_label = lbl))
	# CT row
	vbox.add_child(_make_bar_row("CT", Color(0.9, 0.7, 0.1), 1.0,
		func(bar, lbl): _ct_bar = bar; lbl.visible = false))

func _make_bar_row(label_text: String, bar_color: Color, initial_ratio: float,
		assign_fn: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var prefix := Label.new()
	prefix.text = label_text
	prefix.custom_minimum_size = Vector2(22, 0)
	prefix.add_theme_font_size_override("font_size", 11)
	row.add_child(prefix)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = initial_ratio
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = bar_color
	bar.add_theme_stylebox_override("fill", style)
	row.add_child(bar)

	var value_label := Label.new()
	value_label.text = ""
	value_label.custom_minimum_size = Vector2(60, 0)
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	assign_fn.call(bar, value_label)
	return row

# ── Public API ────────────────────────────────────────────────────────────────

func display_unit(unit: Unit) -> void:
	show()
	_name_label.text = unit.unit_name
	_job_label.text = unit.current_job.job_name if unit.current_job else ""
	_refresh_bars(unit)

	# Connect signals so the panel updates in real time.
	if not unit.hp_changed.is_connected(_on_hp_changed):
		unit.hp_changed.connect(_on_hp_changed)
	if not unit.mp_changed.is_connected(_on_mp_changed):
		unit.mp_changed.connect(_on_mp_changed)

func clear() -> void:
	hide()

func refresh_ct(unit: Unit) -> void:
	if not visible:
		return
	_ct_bar.value = clampf(float(unit.ct) / float(GameConstants.CT_THRESHOLD), 0.0, 1.0)

# ── Private ───────────────────────────────────────────────────────────────────

func _refresh_bars(unit: Unit) -> void:
	_hp_bar.value = float(unit.current_hp) / float(unit.max_hp)
	_hp_label.text = "%d/%d" % [unit.current_hp, unit.max_hp]
	_mp_bar.value = float(unit.current_mp) / float(unit.max_mp) if unit.max_mp > 0 else 0.0
	_mp_label.text = "%d/%d" % [unit.current_mp, unit.max_mp]
	_ct_bar.value = clampf(float(unit.ct) / float(GameConstants.CT_THRESHOLD), 0.0, 1.0)

func _on_hp_changed(new_hp: int, max_hp_val: int) -> void:
	_hp_bar.value = float(new_hp) / float(max_hp_val)
	_hp_label.text = "%d/%d" % [new_hp, max_hp_val]

func _on_mp_changed(new_mp: int, max_mp_val: int) -> void:
	_mp_bar.value = float(new_mp) / float(max_mp_val) if max_mp_val > 0 else 0.0
	_mp_label.text = "%d/%d" % [new_mp, max_mp_val]
