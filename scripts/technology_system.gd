extends Node

## Phase 21 — compact V1 technology tree.
## V2 adds Company Culture as a strategic modifier without changing base research costs.
const DomainSystem = preload("res://scripts/domain_system.gd")
const TECHNOLOGIES := {
    "efficient_production": {"name":"Efficient Production","tier":1,"cost_money":2500,"cost_points":10,"time_days":2,"prerequisites":[],"effects":{"production_multiplier":0.10}},
    "better_logistics": {"name":"Better Logistics","tier":1,"cost_money":2500,"cost_points":10,"time_days":2,"prerequisites":[],"effects":{"transport_capacity_multiplier":0.25}},
    "market_analysis": {"name":"Market Analysis","tier":1,"cost_money":2500,"cost_points":10,"time_days":2,"prerequisites":[],"effects":{"market_demand_multiplier":0.10}},
    "automation": {"name":"Automation","tier":2,"cost_money":4500,"cost_points":15,"time_days":3,"prerequisites":["efficient_production"],"effects":{"production_multiplier":0.15,"worker_reduction":1,"maintenance_multiplier":0.05}},
    "advanced_materials": {"name":"Advanced Materials","tier":2,"cost_money":4500,"cost_points":15,"time_days":3,"prerequisites":["efficient_production"],"effects":{"production_multiplier":0.08,"input_efficiency":0.10}},
    "supply_optimization": {"name":"Supply Optimization","tier":2,"cost_money":4500,"cost_points":15,"time_days":3,"prerequisites":["better_logistics"],"effects":{"transport_capacity_multiplier":0.20,"operating_cost_multiplier":-0.08}},
    "smart_factory": {"name":"Smart Factory","tier":3,"cost_money":7000,"cost_points":20,"time_days":4,"prerequisites":["automation"],"effects":{"production_multiplier":0.20,"worker_reduction":1}},
    "advanced_logistics": {"name":"Advanced Logistics","tier":3,"cost_money":7000,"cost_points":20,"time_days":4,"prerequisites":["better_logistics","supply_optimization"],"effects":{"transport_capacity_multiplier":0.40,"operating_cost_multiplier":-0.10}},
    "premium_manufacturing": {"name":"Premium Manufacturing","tier":3,"cost_money":7000,"cost_points":20,"time_days":4,"prerequisites":["advanced_materials"],"effects":{"production_multiplier":0.15,"base_price_multiplier":0.15}}
}

var state_adapter = DomainSystem.new()
var last_research_days: int = 0

func _ready() -> void:
    add_child(state_adapter)
func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")
func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem")
func _culture_effect(effect_name: String, fallback: float) -> float:
    var culture := get_node_or_null("/root/RenewCompanyCultureSystem")
    if culture != null and culture.has_method("get_effects"):
        return float(culture.get_effects().get(effect_name, fallback))
    return fallback
func _headquarters():
    var services = get_node_or_null("/root/RenewServices")
    if services != null and services.has_method("get_service"):
        return services.get_service("RenewHeadquartersSystem")
    return get_node_or_null("/root/RenewHeadquartersSystem")
func _hq_speed_multiplier() -> float:
    var hq = _headquarters()
    if hq != null and hq.has_method("technology_speed_multiplier"):
        return maxf(1.0, float(hq.technology_speed_multiplier()))
    return 1.0
func _hq_points_multiplier() -> float:
    var hq = _headquarters()
    if hq != null and hq.has_method("technology_points_multiplier"):
        return maxf(1.0, float(hq.technology_points_multiplier()))
    return 1.0
func get_technologies() -> Array:
    var result:Array=[]
    for id in TECHNOLOGIES.keys():
        var tech:Dictionary=TECHNOLOGIES[id].duplicate(true); tech["id"]=id; result.append(tech)
    return result
func get_technology(id:String)->Dictionary: return TECHNOLOGIES.get(id,{}).duplicate(true)
func _entry_researched(entry: Variant) -> bool:
    if entry is bool:
        return bool(entry)
    if entry is Dictionary:
        return bool((entry as Dictionary).get("researched", false))
    return false
func is_unlocked(id:String)->bool:
    var state=_state(); if state==null:return false
    var unlocked=state.get_value("technology","technology",{})
    return unlocked is Dictionary and _entry_researched((unlocked as Dictionary).get(id, false))
func get_unlocked(id:String)->bool: return is_unlocked(id)
func can_research(id:String)->Dictionary:
    var tech:=get_technology(id)
    if tech.is_empty():return {"ok":false,"reason":"unknown_technology"}
    if is_unlocked(id):return {"ok":false,"reason":"already_researched"}
    for prerequisite in tech.get("prerequisites",[]):
        if not is_unlocked(str(prerequisite)):return {"ok":false,"reason":"prerequisite","technology":str(prerequisite)}
    var state=_state(); if state==null:return {"ok":false,"reason":"state_unavailable"}
    var finance := _finance()
    if finance == null or not finance.has_method("available_cash") or not finance.has_method("spend"):
        return {"ok":false,"reason":"finance_unavailable"}
    var cash:=int(finance.available_cash()); var points:=int(state.get_value("technology","research_points",20))
    if cash<int(tech["cost_money"]):return {"ok":false,"reason":"money","required":int(tech["cost_money"]),"available":cash}
    if points<int(tech["cost_points"]):return {"ok":false,"reason":"research_points","required":int(tech["cost_points"]),"available":points}
    return {"ok":true}
