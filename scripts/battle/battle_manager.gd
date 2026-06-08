## Root node for the battle scene.
## Bootstraps the entire 3-D world, manages the battle state machine, handles
## player input, and orchestrates all other systems.
##
## Scene tree created entirely in _ready() so no .tscn editing is required.
extends Node3D

# ── State Machine ─────────────────────────────────────────────────────────────

enum BattlePhase {
	NONE,
	PLAYER_SELECTING,         ## Player's unit is selected; waiting for action choice.
	PLAYER_SELECTING_MOVE,    ## Move tiles highlighted; waiting for destination click.
	PLAYER_SELECTING_TARGET,  ## Ability targets highlighted; waiting for target click.
	EXECUTING_MOVE,           ## Unit is animating toward its destination.
	EXECUTING_ACTION,         ## Ability effect is resolving.
	AI_TURN,                  ## Enemy unit is taking its turn.
	BATTLE_WON,
	BATTLE_LOST,
}

var _phase: BattlePhase = BattlePhase.NONE

# ── Scene-tree references (defined in battle_scene.tscn) ─────────────────────

## The instanced BattleMap scene child.
@onready var _battle_map: BattleMap = $BattleMap
## Root of the camera rig — rotate this to orbit the map.
@onready var _camera_pivot: Node3D = $CameraPivot
## The actual camera, parented to CameraPivot.
@onready var _camera: Camera3D = $CameraPivot/Camera3D

var _turn_manager: TurnManager
var _units_root: Node3D
## Current rotation target in degrees; the pivot tweens toward this.
var _target_camera_rotation: float = -45.0
## Current zoom multiplier; 1.0 = default, lower = closer.
var _zoom_level: float = 1.0
## Holds the active rotation tween so we can interrupt it on rapid presses.
var _camera_tween: Tween = null

# ── Left-mouse drag state ─────────────────────────────────────────────────────

var _lmb_held: bool = false
## Screen position where LMB was first pressed this gesture.
var _lmb_press_pos: Vector2 = Vector2.ZERO
## True once the cursor has moved past the drag threshold while LMB is held.
var _lmb_is_dragging: bool = false
## Live camera pitch (X rotation) adjusted by vertical drag.
var _camera_pitch: float = -52.0

## Pixels of movement before a press becomes a drag (suppresses tile selection).
const LMB_DRAG_THRESHOLD: float = 5.0
## Yaw degrees per pixel of horizontal drag.
const CAMERA_DRAG_YAW_SENSITIVITY: float = 0.40
## Pitch degrees per pixel of vertical drag (inverted: drag up = look more horizontal).
const CAMERA_DRAG_PITCH_SENSITIVITY: float = 0.25
const CAMERA_PITCH_MIN: float = -78.0  ## Most top-down
const CAMERA_PITCH_MAX: float = -18.0  ## Most horizontal

const CAMERA_DISTANCE: float = 10.0
const CAMERA_HEIGHT: float = 14.0
const CAMERA_PITCH_DEG: float = -52.0  ## Default starting pitch
## Degrees per Q/E press.
const CAMERA_ROTATE_STEP: float = 45.0
## Seconds to tween a rotation snap.
const CAMERA_ROTATE_DURATION: float = 0.20
const CAMERA_ZOOM_MIN: float = 0.40
const CAMERA_ZOOM_MAX: float = 2.40
## Zoom change per scroll tick.
const CAMERA_ZOOM_STEP: float = 0.14

# ── UI ────────────────────────────────────────────────────────────────────────

var _hud_layer: CanvasLayer
var _unit_info_panel: UnitInfoPanel
var _action_menu: ActionMenu
var _turn_order_bar: TurnOrderBar
var _status_label: Label
var _pause_menu: Control

## True while the pause menu is open; suppresses all battle input.
var _is_paused: bool = false

# ── Turn State ────────────────────────────────────────────────────────────────

var _active_unit: Unit = null
## Ability currently being targeted (action or innate attack).
var _pending_ability: AbilityData = null
## Tiles highlighted for the current move/target selection.
var _highlighted_tiles: Array[Tile] = []

# ── Hover state ───────────────────────────────────────────────────────────────

