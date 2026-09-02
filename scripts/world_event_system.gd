extends Node
class_name RenewWorldEventSystem

const STATUS_ACTIVE := "active"
const STATUS_RESOLVED := "resolved"
const STATUS_EXPIRED := "expired"

var events: Dictionary = {}
var active_events: Dictionary = {}
var history: Array = []
var next_instance_id := 1
var last_day := -1

var catalog := {
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
    var id := str(definition.get("id", ""))
    if id == "": return false
    events[id] = definition.duplicate(true)
    return true

func trigger(event_id: String, scope_data: Dictionary = {}, day: int = -1) -> Dictionary:
    if not events.has(event_id): return {"ok":false,"error":"unknown_event"}
    var def: Dictionary = events[event_id]
    var actual_day := day if day >= 0 else _current_day()
    var instance_id := "world_event:%d" % next_instance_id
    next_instance_id += 1
    var duration := int(def.get("duration", 0))
    var instance := {"instance_id":instance_id,"id":event_id,"category":def.get("category","general"),"start_day":actual_day,"duration":duration,"end_day":actual_day+duration,"scope":def.get("scope","global"),"scope_data":scope_data.duplicate(true),"causes":def.get("causes",[]).duplicate(true),"effects":def.get("effects",{}).duplicate(true),"choices":def.get("choices",[]).duplicate(true),"follow_up_events":def.get("follow_up_events",[]).duplicate(true),"resolution":{},"status":STATUS_ACTIVE}
    active_events[instance_id] = instance
    history.append(instance.duplicate(true))
    _publish("World event: %s" % event_id)
    if duration == 0: resolve(instance_id, {"choice":"automatic"})
    return {"ok":true,"event":instance.duplicate(true)}

func choose(instance_id: String, choice_id: String) -> Dictionary:
    if not active_events.has(instance_id): return {"ok":false,"error":"event_not_active"}
    var e: Dictionary = active_events[instance_id]
    for choice in e["choices"]:
        if str(choice.get("id","")) == choice_id:
            return resolve(instance_id, {"choice":choice_id,"effects":choice.get("effects",{}).duplicate(true)})
    return {"ok":false,"error":"choice_not_found"}

func resolve(instance_id: String, resolution: Dictionary = {}) -> Dictionary:
    if not active_events.has(instance_id): return {"ok":false,"error":"event_not_active"}
    var e: Dictionary = active_events[instance_id]
    e["status"] = STATUS_RESOLVED
    e["resolution"] = resolution.duplicate(true)
    e["resolution"]["day"] = _current_day()
    active_events.erase(instance_id)
    _apply_effects(e.get("effects",{}))
    _apply_effects(resolution.get("effects",{}))
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
    _roll_scheduled_events(day)

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
    if day > 1 and day % 17 == 0: trigger("energy_crisis", {"cause":"world_energy_stress"}, day)
    if day > 1 and day % 23 == 0: trigger("supply_disruption", {"cause":"world_logistics_stress"}, day)
    if day > 1 and day % 31 == 0: trigger("financial_crisis", {"cause":"credit_cycle"}, day)

func _apply_effects(effects: Dictionary) -> void:
    var main := get_tree().current_scene if get_tree() != null else null
    if main == null: return
    var game = get_node_or_null("/root/RenewGameState")
    if effects.has("cash") and main.get("cash") != null: main.set("cash", float(main.get("cash")) + float(effects["cash"]))
    if effects.has("reputation") and main.get("reputation") != null: main.set("reputation", int(main.get("reputation")) + int(effects["reputation"]))
    if game != null and game.has_method("set_world_modifier"): 
        for key in effects.keys(): game.set_world_modifier(str(key), effects[key])

func _replace_history(e: Dictionary) -> void:
    for i in range(history.size() - 1, -1, -1):
        if str(history[i].get("instance_id","")) == str(e.get("instance_id","")):
            history[i] = e.duplicate(true); return

func _publish(text: String) -> void:
    var news = get_node_or_null("/root/RenewNewsSystem")
    if news != null and news.has_method("publish"): news.publish(text, _current_day())

func _current_day() -> int:
    var scene := get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1

func capture_state() -> Dictionary:
    return {"events":events.duplicate(true),"active_events":active_events.duplicate(true),"history":history.duplicate(true),"next_instance_id":next_instance_id,"last_day":last_day}

func restore_state(state: Dictionary) -> void:
    events = state.get("events", catalog).duplicate(true)
    if events.is_empty(): events = catalog.duplicate(true)
    active_events = state.get("active_events", {}).duplicate(true)
    history = state.get("history", []).duplicate(true)
    next_instance_id = int(state.get("next_instance_id",1))
    last_day = int(state.get("last_day",-1))

func _process(_delta: float) -> void:
    var scene := get_tree().current_scene if get_tree() != null else null
    if scene == null: return
    var day := int(scene.get("day"))
    if day != last_day:
        last_day = day
        process_day(day)
