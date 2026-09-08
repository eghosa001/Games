extends Node
## class_name removed: "RenewWorldEventSystem" conflicts with project.godot autoload.

const STATUS_ACTIVE := "active"
const STATUS_RESOLVED := "resolved"
const STATUS_EXPIRED := "expired"

var events: Dictionary = {}
var active_events: Dictionary = {}
var history: Array = []
var next_instance_id: Variant = 1
var last_day: Variant = -1
var last_roll_day: Variant = -1

func _ready() -> void:
    if events.is_empty():
        events = catalog.duplicate(true)

var catalog: Variant = {
    "energy_crisis": {"id":"energy_crisis","category":"energy","duration":4,"scope":"global","causes":["grid_shortage","fuel_disruption"],"effects":{"energy_price":1.35,"factory_cost":1.12},"choices":[{"id":"ration","label":"Ration energy","effects":{"factory_output":0.88,"energy_price":1.10}},{"id":"subsidize","label":"Subsidize supply","effects":{"cash":-5000.0,"energy_price":0.95}}],"follow_up_events":["energy_price_shock"]},
    "energy_price_shock": {"id":"energy_price_shock","category":"market","duration":3,"scope":"global","causes":["energy_crisis"],"effects":{"energy_price":1.50,"factory_cost":1.20,"factory_output":0.92},"choices":[{"id":"adapt","label":"Adapt factories","effects":{"cash":-3000.0,"factory_output":0.97}},{"id":"hold","label":"Hold production","effects":{"factory_output":0.90}}],"follow_up_events":["alternative_energy_demand"]},
    "alternative_energy_demand": {"id":"alternative_energy_demand","category":"opportunity","duration":5,"scope":"global","causes":["energy_price_shock"],"effects":{"alternative_energy_demand":1.60,"investment_opportunity":1.25},"choices":[{"id":"invest","label":"Invest in alternatives","effects":{"investment_opportunity":1.50}},{"id":"research","label":"Fund energy research","effects":{"research_opportunity":1.50}}],"follow_up_events":["energy_investment_boom","energy_research_breakthrough"]},
    "energy_investment_boom": {"id":"energy_investment_boom","category":"investment","duration":6,"scope":"global","causes":["alternative_energy_demand"],"effects":{"investment_opportunity":1.80,"renewable_demand":1.50},"choices":[{"id":"build","label":"Build renewable capacity","effects":{"infrastructure_capacity":1.20}},{"id":"skip","label":"Stay liquid","effects":{"cash":1000.0}}],"follow_up_events":[]},
    "energy_research_breakthrough": {"id":"energy_research_breakthrough","category":"research","duration":4,"scope":"global","causes":["alternative_energy_demand"],"effects":{"research_speed":1.35,"research_opportunity":1.50},"choices":[{"id":"commercialize","label":"Commercialize discovery","effects":{"technology_discovery":1.0}},{"id":"publish","label":"Publish research","effects":{"reputation":4}}],"follow_up_events":["new_energy_technology"]},
    "new_energy_technology": {"id":"new_energy_technology","category":"technology","duration":0,"scope":"global","causes":["energy_research_breakthrough"],"effects":{"renewable_efficiency":1.20,"research_discovery":1.0},"choices":[],"follow_up_events":[]},
    "supply_disruption": {"id":"supply_disruption","category":"supply_chain","duration":3,"scope":"regional","causes":["logistics_failure","resource_shortage"],"effects":{"logistics_cost":1.30,"input_cost":1.18},"choices":[{"id":"reroute","label":"Reroute supplies","effects":{"logistics_cost":1.10,"cash":-2500.0}},{"id":"wait","label":"Wait it out","effects":{"factory_output":0.88}}],"follow_up_events":["input_shortage"]},
    "input_shortage": {"id":"input_shortage","category":"production","duration":4,"scope":"regional","causes":["supply_disruption"],"effects":{"input_cost":1.35,"factory_output":0.84},"choices":[{"id":"source","label":"Find alternate suppliers","effects":{"factory_output":0.96,"cash":-3500.0}},{"id":"cut","label":"Cut output","effects":{"factory_output":0.82}}],"follow_up_events":[]},
    "financial_crisis": {"id":"financial_crisis","category":"finance","duration":5,"scope":"global","causes":["credit_contraction","market_panic"],"effects":{"credit_cost":1.30,"investment":0.75},"choices":[{"id":"refinance","label":"Refinance debt","effects":{"credit_cost":1.10}},{"id":"cash","label":"Preserve cash","effects":{"investment":0.65}}],"follow_up_events":[]}
}

