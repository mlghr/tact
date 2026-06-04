## Represents a single combatant on the battlefield.
## Contains stats (computed from base + job multipliers + passive bonuses),
## ability loadout, and the placeholder 3-D visual.
class_name Unit
extends Node3D

# ── Signals ───────────────────────────────────────────────────────────────────

signal hp_changed(new_hp: int, max_hp: int)
signal mp_changed(new_mp: int, max_mp: int)
signal died()

# ── Identity ──────────────────────────────────────────────────────────────────

var unit_name: String = "Unknown"
## GameConstants.FACTION_* value.
var faction: int = GameConstants.FACTION_PLAYER
var definition: UnitDefinition = null
var current_job: JobData = null

# ── Base Stats (set from UnitDefinition, before job multipliers) ──────────────

var base_hp: int = 100
var base_mp: int = 50
var base_speed: int = 10
var base_physical_attack: int = 10
var base_physical_defense: int = 10
var base_magical_attack: int = 10
var base_magical_defense: int = 10

# ── Computed/Effective Stats (call recompute_stats() after any change) ────────

var max_hp: int = 100
var max_mp: int = 50
var speed: int = 10
var physical_attack: int = 10
var physical_defense: int = 10
var magical_attack: int = 10
var magical_defense: int = 10
var move_range: int = 3
var jump_height: int = 3

# ── Current Status ────────────────────────────────────────────────────────────

var current_hp: int = 100
var current_mp: int = 50
## Charge Time: advances each turn cycle; reaching CT_THRESHOLD grants a turn.
var ct: int = 0
var is_dead: bool = false

# ── Abilities ─────────────────────────────────────────────────────────────────

## All abilities this unit has unlocked across all jobs.
var learned_abilities: Array[AbilityData] = []
## The single active ability set usable on this unit's turn.
var equipped_action: AbilityData = null
## Fires automatically in response to certain events.
var equipped_reaction: AbilityData = null
## Always-active passive bonus.
var equipped_support: AbilityData = null
## Passive that alters movement rules.
var equipped_movement: AbilityData = null

# ── Turn State ────────────────────────────────────────────────────────────────

var has_moved: bool = false
var has_acted: bool = false

# ── Map Reference ─────────────────────────────────────────────────────────────

## The Tile this unit is currently standing on.
var current_tile: Tile = null

# ── Visual Nodes ──────────────────────────────────────────────────────────────

var _body_mesh: MeshInstance3D
var _name_label: Label3D
var _faction_indicator: MeshInstance3D

# ── Initialization ────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_visual()

## Populate this unit from a UnitDefinition resource and add it to the scene.
func setup(unit_def: UnitDefinition) -> void:
	definition = unit_def
	unit_name = unit_def.unit_name
	faction = unit_def.faction
	current_job = unit_def.starting_job

	base_hp = unit_def.base_hp
	base_mp = unit_def.base_mp
	base_speed = unit_def.base_speed
	base_physical_attack = unit_def.base_physical_attack
	base_physical_defense = unit_def.base_physical_defense
	base_magical_attack = unit_def.base_magical_attack
	base_magical_defense = unit_def.base_magical_defense

	equipped_action = unit_def.equipped_action_ability
	equipped_reaction = unit_def.equipped_reaction_ability
	equipped_support = unit_def.equipped_support_ability
	equipped_movement = unit_def.equipped_movement_ability

	recompute_stats()
	current_hp = max_hp
	current_mp = max_mp

	# Seed CT slightly so not everyone moves at once (based on speed).
	ct = randi_range(0, 20)

	name = unit_name.replace(" ", "_")
	if is_instance_valid(_name_label):
		_name_label.text = unit_name
	_refresh_faction_color()

# ── Stat Computation ──────────────────────────────────────────────────────────

## Recompute all effective stats from base + job multipliers + support passives.
## Call whenever the job or equipped passives change.
func recompute_stats() -> void:
	if current_job == null:
		max_hp = base_hp
		max_mp = base_mp
		speed = base_speed
		physical_attack = base_physical_attack
		physical_defense = base_physical_defense
		magical_attack = base_magical_attack
		magical_defense = base_magical_defense
		move_range = 3
		jump_height = 3
	else:
		max_hp = int(base_hp * current_job.hp_multiplier)
		max_mp = int(base_mp * current_job.mp_multiplier)
		speed = int(base_speed * current_job.speed_multiplier)
		physical_attack = int(base_physical_attack * current_job.physical_attack_multiplier)
		physical_defense = int(base_physical_defense * current_job.physical_defense_multiplier)
		magical_attack = int(base_magical_attack * current_job.magical_attack_multiplier)
		magical_defense = int(base_magical_defense * current_job.magical_defense_multiplier)
		move_range = current_job.base_move
		jump_height = current_job.base_jump

	_apply_support_passive()
	_apply_movement_passive()

