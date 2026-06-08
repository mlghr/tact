## Top-center bar showing the next N upcoming turns.
## Each slot shows unit name, job abbreviation, and a live HP bar.
class_name TurnOrderBar
extends HBoxContainer

const C_PANEL_BG:    Color = Color(0.07, 0.08, 0.13, 0.88)
const C_BORDER_IDLE: Color = Color(0.22, 0.27, 0.40)
const C_BORDER_ACT:  Color = Color(0.90, 0.72, 0.16)
const C_PLAYER_BG:   Color = Color(0.10, 0.18, 0.38)
const C_ENEMY_BG:    Color = Color(0.32, 0.08, 0.08)
const C_PLAYER_ACC:  Color = Color(0.30, 0.55, 1.00)
const C_ENEMY_ACC:   Color = Color(0.90, 0.25, 0.25)
const C_HP_TRACK:    Color = Color(0.08, 0.10, 0.16)
const C_HP_FILL:     Color = Color(0.18, 0.78, 0.38)
const C_TEXT:        Color = Color(0.88, 0.90, 0.96)
const C_TEXT_DIM:    Color = Color(0.50, 0.55, 0.68)
const C_EMPTY_BG:    Color = Color(0.07, 0.08, 0.12)

const SLOT_W_ACTIVE: int = 120
const SLOT_W_IDLE:   int = 98
const SLOT_H:        int = 100

var _slots: Array[Dictionary] = []

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots(GameConstants.TURN_PREVIEW_COUNT)

func _build_slots(count: int) -> void:
	for _i in range(count):
		var slot := _make_slot()
		add_child(slot["panel"])
		_slots.append(slot)

func _make_slot() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_W_IDLE, SLOT_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_slot_style(panel, C_EMPTY_BG, C_BORDER_IDLE, false)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var job_lbl := Label.new()
	job_lbl.text = ""
	job_lbl.add_theme_font_size_override("font_size", 14)
	job_lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	job_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	job_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(job_lbl)

	var name_lbl := Label.new()
	name_lbl.text = ""
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", C_TEXT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0.0
	hp_bar.max_value = 1.0
	hp_bar.value = 1.0
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 9)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track := StyleBoxFlat.new()
	track.bg_color = C_HP_TRACK
	track.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = C_HP_FILL
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill)

	vbox.add_child(hp_bar)

	return { "panel": panel, "name_lbl": name_lbl, "job_lbl": job_lbl, "hp_bar": hp_bar }

# ── Public API ────────────────────────────────────────────────────────────────

func refresh(ordered_units: Array) -> void:
	for idx in range(_slots.size()):
		var slot:     Dictionary    = _slots[idx]
		var panel:    PanelContainer = slot["panel"]
		var name_lbl: Label          = slot["name_lbl"]
		var job_lbl:  Label          = slot["job_lbl"]
		var hp_bar:   ProgressBar    = slot["hp_bar"]

		if idx < ordered_units.size():
			var unit: Unit  = ordered_units[idx]
			var is_active   := idx == 0
			var bg_color    := C_PLAYER_BG if unit.faction == GameConstants.FACTION.PLAYER else C_ENEMY_BG
			var border_col  := C_BORDER_ACT if is_active else C_BORDER_IDLE
			var acc_color   := C_PLAYER_ACC if unit.faction == GameConstants.FACTION.PLAYER else C_ENEMY_ACC

			_apply_slot_style(panel, bg_color, border_col, is_active)
			panel.custom_minimum_size = Vector2(SLOT_W_ACTIVE if is_active else SLOT_W_IDLE, SLOT_H)
			name_lbl.text = unit.unit_name.left(7)
			name_lbl.add_theme_color_override("font_color", C_TEXT if is_active else acc_color)
			job_lbl.text  = _job_abbrev(unit)
			hp_bar.value  = float(unit.current_hp) / float(unit.max_hp)
			hp_bar.visible = true
			panel.modulate.a = 1.0
		else:
			_apply_slot_style(panel, C_EMPTY_BG, C_BORDER_IDLE, false)
			panel.custom_minimum_size = Vector2(SLOT_W_IDLE, SLOT_H)
			name_lbl.text  = ""
			job_lbl.text   = ""
			hp_bar.visible = false
			panel.modulate.a = 0.30

# ── Private ───────────────────────────────────────────────────────────────────

func _apply_slot_style(panel: PanelContainer, bg: Color, border: Color, is_active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2 if is_active else 1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

func _job_abbrev(unit: Unit) -> String:
	if unit.current_job == null:
		return ""
	var words := unit.current_job.job_name.split(" ")
	var abbrev := ""
	for word in words:
		if word.length() > 0:
			abbrev += word[0].to_upper()
	return abbrev.left(3)