func register_event(definition: Dictionary) -> bool:
    var id: Variant = str(definition.get("id", ""))
    if id == "": return false
    events[id] = definition.duplicate(true)
    return true

func trigger(event_id: String, scope_data: Dictionary = {}, day: int = -1) -> Dictionary:
    if not events.has(event_id): return {"ok":false,"error":"unknown_event"}
    var def: Dictionary = events[event_id]
    var actual_day: Variant = day if day >= 0 else _current_day()
    var instance_id: Variant = "world_event:%d" % next_instance_id
    next_instance_id += 1
    var duration: Variant = int(def.get("duration", 0))
    var instance: Variant = {"instance_id":instance_id,"id":event_id,"category":def.get("category","general"),"start_day":actual_day,"duration":duration,"end_day":actual_day+duration,"scope":def.get("scope","global"),"scope_data":scope_data.duplicate(true),"causes":def.get("causes",[]).duplicate(true),"effects":def.get("effects",{}).duplicate(true),"choices":def.get("choices",[]).duplicate(true),"follow_up_events":def.get("follow_up_events",[]).duplicate(true),"resolution":{},"status":STATUS_ACTIVE}
    active_events[instance_id] = instance
    history.append(instance.duplicate(true))
    _publish("World event: %s" % event_id)
    _sync_modifiers()
    if duration == 0: resolve(instance_id, {"choice":"automatic"})
    return {"ok":true,"event":instance.duplicate(true)}

func choose(instance_id: String, choice_id: String) -> Dictionary:
    if not active_events.has(instance_id): return {"ok":false,"error":"event_not_active"}
    var e: Dictionary = active_events[instance_id]
    if not (e.get("resolution", {}) as Dictionary).is_empty(): return {"ok":false,"error":"choice_already_made"}
    for choice in e["choices"]:
        if str(choice.get("id","")) == choice_id:
            var picked: Dictionary = (choice as Dictionary).duplicate(true)
            var merged: Dictionary = (e.get("effects", {}) as Dictionary).duplicate(true)
            var picked_effects: Dictionary = (picked.get("effects", {}) as Dictionary).duplicate(true)
            if not _apply_effects(picked_effects):
                return {"ok":false,"error":"effect_application_failed"}
            for key in picked_effects.keys():
                merged[key] = picked_effects[key]
            e["effects"] = merged
            e["resolution"] = {"choice":choice_id,"day":_current_day()}
            active_events[instance_id] = e
            _sync_modifiers()
            _replace_history(e)
            return {"ok":true,"event":e.duplicate(true)}
    return {"ok":false,"error":"choice_not_found"}

func resolve(instance_id: String, resolution: Dictionary = {}) -> Dictionary:
    if not active_events.has(instance_id): return {"ok":false,"error":"event_not_active"}
    var e: Dictionary = active_events[instance_id]
    e["status"] = STATUS_RESOLVED
    e["resolution"] = resolution.duplicate(true)
    e["resolution"]["day"] = _current_day()
    active_events.erase(instance_id)
    _sync_modifiers()
    var chosen: String = str(e["resolution"].get("choice", ""))
    # A chosen option is applied immediately in choose(). Do not apply the
    # merged event effects again here or cash/reputation rewards are duplicated.
    # Automatic/no-choice resolution still needs the event's base effects.
    if chosen.is_empty() or chosen == "automatic":
        if not _apply_effects(e.get("effects", {})):
            active_events[instance_id] = e
            _sync_modifiers()
            return {"ok":false,"error":"effect_application_failed"}
    if not _apply_effects(resolution.get("effects", {})):
        return {"ok":false,"error":"resolution_effect_application_failed"}
    _queue_followups(e)
    _replace_history(e)
    return {"ok":true,"event":e.duplicate(true)}