var _hovered_tile: Tile = null

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Environment, camera, and map are already in the scene tree via battle_scene.tscn.
	# Just apply initial camera state and centre on the loaded map.
	_init_camera()
	_centre_camera_on_map()
	# TurnManager must exist before _build_units() so _spawn_unit_from_dict()
	# can register each unit immediately after spawning it.
	_turn_manager = TurnManager.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_build_units()
	_build_hud()
	_connect_signals()
	_start_battle()

func _unhandled_input(event: InputEvent) -> void:
	# ── Camera controls (always active) ──────────────────────────────────────

	# Mac trackpad: two-finger scroll → zoom.
	# delta.y is negative when swiping up (zoom in) and positive swiping down.
	if event is InputEventPanGesture:
		_zoom_level = clampf(
			_zoom_level + event.delta.y * 0.005,
			CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX
		)
		_apply_camera_transform()
		return

	# Mac trackpad: pinch gesture → zoom.
	# factor > 1 means fingers spreading apart (zoom in).
	if event is InputEventMagnifyGesture:
		_zoom_level = clampf(
			_zoom_level / event.factor,
			CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX
		)
		_apply_camera_transform()
		return

	# Physical mouse wheel (non-trackpad) — only on the press event to avoid
	# firing twice (Godot sends both a pressed and released event per notch).
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(-1)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(1)
				return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_rotate_camera(-1)
				return
			KEY_E:
				_rotate_camera(1)
				return
			KEY_ESCAPE:
				if _is_paused:
					_pause_menu.close_menu()
				elif _phase == BattlePhase.PLAYER_SELECTING_MOVE \
						or _phase == BattlePhase.PLAYER_SELECTING_TARGET:
					_handle_cancel()
				elif _phase != BattlePhase.BATTLE_WON \
						and _phase != BattlePhase.BATTLE_LOST \
						and _phase != BattlePhase.NONE:
					_is_paused = true
					_pause_menu.open_menu()
				return

	# Block all further input while paused.
	if _is_paused:
		return

	# ── Mouse button handling ─────────────────────────────────────────────────
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_lmb_held = true
					_lmb_press_pos = event.position
					_lmb_is_dragging = false
				else:
					if _lmb_held and not _lmb_is_dragging:
						# Short click with no drag → tile selection.
						var tile := _raycast_tile(event.position)
						if tile:
							_handle_tile_left_click(tile)
					_lmb_held = false
					_lmb_is_dragging = false

			MOUSE_BUTTON_RIGHT:
				# Right-click always cancels, no drag detection needed.
				if event.pressed:
					_handle_cancel()

	# ── Mouse motion ──────────────────────────────────────────────────────────
	elif event is InputEventMouseMotion:
		if _lmb_held:
			if not _lmb_is_dragging:
				if event.position.distance_to(_lmb_press_pos) > LMB_DRAG_THRESHOLD:
					_lmb_is_dragging = true

			if _lmb_is_dragging:
				# Horizontal drag → yaw (no tween for live feel).
				_target_camera_rotation += event.relative.x * CAMERA_DRAG_YAW_SENSITIVITY
				_camera_pivot.rotation_degrees.y = _target_camera_rotation
				# Vertical drag → pitch (drag up = more horizontal view).
				_camera_pitch = clampf(
					_camera_pitch - event.relative.y * CAMERA_DRAG_PITCH_SENSITIVITY,
					CAMERA_PITCH_MIN, CAMERA_PITCH_MAX
				)
				_apply_camera_transform()
				return  # Skip tile hover while rotating.

		_handle_tile_hover(_raycast_tile(event.position))

# ─────────────────────────────────────────────────────────────────────────────
# Scene Construction
# ─────────────────────────────────────────────────────────────────────────────

## Applies the starting camera rotation and position from the scene values.
## Called once in _ready() after @onready refs are resolved.
func _init_camera() -> void:
	_camera_pivot.rotation_degrees.y = _target_camera_rotation
	_apply_camera_transform()