# ── HP / MP Modification ──────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	if current_hp <= 0 and not is_dead:
		_die()

func restore_hp(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func spend_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	mp_changed.emit(current_mp, max_mp)
	return true

func restore_mp(amount: int) -> void:
	current_mp = min(max_mp, current_mp + amount)
	mp_changed.emit(current_mp, max_mp)

# ── Turn Helpers ──────────────────────────────────────────────────────────────

func can_move() -> bool:
	return not has_moved and not is_dead

func can_act() -> bool:
	return not has_acted and not is_dead

func end_turn() -> void:
	has_moved = false
	has_acted = false

# ── Visual ────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	# Body: capsule mesh
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "BodyMesh"
	add_child(_body_mesh)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.22
	capsule.height = 0.70
	_body_mesh.mesh = capsule
	_body_mesh.position = Vector3(0.0, 0.35, 0.0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = _faction_color()
	_body_mesh.set_surface_override_material(0, body_mat)

	# Faction dot on top
	_faction_indicator = MeshInstance3D.new()
	_faction_indicator.name = "FactionIndicator"
	add_child(_faction_indicator)
	var sphere := SphereMesh.new()
	sphere.radius = 0.10
	sphere.height = 0.20
	_faction_indicator.mesh = sphere
	_faction_indicator.position = Vector3(0.0, 0.75, 0.0)
	var indicator_mat := StandardMaterial3D.new()
	indicator_mat.albedo_color = _faction_color()
	indicator_mat.emission_enabled = true
	indicator_mat.emission = _faction_color()
	_faction_indicator.set_surface_override_material(0, indicator_mat)

	# Name label (billboard so it always faces the camera)
	_name_label = Label3D.new()
	_name_label.name = "NameLabel"
	add_child(_name_label)
	_name_label.text = unit_name
	_name_label.position = Vector3(0.0, 1.05, 0.0)
	_name_label.pixel_size = 0.006
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.modulate = Color.WHITE
	_name_label.outline_modulate = Color.BLACK
	_name_label.outline_size = 6

func _faction_color() -> Color:
	match faction:
		GameConstants.FACTION_PLAYER:  return Color(0.30, 0.55, 1.0)
		GameConstants.FACTION_ENEMY:   return Color(1.0, 0.30, 0.25)
		_:                             return Color(0.55, 0.55, 0.55)

func _refresh_faction_color() -> void:
	if not is_instance_valid(_body_mesh):
		return
	var color := _faction_color()
	(_body_mesh.get_surface_override_material(0) as StandardMaterial3D).albedo_color = color
	var ind_mat := _faction_indicator.get_surface_override_material(0) as StandardMaterial3D
	ind_mat.albedo_color = color
	ind_mat.emission = color

# ── Death ─────────────────────────────────────────────────────────────────────

func _die() -> void:
	is_dead = true
	if current_tile != null:
		current_tile.occupant = null
	died.emit()
	GameEvents.unit_died.emit(self)
	# Shrink to zero then free
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.45)
	tween.tween_callback(queue_free)

# ── Private – passive application ─────────────────────────────────────────────

func _apply_support_passive() -> void:
	if equipped_support == null:
		return
	match equipped_support.effect_type:
		AbilityData.EffectType.HP_BONUS:
			max_hp = int(max_hp * equipped_support.stat_multiplier)
		AbilityData.EffectType.MP_BONUS:
			max_mp = int(max_mp * equipped_support.stat_multiplier)

func _apply_movement_passive() -> void:
	if equipped_movement == null:
		return
	match equipped_movement.effect_type:
		AbilityData.EffectType.MOVE_BONUS:
			move_range += equipped_movement.stat_bonus
		AbilityData.EffectType.JUMP_BONUS:
			jump_height += equipped_movement.stat_bonus