func process_day(day: int) -> void:
    var to_expire: Array = []
    for instance_id in active_events.keys():
        var e: Dictionary = active_events[instance_id]
        if int(e.get("end_day",day+1)) > day: continue
        to_expire.append(instance_id)
    for instance_id in to_expire:
        if active_events.has(instance_id):
            var e: Dictionary = active_events[instance_id]
            e["status"] = STATUS_EXPIRED
            active_events.erase(instance_id)
            _queue_followups(e)
            _replace_history(e)
    _sync_modifiers()
    _roll_scheduled_events(day)
    _roll_cycle(day)
const CYCLE_PHASES := ["expansion", "boom", "overheating", "recession", "recovery"]
const CYCLE_LENGTH := 45
const CYCLE_DEMAND := {
    "furniture": {"expansion": 1.0, "boom": 1.20, "overheating": 1.10, "recession": 0.70, "recovery": 0.90},
    "construction_materials": {"expansion": 1.0, "boom": 1.30, "overheating": 1.15, "recession": 0.60, "recovery": 0.85},
    "consumer_electronics": {"expansion": 1.0, "boom": 1.25, "overheating": 1.10, "recession": 0.75, "recovery": 0.95}
}
func cycle_phase() -> Dictionary:
    var game = get_node_or_null("/root/RenewGameState")
    if game == null:
        return {"phase": "expansion", "start_day": 1}
    var seasonal: Variant = game.get_value("events", "seasonal", {})
    if seasonal is Dictionary and (seasonal as Dictionary).get("economy_cycle") is Dictionary:
        return ((seasonal as Dictionary)["economy_cycle"] as Dictionary).duplicate(true)
    return {"phase": "expansion", "start_day": _current_day()}
func _roll_cycle(day: int) -> void:
    var game = get_node_or_null("/root/RenewGameState")
    if game == null or not game.has_method("set_world_modifier"):
        return
    var seasonal: Variant = game.get_value("events", "seasonal", {})
    var table: Dictionary = (seasonal as Dictionary).duplicate(true) if seasonal is Dictionary else {}
    var cycle: Dictionary = (table.get("economy_cycle", {}) as Dictionary).duplicate(true) if table.get("economy_cycle", {}) is Dictionary else {"phase": "expansion", "start_day": day}
    if day - int(cycle.get("start_day", day)) < CYCLE_LENGTH:
        return
    var next_index := (CYCLE_PHASES.find(str(cycle.get("phase", "expansion"))) + 1) % CYCLE_PHASES.size()
    if next_index < 0:
        next_index = 0
    var advanced := false
    if day - int(cycle.get("start_day", day)) >= CYCLE_LENGTH:
        cycle = {"phase": CYCLE_PHASES[next_index], "start_day": day}
        table["economy_cycle"] = cycle
        game.set_value("events", "seasonal", table)
        advanced = true
    _apply_cycle_modifiers()
    if advanced:
        _publish("EVENT: Economic %s — demand shifts across industries." % str(cycle["phase"]).capitalize())
func _apply_cycle_modifiers() -> void:
    var game = get_node_or_null("/root/RenewGameState")
    if game == null or not game.has_method("set_world_modifier"):
        return
    var phase := str(cycle_phase().get("phase", "expansion"))
    var demand: Dictionary = CYCLE_DEMAND
    for industry in (demand as Dictionary).keys():
        game.set_world_modifier("cycle_" + str(industry), float(((demand as Dictionary)[industry] as Dictionary).get(phase, 1.0)))

