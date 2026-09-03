extends Node

## Phase 21 — compact V1 technology tree.
## Definitions are static; research progress and unlocked technologies live in GameState.
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

func _state() -> Variant: return get_node_or_null("/root/RenewGameState")
func get_technologies() -> Array:
    var result:Array=[]
    for id in TECHNOLOGIES.keys():
        var tech:Dictionary=TECHNOLOGIES[id].duplicate(true); tech["id"]=id; result.append(tech)
    return result
func get_technology(id:String)->Dictionary: return TECHNOLOGIES.get(id,{}).duplicate(true)
func is_unlocked(id:String)->bool:
    var state=_state(); if state==null:return false
    var unlocked=state.get_value("technology","technology",{})
    return unlocked is Dictionary and bool(unlocked.get(id,false))
func can_research(id:String)->Dictionary:
    var tech:=get_technology(id)
    if tech.is_empty():return {"ok":false,"reason":"unknown_technology"}
    if is_unlocked(id):return {"ok":false,"reason":"already_researched"}
    for prerequisite in tech.get("prerequisites",[]):
        if not is_unlocked(str(prerequisite)):return {"ok":false,"reason":"prerequisite","technology":str(prerequisite)}
    var state=_state(); if state==null:return {"ok":false,"reason":"state_unavailable"}
    var cash:=int(state.get_value("economy","cash",25000)); var points:=int(state.get_value("technology","research_points",20))
    if cash<int(tech["cost_money"]):return {"ok":false,"reason":"money","required":int(tech["cost_money"]),"available":cash}
    if points<int(tech["cost_points"]):return {"ok":false,"reason":"research_points","required":int(tech["cost_points"]),"available":points}
    return {"ok":true}
func research(id:String)->bool:
    var check:=can_research(id); var state=_state(); if state==null:return false
    if not bool(check.get("ok",false)):
        state.set_value("company","message",_research_error(id,check)); return false
    var tech:=get_technology(id); var cash:=int(state.get_value("economy","cash",25000)); var points:=int(state.get_value("technology","research_points",20))
    state.set_value("economy","cash",cash-int(tech["cost_money"])); state.set_value("technology","research_points",points-int(tech["cost_points"]))
    var unlocked:Dictionary=state.get_value("technology","technology",{}); unlocked=unlocked.duplicate(true); unlocked[id]=true; state.set_value("technology","technology",unlocked)
    var day:=int(state.get_value("player","day",1))+int(tech["time_days"]); state.set_value("player","day",day)
    state.set_value("company","message","Research complete: %s. %d day(s) passed." % [tech["name"],int(tech["time_days"])])
    var logs=state.get_value("company","log_lines",[]); if not logs is Array:logs=[]; logs=logs.duplicate(true); logs.append("TECHNOLOGY: %s researched (-$%d, -%d RP, %d days)." % [tech["name"],int(tech["cost_money"]),int(tech["cost_points"]),int(tech["time_days"])]); if logs.size()>100:logs.pop_front(); state.set_value("company","log_lines",logs)
    return true
func research_next()->bool:
    for tier in [1,2,3]:
        for id in TECHNOLOGIES.keys():
            if int(TECHNOLOGIES[id]["tier"])==tier and not is_unlocked(id) and bool(can_research(id).get("ok",false)):return research(id)
    var state=_state(); if state!=null:state.set_value("company","message","No technology is currently researchable."); return false
func add_daily_research_points(amount:int=3)->void:
    var state=_state(); if state==null:return
    state.set_value("technology","research_points",int(state.get_value("technology","research_points",20))+max(0,amount))
func effect(name:String,default_value:float=0.0)->float:
    var total:=default_value; var state=_state(); if state==null:return total
    var unlocked=state.get_value("technology","technology",{}); if not unlocked is Dictionary:return total
    for id in unlocked.keys():
        if bool(unlocked[id]):total+=float(TECHNOLOGIES.get(str(id),{}).get("effects",{}).get(name,0.0))
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
    return "Technology research unavailable."