func _build_units() -> void:
	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)

	# Load job and ability resources at runtime.
	var warrior_job: JobData = load("res://resources/jobs/warrior.tres")
	var mage_job: JobData = load("res://resources/jobs/black_mage.tres")
	var archer_job: JobData = load("res://resources/jobs/archer.tres")
	var attack_ability: AbilityData = load("res://resources/abilities/attack.tres")
	var aim_ability: AbilityData = load("res://resources/abilities/aim.tres")
	var counter_ability: AbilityData = load("res://resources/abilities/counter.tres")
	var move_plus: AbilityData = load("res://resources/abilities/move_plus_one.tres")

	# Player party (bottom of map)
	var player_defs: Array[Dictionary] = [
		{
			"name": "Fighter1", "job": warrior_job, "faction": GameConstants.FACTION.PLAYER,
			"base_hp": 120, "base_mp": 30, "base_speed": 10,
			"phys_atk": 14, "phys_def": 10, "mag_atk": 8, "mag_def": 8,
			"action": null, "reaction": counter_ability, "support": null,
			"movement": move_plus, "tile": Vector2i(1, 1),
		},
		{
			"name": "Fighter2", "job": mage_job, "faction": GameConstants.FACTION.PLAYER,
			"base_hp": 80, "base_mp": 80, "base_speed": 11,
			"phys_atk": 7, "phys_def": 6, "mag_atk": 16, "mag_def": 10,			
			"movement": null, "tile": Vector2i(2, 1),
		},
		{
			"name": "Fighter3", "job": archer_job, "faction": GameConstants.FACTION.PLAYER,
			"base_hp": 100, "base_mp": 20, "base_speed": 9,
			"phys_atk": 12, "phys_def": 9, "mag_atk": 8, "mag_def": 9,
			"action": aim_ability, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(3, 1),
		},
	]

	# Enemy party (top of map)
	var enemy_defs: Array[Dictionary] = [
		{
			"name": "Goblin", "job": warrior_job, "faction": GameConstants.FACTION.ENEMY,
			"base_hp": 90, "base_mp": 10, "base_speed": 9,
			"phys_atk": 11, "phys_def": 8, "mag_atk": 5, "mag_def": 6,
			"action": null, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(6, 8),
		},
		{
			"name": "Wizard", "job": mage_job, "faction": GameConstants.FACTION.ENEMY,
			"base_hp": 70, "base_mp": 60, "base_speed": 12,
			"phys_atk": 6, "phys_def": 5, "mag_atk": 14, "mag_def": 9,
			"movement": null, "tile": Vector2i(7, 8),
		},
		{
			"name": "Archer", "job": archer_job, "faction": GameConstants.FACTION.ENEMY,
			"base_hp": 85, "base_mp": 15, "base_speed": 10,
			"phys_atk": 10, "phys_def": 8, "mag_atk": 6, "mag_def": 8,
			"action": aim_ability, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(5, 9),
		},
	]

	for def in player_defs + enemy_defs:
		_spawn_unit_from_dict(def)

func _spawn_unit_from_dict(def: Dictionary) -> void:
	var unit := Unit.new()
	_units_root.add_child(unit)

	# Build a UnitDefinition on the fly so Unit.setup() works normally.
	var unit_def := UnitDefinition.new()
	unit_def.unit_name = def["name"]
	unit_def.starting_job = def["job"]
	unit_def.faction = def["faction"]
	unit_def.base_hp = def["base_hp"]
	unit_def.base_mp = def["base_mp"]
	unit_def.base_speed = def["base_speed"]
	unit_def.base_physical_attack = def["phys_atk"]
	unit_def.base_physical_defense = def["phys_def"]
	unit_def.base_magical_attack = def["mag_atk"]
	unit_def.base_magical_defense = def["mag_def"]
	unit_def.equipped_action_ability = def.get("action")
	unit_def.equipped_reaction_ability = def.get("reaction")
	unit_def.equipped_support_ability = def.get("support")
	unit_def.equipped_movement_ability = def.get("movement")
	unit.setup(unit_def)

	var tile_pos: Vector2i = def["tile"]
	var tile := _battle_map.get_tile(tile_pos)
	if tile:
		_battle_map.place_unit(unit, tile)

	_turn_manager.register_unit(unit)

