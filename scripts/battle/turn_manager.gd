## Manages the Charge-Time (CT) queue.
## Each frame of the CT simulation, every living unit's CT advances by their
## Speed.  When a unit's CT reaches CT_THRESHOLD, they get their turn.
## After acting, their CT drops by CT_THRESHOLD (retaining any overflow).
class_name TurnManager
extends Node

const CT_THRESHOLD: int = GameConstants.CT_THRESHOLD

## All registered units (living and dead; dead units are skipped automatically).
var _all_units: Array[Unit] = []

## Units whose CT has already reached the threshold this cycle, sorted by
## descending CT (ties broken by Speed).  They act before more CT is simulated.
var _ready_queue: Array[Unit] = []

# ── Registration ──────────────────────────────────────────────────────────────

func register_unit(unit: Unit) -> void:
	_all_units.append(unit)

func unregister_unit(unit: Unit) -> void:
	_all_units.erase(unit)
	_ready_queue.erase(unit)

func get_active_units() -> Array[Unit]:
	var active: Array[Unit] = []
	for unit in _all_units:
		if not unit.is_dead:
			active.append(unit)
	return active

# ── Turn Resolution ───────────────────────────────────────────────────────────

## Advance CT until at least one unit is ready to act, then return that unit.
## The returned unit's CT is still ≥ CT_THRESHOLD; call end_unit_turn() after
## their actions complete.
func get_next_acting_unit() -> Unit:
	# Drain any units already queued before simulating more CT.
	_flush_dead_from_queue()
	if not _ready_queue.is_empty():
		return _ready_queue.pop_front()

	# Simulate CT advancement in batches until at least one unit is ready.
	while _ready_queue.is_empty():
		var living := get_active_units()
		if living.is_empty():
			return null

		# Advance by the minimum number of ticks until the next unit hits threshold.
		var min_ticks: int = _ticks_until_next_turn(living)
		for unit in living:
			unit.ct += unit.speed * min_ticks
			GameEvents.ct_updated.emit(unit, unit.ct)

		# Collect all units that have reached the threshold.
		for unit in living:
			if unit.ct >= CT_THRESHOLD:
				_ready_queue.append(unit)
		_sort_ready_queue()

	return _ready_queue.pop_front()

## Call after the acting unit has finished their turn.
## Drains CT_THRESHOLD from their CT (retaining overflow) and resets turn flags.
func end_unit_turn(unit: Unit) -> void:
	unit.ct -= CT_THRESHOLD
	unit.has_moved = false
	unit.has_acted = false
	GameEvents.turn_ended.emit(unit)

	# If they still have CT ≥ threshold (rare for very high-speed units),
	# re-add them to the ready queue.
	if unit.ct >= CT_THRESHOLD and not unit.is_dead:
		_ready_queue.append(unit)
		_sort_ready_queue()

# ── Turn Order Preview ────────────────────────────────────────────────────────

## Simulates future CT without modifying real state.
## Returns an ordered Array[Unit] of the next `count` acting units (may repeat).
func preview_turn_order(count: int) -> Array[Unit]:
	var living := get_active_units()
	if living.is_empty():
		return []

	# Snapshot current CTs (including any already-queued overflow).
	var sim_ct: Dictionary = {}
	for unit: Unit in living:
		sim_ct[unit] = unit.ct

	# Pre-seed with any units already waiting in the ready queue.
	var result: Array[Unit] = []
	for unit: Unit in _ready_queue:
		result.append(unit)
		if result.size() >= count:
			return result

	while result.size() < count:
		var min_ticks := _ticks_until_next_turn_sim(living, sim_ct)
		for unit: Unit in living:
			sim_ct[unit] += unit.speed * min_ticks

		var batch: Array = []
		for unit: Unit in living:
			if sim_ct[unit] >= CT_THRESHOLD:
				batch.append(unit)

		batch.sort_custom(func(a: Unit, b: Unit) -> bool:
			return sim_ct[a] > sim_ct[b] if sim_ct[a] != sim_ct[b] else a.speed > b.speed
		)
		for unit: Unit in batch:
			result.append(unit)
			sim_ct[unit] -= CT_THRESHOLD
			if result.size() >= count:
				break

	return result

# ── Private ───────────────────────────────────────────────────────────────────

func _ticks_until_next_turn(living: Array[Unit]) -> int:
	var min_ticks: int = 9999
	for unit in living:
		if unit.speed <= 0:
			continue
		var ticks: int = ceili(float(CT_THRESHOLD - unit.ct) / float(unit.speed))
		min_ticks = min(min_ticks, max(1, ticks))
	return min_ticks

func _ticks_until_next_turn_sim(units: Array[Unit], sim_ct: Dictionary) -> int:
	var min_ticks: int = 9999
	for unit in units:
		if unit.speed <= 0:
			continue
		var remaining: int = CT_THRESHOLD - sim_ct.get(unit, 0)
		if remaining <= 0:
			return 1
		var ticks: int = ceili(float(remaining) / float(unit.speed))
		min_ticks = min(min_ticks, max(1, ticks))
	return min_ticks

func _sort_ready_queue() -> void:
	_ready_queue.sort_custom(func(a, b):
		return a.ct > b.ct if a.ct != b.ct else a.speed > b.speed
	)

func _flush_dead_from_queue() -> void:
	var cleaned: Array[Unit] = []
	for unit: Unit in _ready_queue:
		if not unit.is_dead:
			cleaned.append(unit)
	_ready_queue = cleaned