func active() -> Array:
    var out: Array = []
    for e in active_events.values(): out.append(e.duplicate(true))
    return out

func get_event(instance_id: String) -> Dictionary: return active_events.get(instance_id, {}).duplicate(true)
func history_list() -> Array: return history.duplicate(true)

func _queue_followups(e: Dictionary) -> void:
    for follow_id in e.get("follow_up_events", []):
        trigger(str(follow_id), {"caused_by":e.get("instance_id","")}, _current_day() + 1)

func _roll_scheduled_events(day: int) -> void:
    if day == last_roll_day:
        return
    last_roll_day = day
    if day > 1 and day % 17 == 0: trigger("energy_crisis", {"cause":"world_energy_stress"}, day)
    if day > 1 and day % 23 == 0: trigger("supply_disruption", {"cause":"world_logistics_stress"}, day)
    if day > 1 and day % 31 == 0: trigger("financial_crisis", {"cause":"credit_cycle"}, day)

func _apply_effects(effects: Dictionary) -> bool:
    var game = get_node_or_null("/root/RenewGameState")
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if effects.has("cash"):
        if finance == null:
            return false
        var cash_delta := float(effects["cash"])
        var cash_result: Dictionary
        if cash_delta >= 0.0:
            cash_result = finance.receive(int(round(cash_delta)), "world event effect")
        else:
            cash_result = finance.spend(int(round(-cash_delta)), "world event effect")
        if not bool(cash_result.get("ok", false)):
            return false
    if effects.has("reputation") and game != null:
        var current_rep := int(game.get_value("player", "reputation", 0))
        game.set_value("player", "reputation", current_rep + int(effects["reputation"]))
    return true

func _sync_modifiers() -> void:
    var game = get_node_or_null("/root/RenewGameState")
    if game == null or not game.has_method("clear_world_modifiers"): return
    game.clear_world_modifiers()
    if not game.has_method("set_world_modifier"): return
    for e in active_events.values():
        if not e is Dictionary: continue
        for key in (e as Dictionary).get("effects", {}).keys():
            if str(key) == "cash" or str(key) == "reputation": continue
            var current: float = game.get_world_modifier(str(key), 1.0) if game.has_method("get_world_modifier") else 1.0
            game.set_world_modifier(str(key), current * float(((e as Dictionary).get("effects", {}) as Dictionary)[key]))
    _apply_cycle_modifiers()
func _replace_history(e: Dictionary) -> void:
    for i in range(history.size() - 1, -1, -1):
        if str(history[i].get("instance_id","")) == str(e.get("instance_id","")):
            history[i] = e.duplicate(true); return

func _publish(text: String) -> void:
    var game = get_node_or_null("/root/RenewGameState")
    if game == null: return
    var line := text if text.begins_with("EVENT:") else "EVENT: " + text
    var logs: Variant = game.get_value("company", "log_lines", [])
    var lines: Array = (logs as Array).duplicate(true) if logs is Array else []
    lines.append(line)
    while lines.size() > 100: lines.pop_front()
    game.set_value("company", "log_lines", lines)

func _current_day() -> int:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1

func capture_state() -> Dictionary:
    return {"events":events.duplicate(true),"active_events":active_events.duplicate(true),"history":history.duplicate(true),"next_instance_id":next_instance_id,"last_day":last_day,"last_roll_day":last_roll_day}

func restore_state(state: Dictionary) -> void:
    events = state.get("events", catalog).duplicate(true)
    if events.is_empty(): events = catalog.duplicate(true)
    active_events = state.get("active_events", {}).duplicate(true)
    history = state.get("history", []).duplicate(true)
    next_instance_id = int(state.get("next_instance_id",1))
    last_day = int(state.get("last_day",-1))
    last_roll_day = int(state.get("last_roll_day",-1))

func _process(_delta: float) -> void:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    if scene == null: return
    var day: Variant = int(scene.get("day"))
    if day != last_day:
        last_day = day
        process_day(day)