func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HUD"
	add_child(_hud_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Layout containers must not eat mouse events — only interactive widgets do.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(margin)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var screen_vbox := VBoxContainer.new()
	screen_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(screen_vbox)

	# ── Top row: turn order bar (centred) ───────────────────────────────────
	var top_row := HBoxContainer.new()
	top_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(top_row)

	var top_left := Control.new()
	top_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_left)

	_turn_order_bar = TurnOrderBar.new()
	top_row.add_child(_turn_order_bar)

	var top_right := Control.new()
	top_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_right)

	# ── Middle: empty space ───────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(spacer)

	# ── Status label (above bottom row) ──────────────────────────────────────
	var status_row := HBoxContainer.new()
	status_row.size_flags_vertical = Control.SIZE_SHRINK_END
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(status_row)

	var status_left := Control.new()
	status_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(status_left)

	var status_panel := PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status_style := StyleBoxFlat.new()
	status_style.bg_color = Color(0.06, 0.07, 0.12, 0.85)
	status_style.border_color = Color(0.22, 0.27, 0.44)
	status_style.set_border_width_all(1)
	status_style.set_corner_radius_all(6)
	status_style.content_margin_left   = 20.0
	status_style.content_margin_right  = 20.0
	status_style.content_margin_top    = 6.0
	status_style.content_margin_bottom = 6.0
	status_panel.add_theme_stylebox_override("panel", status_style)
	status_row.add_child(status_panel)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.97))
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(_status_label)

	var status_right := Control.new()
	status_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row.add_child(status_right)

	# ── Bottom row: unit info (left) + action menu (right) ───────────────────
	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(bottom_row)

	_unit_info_panel = UnitInfoPanel.new()
	bottom_row.add_child(_unit_info_panel)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(mid_spacer)

	_action_menu = ActionMenu.new()
	bottom_row.add_child(_action_menu)

	# Pause menu — sits on top of everything in the HUD layer.
	var pause_scene := load("res://scenes/ui/pause_menu.tscn") as PackedScene
	_pause_menu = pause_scene.instantiate()
	_hud_layer.add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_on_pause_resume)

func _connect_signals() -> void:
	_action_menu.move_pressed.connect(_on_action_menu_move)
	_action_menu.attack_pressed.connect(_on_action_menu_attack)
	_action_menu.ability_pressed.connect(_on_action_menu_ability)
	_action_menu.wait_pressed.connect(_on_action_menu_wait)
	GameEvents.unit_died.connect(_on_unit_died)

# ─────────────────────────────────────────────────────────────────────────────
# Battle Flow
# ─────────────────────────────────────────────────────────────────────────────

func _start_battle() -> void:
	_set_status("Battle start!")
	_advance_to_next_turn()

func _advance_to_next_turn() -> void:
	if _check_battle_end():
		return

	var next_unit := _turn_manager.get_next_acting_unit()
	if next_unit == null:
		return

	_active_unit = next_unit
	_refresh_turn_order_bar()
	GameEvents.turn_started.emit(next_unit)

	if next_unit.faction == GameConstants.FACTION.PLAYER:
		_start_player_turn(next_unit)
	else:
		_start_ai_turn(next_unit)

func _start_player_turn(unit: Unit) -> void:
	_change_phase(BattlePhase.PLAYER_SELECTING)
	_unit_info_panel.display_unit(unit)
	_highlight_unit_tile(unit)
	_action_menu.show_for_unit(unit)
	_set_status("%s — choose an action." % unit.unit_name)

func _start_ai_turn(unit: Unit) -> void:
	_change_phase(BattlePhase.AI_TURN)
	_clear_highlights()
	_set_status("%s is acting…" % unit.unit_name)
	_unit_info_panel.display_unit(unit)

	AIController.take_turn(unit, _battle_map)

	await get_tree().create_timer(0.5).timeout
	_end_current_turn()

func _end_current_turn() -> void:
	_clear_highlights()
	_action_menu.hide_menu()
	_turn_manager.end_unit_turn(_active_unit)
	_active_unit = null
	_pending_ability = null
	_advance_to_next_turn()

