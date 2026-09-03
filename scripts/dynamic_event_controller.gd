extends Node

## Phase 26 — prepares one dynamic event for each playable day.
## The event is installed before the next simulation tick so economy and demand
## systems consume the event's modifiers during the actual day.
const Events = preload("res://scripts/events.gd")
var event_model = Events.new()
var prepared_day := -1

func _ready() -> void:
    set_process(true)

func _process(_delta:float) -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null:
        return
    var day := int(state.get_value("player", "day", 1))
    if day == prepared_day:
        return
    var economy = _find_economy()
    if economy == null:
        return
    event_model.begin_day(economy, state, day)
    prepared_day = day

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
