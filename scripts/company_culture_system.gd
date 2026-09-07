extends Node
## class_name removed: "RenewCompanyCultureSystem" conflicts with project.godot autoload.

## V2: persistent company culture profile.
## Culture is a strategic modifier built from leadership choices and employee conditions.
const SYSTEM_VERSION := 1
const CHECK_INTERVAL_SECONDS := 0.50
const DIMENSIONS := [
    "innovation",
    "discipline",
    "employee_welfare",
    "risk_tolerance",
    "quality",
    "growth_ambition",
    "environmental_responsibility",
]
const DEFAULT_PROFILE := {
    "innovation": 50,
    "discipline": 55,
    "employee_welfare": 60,
    "risk_tolerance": 45,
    "quality": 55,
    "growth_ambition": 50,
    "environmental_responsibility": 45,
}

var culture: Dictionary = DEFAULT_PROFILE.duplicate(true)
var _last_day: int = 0
var _timer: Timer

func _ready() -> void:
    _restore_from_state()
    _timer = Timer.new()
    _timer.wait_time = CHECK_INTERVAL_SECONDS
    _timer.one_shot = false
    add_child(_timer)
    _timer.timeout.connect(_check_day)
    _timer.start()

func _exit_tree() -> void:
    if is_instance_valid(_timer):
        if _timer.timeout.is_connected(_check_day):
            _timer.timeout.disconnect(_check_day)
        _timer.stop()
        _timer.queue_free()
        _timer = null

func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")

func _day() -> int:
    var state := _state()
    return int(state.get_value("player", "day", 1)) if state != null else 1

func _check_day() -> void:
    var day := _day()
    if day <= 0 or day == _last_day:
        return
    daily_update(day)

func _normalize() -> void:
    for dimension in DIMENSIONS:
        culture[dimension] = clampi(int(culture.get(dimension, DEFAULT_PROFILE[dimension])), 0, 100)

func get_profile() -> Dictionary:
    _normalize()
    return culture.duplicate(true)

func get_dimension(dimension: String) -> int:
    return int(culture.get(dimension, DEFAULT_PROFILE.get(dimension, 50)))

func set_dimension(dimension: String, value: int, day: int = 0, reason: String = "leadership decision") -> Dictionary:
    if not DIMENSIONS.has(dimension):
        return {"ok": false, "message": "Unknown culture dimension."}
    var old_value := get_dimension(dimension)
    var new_value := clampi(value, 0, 100)
    culture[dimension] = new_value
    _sync_state()
    if old_value != new_value:
        _log_change(dimension, old_value, new_value, day, reason)
    return {"ok": true, "dimension": dimension, "old": old_value, "value": new_value}

func adjust_dimension(dimension: String, amount: int, day: int = 0, reason: String = "leadership decision") -> Dictionary:
    return set_dimension(dimension, get_dimension(dimension) + amount, day, reason)

func daily_update(day: int) -> Dictionary:
    var resolved_day := int(day)
    if resolved_day <= 0:
        return {"day": resolved_day, "changed": false, "profile": get_profile()}
    if resolved_day == _last_day:
        return {"day": resolved_day, "changed": false, "profile": get_profile()}
    _last_day = resolved_day
    var before := get_profile()
    var employee_system := get_node_or_null("/root/RenewEmployeeSystem")
    if employee_system != null:
        var morale := 70.0
        if employee_system.has_method("get_morale_multiplier"):
            morale = clampf(float(employee_system.get_morale_multiplier()) * 70.0, 0.0, 100.0)
        var welfare_target := int(round(morale))
        _nudge("employee_welfare", welfare_target, 2)
        _nudge("discipline", 55, 1)
    _sync_state()
    return {"day": resolved_day, "changed": before != culture, "profile": get_profile()}

func get_effects() -> Dictionary:
    _normalize()
    var welfare := float(get_dimension("employee_welfare")) / 100.0
    var innovation := float(get_dimension("innovation")) / 100.0
    var quality := float(get_dimension("quality")) / 100.0
    var growth := float(get_dimension("growth_ambition")) / 100.0
    var discipline := float(get_dimension("discipline")) / 100.0
    var risk := float(get_dimension("risk_tolerance")) / 100.0
    var environment := float(get_dimension("environmental_responsibility")) / 100.0
    return {
        "recruitment_multiplier": clampf(0.85 + welfare * 0.30, 0.85, 1.15),
        "retention_multiplier": clampf(0.70 + welfare * 0.50, 0.70, 1.20),
        "productivity_multiplier": clampf(0.80 + welfare * 0.12 + discipline * 0.13, 0.80, 1.05),
        "research_multiplier": clampf(0.75 + innovation * 0.50, 0.75, 1.25),
        "quality_multiplier": clampf(0.80 + quality * 0.40, 0.80, 1.20),
        "expansion_multiplier": clampf(0.85 + growth * 0.30 + risk * 0.10, 0.85, 1.25),
        "reputation_multiplier": clampf(0.85 + quality * 0.10 + welfare * 0.10 + environment * 0.15, 0.85, 1.20),
    }

func capture_state() -> Dictionary:
    _normalize()
    return {"system_version": SYSTEM_VERSION, "culture": culture.duplicate(true), "last_day": _last_day}

func restore_state(snapshot: Dictionary) -> void:
    culture = DEFAULT_PROFILE.duplicate(true)
    if snapshot is Dictionary:
        var saved := snapshot.get("culture", {})
        if saved is Dictionary:
            for dimension in DIMENSIONS:
                if saved.has(dimension):
                    culture[dimension] = int(saved[dimension])
        _last_day = int(snapshot.get("last_day", 0))
    _normalize()
    _sync_state()

func _restore_from_state() -> void:
    var state := _state()
    if state != null:
        var saved: Dictionary = state.get_value("company", "culture", {}) as Dictionary
        if saved is Dictionary:
            for dimension in DIMENSIONS:
                if saved.has(dimension):
                    culture[dimension] = int(saved[dimension])
    _normalize()
    _sync_state()

func _sync_state() -> void:
    var state := _state()
    if state != null:
        state.set_value("company", "culture", culture.duplicate(true))

func _nudge(dimension: String, target: int, step: int) -> void:
    var current := get_dimension(dimension)
    if current < target:
        culture[dimension] = mini(current + step, target)
    elif current > target:
        culture[dimension] = maxi(current - step, target)

func _log_change(dimension: String, old_value: int, new_value: int, day: int, reason: String) -> void:
    var state := _state()
    if state == null:
        return
    var logs = state.get_value("company", "log_lines", [])
    if not logs is Array:
        logs = []
    logs = logs.duplicate(true)
    logs.append("Day %d: culture %s changed %d → %d (%s)." % [day, dimension, old_value, new_value, reason])
    if logs.size() > 100:
        logs.pop_front()
    state.set_value("company", "log_lines", logs)