func _check_battle_end() -> bool:
	var player_units := _battle_map.get_units_by_faction(GameConstants.FACTION.PLAYER)
	var enemy_units := _battle_map.get_units_by_faction(GameConstants.FACTION.ENEMY)

	if player_units.is_empty():
		_change_phase(BattlePhase.BATTLE_LOST)
		_set_status("Defeat!  All allies have fallen.")
		return true
	if enemy_units.is_empty():
		_change_phase(BattlePhase.BATTLE_WON)
		_set_status("Victory!  All enemies have been defeated.")
		return true
	return false

# ─────────────────────────────────────────────────────────────────────────────
# Input Handling
# ─────────────────────────────────────────────────────────────────────────────

func _handle_tile_left_click(tile: Tile) -> void:
	match _phase:
		BattlePhase.PLAYER_SELECTING_MOVE:
			_confirm_move(tile)
		BattlePhase.PLAYER_SELECTING_TARGET:
			_confirm_target(tile)
		BattlePhase.PLAYER_SELECTING:
			# Click on own unit re-opens the action menu.
			if tile.occupant != null and tile.occupant == _active_unit:
				_action_menu.show_for_unit(_active_unit)
		_:
			pass

func _handle_cancel() -> void:
	match _phase:
		BattlePhase.PLAYER_SELECTING_MOVE, BattlePhase.PLAYER_SELECTING_TARGET:
			_clear_highlights()
			_change_phase(BattlePhase.PLAYER_SELECTING)
			_action_menu.show_for_unit(_active_unit)
			_highlight_unit_tile(_active_unit)
			_set_status("%s — choose an action." % _active_unit.unit_name)
		_:
			pass

func _handle_tile_hover(tile: Tile) -> void:
	if tile == _hovered_tile:
		return

	# Restore the tile we just left to whatever its base highlight should be.
	if _hovered_tile != null:
		_restore_tile_base_highlight(_hovered_tile)

	_hovered_tile = tile

	if tile != null:
		_apply_hover_highlight(tile)

## Show the appropriate hover color for `tile` based on the current phase.
func _apply_hover_highlight(tile: Tile) -> void:
	# During move selection: green if reachable and empty, red otherwise.
	if _phase == BattlePhase.PLAYER_SELECTING_MOVE:
		var is_valid_dest := _highlighted_tiles.has(tile) \
			and (tile.occupant == null or tile.occupant == _active_unit)
		if is_valid_dest:
			tile.set_highlight(GameConstants.HIGHLIGHT_HOVER_VALID)
		elif tile != (_active_unit.current_tile if _active_unit else null):
			tile.set_highlight(GameConstants.HIGHLIGHT_HOVER_INVALID)
		return

	# During target selection: only hover non-highlighted tiles with a generic tint.
	if _phase == BattlePhase.PLAYER_SELECTING_TARGET:
		if not _highlighted_tiles.has(tile):
			tile.set_highlight(GameConstants.HIGHLIGHT_HOVER)
		return

	# All other phases: generic yellow hover on any non-highlighted, non-selected tile.
	var is_selected := _active_unit != null and tile == _active_unit.current_tile
	if not is_selected and not _highlighted_tiles.has(tile):
		tile.set_highlight(GameConstants.HIGHLIGHT_HOVER)

## Restore `tile` to the highlight it should show when not hovered.
func _restore_tile_base_highlight(tile: Tile) -> void:
	# Always keep the selected-unit tile green.
	if _active_unit != null and tile == _active_unit.current_tile:
		tile.set_highlight(GameConstants.HIGHLIGHT_SELECTED)
		return

	if _highlighted_tiles.has(tile):
		match _phase:
			BattlePhase.PLAYER_SELECTING_MOVE:
				tile.set_highlight(GameConstants.HIGHLIGHT_MOVE)
			BattlePhase.PLAYER_SELECTING_TARGET:
				tile.set_highlight(GameConstants.HIGHLIGHT_ATTACK)
			_:
				tile.set_highlight(GameConstants.HIGHLIGHT_NONE)
	else:
		tile.set_highlight(GameConstants.HIGHLIGHT_NONE)

# ── Action Menu Callbacks ─────────────────────────────────────────────────────