func research(id:String)->bool:
    last_research_days = 0
    var check:=can_research(id); var state=_state(); if state==null:return false
    if not bool(check.get("ok",false)):
        state.set_value("company","message",_research_error(id,check)); return false
    var tech:=get_technology(id); var points:=int(state.get_value("technology","research_points",20))
    var finance := _finance()
    if finance == null or not finance.has_method("spend"):
        state.set_value("company","message","Financial system is unavailable; research was not started.")
        return false
    var spend_result: Dictionary = finance.spend(int(tech["cost_money"]),"technology research: %s" % str(tech["name"]))
    if not bool(spend_result.get("ok", false)):
        state.set_value("company","message",str(spend_result.get("message","Technology research requires sufficient cash.")))
        return false
    state_adapter._sync_finance_mirrors(finance)
    state.set_value("technology","research_points",points-int(tech["cost_points"]))
    var unlocked:Dictionary=state.get_value("technology","technology",{}); unlocked=unlocked.duplicate(true); unlocked[id]=true; state.set_value("technology","technology",unlocked)
    last_research_days = get_research_time_days(id)
    state.set_value("company","message","Research complete: %s. %d day(s) will be simulated." % [tech["name"],last_research_days])
    var logs=state.get_value("company","log_lines",[])
    if not logs is Array:
        logs=[]
    logs=logs.duplicate(true)
    logs.append("TECHNOLOGY: %s researched (-$%d, -%d RP, %d days)." % [tech["name"],int(tech["cost_money"]),int(tech["cost_points"]),last_research_days])
    if logs.size()>100:
        logs.pop_front()
    state.set_value("company","log_lines",logs)
    return true
func get_research_time_days(id:String)->int:
    var tech:=get_technology(id)
    if tech.is_empty(): return 0
    var base_days:int=max(1,int(tech.get("time_days",1)))
    var culture_multiplier:float=maxf(0.50,_culture_effect("research_multiplier",1.0))
    var multiplier:float=culture_multiplier * _hq_speed_multiplier()
    return max(1,int(ceil(float(base_days) / multiplier)))
func get_last_research_days()->int:
    return last_research_days
func research_next() -> bool:
    for tier in [1, 2, 3]:
        for id in TECHNOLOGIES.keys():
            if int(TECHNOLOGIES[id]["tier"]) == tier and not is_unlocked(id) and bool(can_research(id).get("ok", false)):
                return research(id)
    var state = _state()
    if state != null:
        state.set_value("company", "message", "No technology is currently researchable.")
    return false
func add_daily_research_points(amount:int=3)->void:
    var state=_state(); if state==null:return
    var credited:=max(0,int(round(float(max(0,amount))*state_adapter.executive_bonus("research")*max(1.0,state_adapter.infra_modifier("technology"))*_world_modifier("research")*_hq_points_multiplier())))
    state.set_value("technology","research_points",int(state.get_value("technology","research_points",20))+credited)
func _world_modifier(key:String)->float:
    var state=_state(); if state==null or not state.has_method("get_world_modifier"):return 1.0
    return clampf(float(state.get_world_modifier(key,1.0)),0.5,3.0)
func effect(name:String,default_value:float=0.0)->float:
    var total:=default_value; var state=_state(); if state==null:return total
    var unlocked=state.get_value("technology","technology",{}); if not unlocked is Dictionary:return total
    for id in (unlocked as Dictionary).keys():
        if _entry_researched((unlocked as Dictionary)[id]):
            total+=float(TECHNOLOGIES.get(str(id),{}).get("effects",{}).get(name,0.0))
    return total
func production_multiplier()->float:return max(1.0,1.0+effect("production_multiplier"))
func worker_reduction()->int:return max(0,int(effect("worker_reduction")))
func maintenance_multiplier()->float:return max(0.0,1.0+effect("maintenance_multiplier"))
func input_efficiency()->float:return clamp(effect("input_efficiency"),0.0,0.50)
func transport_capacity_multiplier()->float:return max(1.0,1.0+effect("transport_capacity_multiplier"))
func operating_cost_multiplier()->float:return max(0.25,1.0+effect("operating_cost_multiplier"))
func base_price_multiplier()->float:return max(1.0,1.0+effect("base_price_multiplier"))
func market_demand_multiplier()->float:return max(1.0,1.0+effect("market_demand_multiplier"))
func _research_error(id:String,check:Dictionary)->String:
    var tech:=get_technology(id)
    match str(check.get("reason","")):
        "money":return "Research %s needs $%s." % [tech.get("name",id),str(check.get("required",0))]
        "research_points":return "Research %s needs %d research points." % [tech.get("name",id),int(check.get("required",0))]
        "prerequisite":return "%s requires %s first." % [tech.get("name",id),get_technology(str(check.get("technology",""))).get("name",check.get("technology",""))]
        "already_researched":return "%s is already researched." % tech.get("name",id)
        "finance_unavailable":return "Financial system is unavailable; research cannot start."
    return "Technology research unavailable."
