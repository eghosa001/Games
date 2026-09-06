extends Node

## Phase 26 — prepares one dynamic event for each playable day.
## The event is installed before the next simulation tick so economy and demand
## systems consume the event's modifiers during the actual day.
const Events = preload("res://scripts/events.gd")
const CHECK_INTERVAL_SECONDS := 0.25
var event_model = Events.new()
var prepared_day: int = -1
var check_timer: Timer

func _ready() -> void:
    check_timer = Timer.new()
    check_timer.name = "DynamicEventCheckTimer"
    check_timer.wait_time = CHECK_INTERVAL_SECONDS
    check_timer.one_shot = false
    check_timer.autostart = true
    check_timer.timeout.connect(_check_current_day)
    add_child(check_timer)
    call_deferred("_check_current_day")

func _check_current_day() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var day: int = int(state.get_value("player", "day", 1))
    if day == prepared_day:
        return
    var economy = _find_economy()
    if economy == null:
        return
    event_model.begin_day(economy, state, day)
    prepared_day = day

func _exit_tree() -> void:
    if check_timer != null and is_instance_valid(check_timer):
        if check_timer.timeout.is_connected(_check_current_day):
            check_timer.timeout.disconnect(_check_current_day)
        check_timer.stop()

func _find_economy():
    var main = get_node_or_null("/root/Main")
    if main == null:
        return null
    var command = main.get_node_or_null("GameplayCommandSystem")
    if command == null or command.supply_system == null:
        return null
    return command.supply_system.economy

func current_event() -> Dictionary:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null:
        return {}
    var active = state.get_value("events", "active", {})
    return active.duplicate(true) if active is Dictionary else {}
