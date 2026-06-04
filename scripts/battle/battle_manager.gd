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

# ── Child Systems ─────────────────────────────────────────────────────────────

var _battle_map: BattleMap
var _turn_manager: TurnManager
var _units_root: Node3D

# ── Camera ────────────────────────────────────────────────────────────────────

var _camera_pivot: Node3D
var _camera: Camera3D
var _camera_y_rotation: float = -45.0  # degrees; starting angle

const MAP_WIDTH: int = 10
const MAP_DEPTH: int = 10
const CAMERA_DISTANCE: float = 10.0
const CAMERA_HEIGHT: float = 14.0
const CAMERA_PITCH_DEG: float = -52.0

# ── UI ────────────────────────────────────────────────────────────────────────

var _hud_layer: CanvasLayer
var _unit_info_panel: UnitInfoPanel
var _action_menu: ActionMenu
var _turn_order_bar: TurnOrderBar
var _status_label: Label

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
	_build_environment()
	_build_camera()
	_build_map()
	# TurnManager must exist before _build_units() so _spawn_unit_from_dict()
	# can register each unit immediately after spawning it.
	_turn_manager = TurnManager.new()
	_turn_manager.name = "TurnManager"
	add_child(_turn_manager)
	_build_units()
	_build_hud()
	_connect_signals()
	_start_battle()

func _process(delta: float) -> void:
	_handle_camera_rotation_input(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var tile := _raycast_tile(event.position)
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if tile:
					_handle_tile_left_click(tile)
			MOUSE_BUTTON_RIGHT:
				_handle_right_click()

	elif event is InputEventMouseMotion:
		var tile := _raycast_tile(event.position)
		_handle_tile_hover(tile)

# ─────────────────────────────────────────────────────────────────────────────
# Scene Construction
# ─────────────────────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.35, 0.45)
	env.ambient_light_energy = 0.6
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	add_child(_camera_pivot)
	_camera_pivot.position = Vector3(
		(MAP_WIDTH - 1) * 0.5,
		0.0,
		(MAP_DEPTH - 1) * 0.5
	)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera_pivot.add_child(_camera)
	_camera.fov = 40.0
	_apply_camera_rotation()

func _build_map() -> void:
	_battle_map = BattleMap.new()
	_battle_map.name = "BattleMap"
	add_child(_battle_map)
	_battle_map.generate_test_map(MAP_WIDTH, MAP_DEPTH)

func _build_units() -> void:
	_units_root = Node3D.new()
	_units_root.name = "Units"
	add_child(_units_root)

	# Load job and ability resources at runtime.
	var warrior_job: JobData = load("res://resources/jobs/warrior.tres")
	var mage_job: JobData = load("res://resources/jobs/black_mage.tres")
	var archer_job: JobData = load("res://resources/jobs/archer.tres")
	var attack_ability: AbilityData = load("res://resources/abilities/attack.tres")
	var fire_ability: AbilityData = load("res://resources/abilities/fire.tres")
	var aim_ability: AbilityData = load("res://resources/abilities/aim.tres")
	var counter_ability: AbilityData = load("res://resources/abilities/counter.tres")
	var move_plus: AbilityData = load("res://resources/abilities/move_plus_one.tres")

	# Player party (bottom of map)
	var player_defs: Array[Dictionary] = [
		{
			"name": "Ramza", "job": warrior_job, "faction": GameConstants.FACTION_PLAYER,
			"base_hp": 120, "base_mp": 30, "base_speed": 10,
			"phys_atk": 14, "phys_def": 10, "mag_atk": 8, "mag_def": 8,
			"action": null, "reaction": counter_ability, "support": null,
			"movement": move_plus, "tile": Vector2i(1, 1),
		},
		{
			"name": "Alma", "job": mage_job, "faction": GameConstants.FACTION_PLAYER,
			"base_hp": 80, "base_mp": 80, "base_speed": 11,
			"phys_atk": 7, "phys_def": 6, "mag_atk": 16, "mag_def": 10,
			"action": fire_ability, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(2, 1),
		},
		{
			"name": "Agrias", "job": archer_job, "faction": GameConstants.FACTION_PLAYER,
			"base_hp": 100, "base_mp": 20, "base_speed": 9,
			"phys_atk": 12, "phys_def": 9, "mag_atk": 8, "mag_def": 9,
			"action": aim_ability, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(3, 1),
		},
	]

	# Enemy party (top of map)
	var enemy_defs: Array[Dictionary] = [
		{
			"name": "Goblin", "job": warrior_job, "faction": GameConstants.FACTION_ENEMY,
			"base_hp": 90, "base_mp": 10, "base_speed": 9,
			"phys_atk": 11, "phys_def": 8, "mag_atk": 5, "mag_def": 6,
			"action": null, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(6, 8),
		},
		{
			"name": "Wizard", "job": mage_job, "faction": GameConstants.FACTION_ENEMY,
			"base_hp": 70, "base_mp": 60, "base_speed": 12,
			"phys_atk": 6, "phys_def": 5, "mag_atk": 14, "mag_def": 9,
			"action": fire_ability, "reaction": null, "support": null,
			"movement": null, "tile": Vector2i(7, 8),
		},
		{
			"name": "Archer", "job": archer_job, "faction": GameConstants.FACTION_ENEMY,
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

	# Top bar: turn order
	var top_bar := HBoxContainer.new()
	top_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(top_bar)

	_turn_order_bar = TurnOrderBar.new()
	top_bar.add_child(_turn_order_bar)

	# Spacer — pure layout, must be fully transparent to input
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(spacer)

	# Bottom row: unit info + action menu
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

	# Status label (bottom, full width) — display-only, no mouse interaction
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_vbox.add_child(_status_label)

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

	if next_unit.faction == GameConstants.FACTION_PLAYER:
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
	var player_units := _battle_map.get_units_by_faction(GameConstants.FACTION_PLAYER)
	var enemy_units := _battle_map.get_units_by_faction(GameConstants.FACTION_ENEMY)

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

func _handle_right_click() -> void:
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
	if _hovered_tile != null:
		# Restore the highlight that was showing before the hover.
		if _highlighted_tiles.has(_hovered_tile):
			# The tile was already highlighted — keep its highlight.
			pass
		else:
			_hovered_tile.set_highlight(GameConstants.HIGHLIGHT_NONE)
	_hovered_tile = tile
	if tile != null and not _highlighted_tiles.has(tile):
		tile.set_highlight(GameConstants.HIGHLIGHT_HOVER)

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

func _handle_camera_rotation_input(delta: float) -> void:
	var rotate_dir := 0.0
	if Input.is_action_pressed("ui_page_up") or Input.is_key_pressed(KEY_Q):
		rotate_dir = -1.0
	elif Input.is_action_pressed("ui_page_down") or Input.is_key_pressed(KEY_E):
		rotate_dir = 1.0
	if rotate_dir != 0.0:
		_camera_y_rotation += rotate_dir * 90.0 * delta
		_apply_camera_rotation()

func _apply_camera_rotation() -> void:
	if not is_instance_valid(_camera_pivot):
		return
	_camera_pivot.rotation_degrees.y = _camera_y_rotation
	_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	_camera.rotation_degrees = Vector3(CAMERA_PITCH_DEG, 0.0, 0.0)

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

func _on_unit_died(unit: Unit) -> void:
	_turn_manager.unregister_unit(unit)
	_check_battle_end()