func _on_action_menu_move() -> void:
	if _active_unit == null or not _active_unit.can_move():
		return
	_clear_highlights()
	_change_phase(BattlePhase.PLAYER_SELECTING_MOVE)
	var reachable := PathFinder.get_reachable_tiles(
		_active_unit.current_tile, _active_unit, _battle_map
	)
	_highlighted_tiles = reachable
	_battle_map.highlight_tiles(reachable, GameConstants.HIGHLIGHT_MOVE)
	_highlight_unit_tile(_active_unit)
	_set_status("Select a destination.")

func _on_action_menu_attack() -> void:
	if _active_unit == null or not _active_unit.can_act():
		return
	var innate_attack := _get_innate_attack(_active_unit)
	if innate_attack == null:
		return
	_begin_target_selection(innate_attack)

func _on_action_menu_ability(ability: AbilityData) -> void:
	if _active_unit == null or not _active_unit.can_act():
		return
	_begin_target_selection(ability)

func _on_action_menu_wait() -> void:
	_end_current_turn()

# ── Move Confirmation ──────────────────────────────────────────────────────────

func _confirm_move(destination: Tile) -> void:
	if not _highlighted_tiles.has(destination):
		return
	if destination.occupant != null:
		return  # Occupied
	_clear_highlights()
	var from_tile := _active_unit.current_tile
	_battle_map.place_unit(_active_unit, destination)
	_active_unit.has_moved = true
	GameEvents.unit_moved.emit(_active_unit, from_tile, destination)
	_change_phase(BattlePhase.PLAYER_SELECTING)
	_action_menu.show_for_unit(_active_unit)
	_highlight_unit_tile(_active_unit)
	_set_status("%s moved.  Choose an action." % _active_unit.unit_name)
	GameEvents.active_unit_state_changed.emit(_active_unit)

# ── Ability Target Selection ───────────────────────────────────────────────────

func _begin_target_selection(ability: AbilityData) -> void:
	_pending_ability = ability
	_clear_highlights()
	_change_phase(BattlePhase.PLAYER_SELECTING_TARGET)

	var origin := _active_unit.current_tile.grid_position
	var candidate_tiles := _battle_map.get_tiles_in_range(origin, ability.range)
	# Filter to tiles that have a valid target for this ability.
	var target_tiles: Array[Tile] = []
	for tile: Tile in candidate_tiles:
		if _tile_is_valid_target(tile, ability):
			target_tiles.append(tile)

	_highlighted_tiles = target_tiles
	_battle_map.highlight_tiles(target_tiles, GameConstants.HIGHLIGHT_ATTACK)
	_highlight_unit_tile(_active_unit)
	_set_status("Select a target for %s." % ability.ability_name)

func _confirm_target(tile: Tile) -> void:
	if not _highlighted_tiles.has(tile):
		return
	if _pending_ability == null:
		return

	var targets: Array[Unit] = _collect_targets(tile, _pending_ability)
	if targets.is_empty():
		return

	_clear_highlights()
	_change_phase(BattlePhase.EXECUTING_ACTION)
	AbilityExecutor.execute(_active_unit, _pending_ability, targets)
	_active_unit.has_acted = true

	await get_tree().create_timer(0.3).timeout
	_pending_ability = null

	# Active unit might have died from a counter-attack during the wait.
	if not is_instance_valid(_active_unit) or _active_unit.is_dead:
		_active_unit = null
		_advance_to_next_turn()
		return

	if _active_unit.has_moved and _active_unit.has_acted:
		_end_current_turn()
	else:
		_change_phase(BattlePhase.PLAYER_SELECTING)
		_action_menu.show_for_unit(_active_unit)
		_highlight_unit_tile(_active_unit)
		_set_status("%s — choose an action." % _active_unit.unit_name)
		GameEvents.active_unit_state_changed.emit(_active_unit)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _tile_is_valid_target(tile: Tile, ability: AbilityData) -> bool:
	if tile.occupant == null:
		return false
	var occupant: Unit = tile.occupant
	if occupant.is_dead:
		return false
	match ability.target_type:
		AbilityData.TargetType.SINGLE_ENEMY:
			return occupant.faction != _active_unit.faction
		AbilityData.TargetType.SINGLE_ALLY:
			return occupant.faction == _active_unit.faction and occupant != _active_unit
		AbilityData.TargetType.SELF:
			return occupant == _active_unit
		AbilityData.TargetType.AOE:
			return occupant.faction != _active_unit.faction
		_:
			return false

