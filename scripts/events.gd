extends RefCounted
class_name RenewEvents

## Phase 26 — dynamic V1 events. Events modify live economy, supply, demand,
## production and operating costs rather than awarding flat cash bonuses.
const EVENT_DEFINITIONS := [
    {"id":"energy_shortage","title":"Energy Shortage","text":"Energy supply falls 20%, energy prices rise and factory costs increase.","duration_days":1,"effects":{"supply":{"energy":0.80},"market":{"energy":1.30},"operating_cost_multiplier":1.20}},
    {"id":"resource_discovery","title":"Resource Discovery","text":"New deposits increase timber and iron availability and lower their prices.","duration_days":1,"effects":{"supply":{"timber":1.35,"iron":1.25},"stock":{"timber":30.0,"iron":20.0},"market":{"timber":0.90,"iron":0.92}}},
    {"id":"supply_disruption","title":"Supply Disruption","text":"Material supply falls and procurement prices rise.","duration_days":1,"effects":{"supply":{"timber":0.75,"iron":0.80},"market":{"timber":1.20,"iron":1.15},"operating_cost_multiplier":1.10}},
    {"id":"demand_boom","title":"Demand Boom","text":"Strong spending lifts customer demand by 35%.","duration_days":1,"effects":{"demand_multiplier":1.35,"market":{"timber":1.10}}},
    {"id":"recession","title":"Recession","text":"Economic activity slows and customer demand falls by 30%.","duration_days":1,"effects":{"demand_multiplier":0.70,"market":{"energy":0.90,"timber":0.90,"iron":0.90}}},
    {"id":"natural_disaster","title":"Natural Disaster","text":"Severe weather damages resource output and raises affected material prices.","duration_days":1,"effects":{"supply":{"timber":0.55,"food":0.60},"market":{"timber":1.30,"food":1.25},"operating_cost_multiplier":1.15}},
    {"id":"technology_breakthrough","title":"Technology Breakthrough","text":"A manufacturing breakthrough boosts production 15% and cuts operating costs 15%.","duration_days":1,"effects":{"production_multiplier":1.15,"operating_cost_multiplier":0.85,"demand_multiplier":1.05}}
]

func definitions() -> Array:
    return EVENT_DEFINITIONS.duplicate(true)

func roll() -> Dictionary:
    return EVENT_DEFINITIONS[randi_range(0, EVENT_DEFINITIONS.size() - 1)].duplicate(true)

func begin_day(economy, state, day:int) -> Dictionary:
    _reset(economy, state)
    var event := roll()
    _apply(event, economy, state, day)
    return event

func _reset(economy, state) -> void:
    if economy != null and economy.has_method("reset_event_modifiers"):
        economy.reset_event_modifiers()
    if state != null:
        state.set_value("events", "active", {})
        state.set_value("events", "modifiers", {})

func _apply(event:Dictionary, economy, state, day:int) -> void:
    var effects:Dictionary = event.get("effects", {})
    if economy != null:
        var supply:Dictionary = effects.get("supply", {})
        for resource in supply.keys():
            if economy.has_method("set_event_supply_multiplier"):
                economy.set_event_supply_multiplier(String(resource), float(supply[resource]))
        var market:Dictionary = effects.get("market", {})
        for resource in market.keys():
            if economy.has_method("set_event_market_multiplier"):
                economy.set_event_market_multiplier(String(resource), float(market[resource]))
        var stock:Dictionary = effects.get("stock", {})
        for resource in stock.keys():
            if economy.resources.has(resource):
                economy.resources[resource]["stock"] = max(0.0, float(economy.resources[resource].get("stock", 0.0)) + float(stock[resource]))
    var active := event.duplicate(true)
    active["start_day"] = day
    active["end_day"] = day + int(event.get("duration_days", 1)) - 1
    if state != null:
        state.set_value("events", "active", active)
        var modifiers := {"demand_multiplier":float(effects.get("demand_multiplier",1.0)),"production_multiplier":float(effects.get("production_multiplier",1.0)),"operating_cost_multiplier":float(effects.get("operating_cost_multiplier",1.0))}
        state.set_value("events", "modifiers", modifiers)
        var history = state.get_value("events", "history", [])
        if not history is Array: history = []
        history = history.duplicate(true)
        history.append(active.duplicate(true))
        if history.size() > 50: history.pop_front()
        state.set_value("events", "history", history)
        state.set_value("company", "message", "%s: %s" % [event["title"], event["text"]])
        var logs = state.get_value("company", "log_lines", [])
        if not logs is Array: logs = []
        logs = logs.duplicate(true)
        logs.append("EVENT: %s — %s" % [event["title"], event["text"]])
        if logs.size() > 100: logs.pop_front()
        state.set_value("company", "log_lines", logs)