func _collect_targets(tile: Tile, ability: AbilityData) -> Array[Unit]:
	var targets: Array[Unit] = []
	if ability.area == 0:
		if tile.occupant != null and not tile.occupant.is_dead:
			targets.append(tile.occupant)
	else:
		for candidate_tile in _battle_map.get_tiles_in_range(
				tile.grid_position, ability.area, true):
			if candidate_tile.occupant != null and not candidate_tile.occupant.is_dead:
				if candidate_tile.occupant.faction != _active_unit.faction:
					targets.append(candidate_tile.occupant)
	return targets

func _get_innate_attack(unit: Unit) -> AbilityData:
	if unit.current_job != null and not unit.current_job.innate_abilities.is_empty():
		return unit.current_job.innate_abilities[0]
	return null

func _highlight_unit_tile(unit: Unit) -> void:
	if unit.current_tile != null:
		unit.current_tile.set_highlight(GameConstants.HIGHLIGHT_SELECTED)

func _clear_highlights() -> void:
	_battle_map.clear_all_highlights()
	_highlighted_tiles.clear()
	_hovered_tile = null  # Reset so the next MouseMotion event re-evaluates cleanly.

func _change_phase(new_phase: BattlePhase) -> void:
	_phase = new_phase
	GameEvents.battle_phase_changed.emit(new_phase)

func _set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text

func _refresh_turn_order_bar() -> void:
	var preview := _turn_manager.preview_turn_order(GameConstants.TURN_PREVIEW_COUNT)
	_turn_order_bar.refresh(preview)

# ── Camera ────────────────────────────────────────────────────────────────────

## Snap-rotate the camera by CAMERA_ROTATE_STEP degrees.
## Rapid presses accumulate: each press moves the target further and restarts
## the tween so the camera sweeps to the new destination.
func _rotate_camera(direction: int) -> void:
	_target_camera_rotation += direction * CAMERA_ROTATE_STEP
	if is_instance_valid(_camera_tween):
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_tween.tween_property(
		_camera_pivot, "rotation_degrees:y",
		_target_camera_rotation, CAMERA_ROTATE_DURATION
	)

## Zoom in (direction = -1) or out (direction = +1) by one step.
func _zoom_camera(direction: int) -> void:
	_zoom_level = clampf(
		_zoom_level + direction * CAMERA_ZOOM_STEP,
		CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX
	)
	_apply_camera_transform()

## Moves the camera pivot to sit above the centre of the loaded map.
func _centre_camera_on_map() -> void:
	if not is_instance_valid(_battle_map) or not is_instance_valid(_camera_pivot):
		return
	var w: float = float(_battle_map.get_width() - 1) * GameConstants.TILE_SIZE
	var d: float = float(_battle_map.get_depth() - 1) * GameConstants.TILE_SIZE
	_camera_pivot.position = Vector3(w * 0.5, 0.0, d * 0.5)

## Re-positions the camera arm according to current zoom level and angle.
func _apply_camera_transform() -> void:
	if not is_instance_valid(_camera):
		return
	_camera.position = Vector3(
		0.0,
		CAMERA_HEIGHT * _zoom_level,
		CAMERA_DISTANCE * _zoom_level
	)
	_camera.rotation_degrees = Vector3(_camera_pitch, 0.0, 0.0)

# ── Raycasting ────────────────────────────────────────────────────────────────

func _raycast_tile(screen_pos: Vector2) -> Tile:
	if not is_instance_valid(_camera):
		return null
	var from := _camera.project_ray_origin(screen_pos)
	var to := from + _camera.project_ray_normal(screen_pos) * 500.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = GameConstants.TILE_COLLISION_LAYER
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Object = result["collider"]
	if collider is Tile:
		return collider as Tile
	if collider is CollisionShape3D and collider.get_parent() is Tile:
		return collider.get_parent() as Tile
	return null

# ── Event Handlers ────────────────────────────────────────────────────────────

func _on_pause_resume() -> void:
	_is_paused = false

func _on_unit_died(unit: Unit) -> void:
	_turn_manager.unregister_unit(unit)
	_check_battle_end()
