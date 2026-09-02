extends RefCounted
class_name RenewSupplyChain

const SYSTEM_VERSION := 2
const STAGES := ["source", "extraction", "transport", "processing", "manufacturing", "warehouse", "distribution", "retail"]
const RESOURCE_BASE_COST := {"materials":38.0,"packaging":28.0,"fuel":52.0,"food":34.0}

var network_stock := {"materials":0,"packaging":0,"fuel":0,"food":0}
var stage_state := {}
var routes: Array = []
var shipments: Array = []
var shortages_today: Array[String] = []
var disruptions_today: Array[String] = []
var shipped_today := 0
var transport_cost_today := 0
var delay_today := 0
var disruption_level := 0
var competitor_pressure := 0
var day := 1
var valid_resources := ["materials","packaging","fuel","food"]
var resource_regions := {"materials":5,"packaging":0,"fuel":2,"food":3}

func _init() -> void:
    for stage in STAGES:
        stage_state[stage] = {"capacity":100,"used":0,"cost":0.0,"delay":0,"reliability":0.98,"risk":0.02,"controlled":true,"owner":"player"}
    _seed_default_routes()

func _seed_default_routes() -> void:
    routes = [
        {"id":"primary_supply","from":"source","to":"extraction","capacity":100,"cost_per_unit":1.0,"delay":1,"reliability":0.97,"risk":0.03,"owner":"player","controlled":true,"active":true},
        {"id":"resource_haul","from":"extraction","to":"processing","capacity":60,"cost_per_unit":2.5,"delay":2,"reliability":0.94,"risk":0.06,"owner":"player","controlled":true,"active":true},
        {"id":"factory_feed","from":"processing","to":"manufacturing","capacity":55,"cost_per_unit":2.0,"delay":1,"reliability":0.96,"risk":0.04,"owner":"player","controlled":true,"active":true},
        {"id":"warehouse_inbound","from":"manufacturing","to":"warehouse","capacity":50,"cost_per_unit":1.5,"delay":1,"reliability":0.98,"risk":0.02,"owner":"player","controlled":true,"active":true},
        {"id":"distribution_route","from":"warehouse","to":"distribution","capacity":45,"cost_per_unit":2.0,"delay":2,"reliability":0.93,"risk":0.07,"owner":"player","controlled":true,"active":true},
        {"id":"retail_route","from":"distribution","to":"retail","capacity":40,"cost_per_unit":1.5,"delay":1,"reliability":0.97,"risk":0.03,"owner":"player","controlled":true,"active":true}
    ]

func _normalize() -> void:
    for resource in valid_resources: network_stock[resource] = max(0,int(network_stock.get(resource,0)))
    shipped_today=max(0,shipped_today); transport_cost_today=max(0,transport_cost_today); delay_today=max(0,delay_today)
    disruption_level=clamp(disruption_level,0,100); competitor_pressure=clamp(competitor_pressure,0,20)
    for stage in STAGES:
        if not stage_state.has(stage): stage_state[stage]={"capacity":100,"used":0,"cost":0.0,"delay":0,"reliability":0.98,"risk":0.02,"controlled":true,"owner":"player"}
        stage_state[stage]["capacity"]=max(0,int(stage_state[stage].get("capacity",100)))
        stage_state[stage]["used"]=max(0,int(stage_state[stage].get("used",0)))
        stage_state[stage]["reliability"]=clamp(float(stage_state[stage].get("reliability",0.98)),0.0,1.0)
        stage_state[stage]["risk"]=clamp(float(stage_state[stage].get("risk",0.02)),0.0,1.0)

func configure_stage(stage:String,capacity:int,cost:float,delay:int,reliability:float,risk:float,owner:String="player",controlled:bool=true)->Dictionary:
    if stage not in STAGES: return {"ok":false,"message":"Unknown supply-chain stage."}
    stage_state[stage]={"capacity":max(0,capacity),"used":0,"cost":max(0.0,cost),"delay":max(0,delay),"reliability":clamp(reliability,0.0,1.0),"risk":clamp(risk,0.0,1.0),"owner":owner,"controlled":controlled}
    return {"ok":true}

func add_route(route_id:String,from_stage:String,to_stage:String,capacity:int,cost_per_unit:float,delay:int,reliability:float,risk:float,owner:String="player",controlled:bool=true)->Dictionary:
    if from_stage not in STAGES or to_stage not in STAGES or capacity<=0: return {"ok":false,"message":"Invalid route."}
    routes.append({"id":route_id,"from":from_stage,"to":to_stage,"capacity":capacity,"cost_per_unit":max(0.0,cost_per_unit),"delay":max(0,delay),"reliability":clamp(reliability,0.0,1.0),"risk":clamp(risk,0.0,1.0),"owner":owner,"controlled":controlled,"active":true})
    return {"ok":true}

func set_route_control(route_id:String,owner:String,controlled:bool)->Dictionary:
    for route in routes:
        if String(route.get("id",""))==route_id: route["owner"]=owner; route["controlled"]=controlled; return {"ok":true}
    return {"ok":false}
func set_route_active(route_id:String,active:bool)->Dictionary:
    for route in routes:
        if String(route.get("id",""))==route_id: route["active"]=active; return {"ok":true}
    return {"ok":false}
func route_for(from_stage:String,to_stage:String)->Dictionary:
    for route in routes:
        if route.get("from")==from_stage and route.get("to")==to_stage and bool(route.get("active",true)): return route
    return {}

func _stage_factor(stage:String)->float:
    var s:Dictionary=stage_state.get(stage,{})
    var control:=1.0 if bool(s.get("controlled",false)) else 0.78
    return clamp(control*float(s.get("reliability",0.98))*(1.0-float(s.get("risk",0.02))*0.5),0.25,1.0)
func chain_capacity()->int:
    var cap:=1000000
    for stage in STAGES: cap=min(cap,int(stage_state[stage].get("capacity",0)))
    for route in routes:
        if bool(route.get("active",true)): cap=min(cap,int(route.get("capacity",0)))
    return max(0,cap)
func chain_factor()->float:
    var factor:=1.0
    for stage in STAGES: factor*=_stage_factor(stage)
    for route in routes:
        if bool(route.get("active",true)): factor*=clamp(float(route.get("reliability",0.98))*(1.0-float(route.get("risk",0))*0.35),0.25,1.0)
    return clamp(factor,0.05,1.0)

func route_metrics(from_stage:String,to_stage:String,units:int)->Dictionary:
    var route:=route_for(from_stage,to_stage)
    if route.is_empty(): return {"ok":false,"capacity":0,"cost":0,"delay":0,"reliability":0.0,"risk":1.0,"controlled":false,"owner":"none"}
    var send:=min(max(0,units),int(route["capacity"]))
    return {"ok":send>0,"capacity":send,"cost":int(round(float(send)*float(route["cost_per_unit"]))),"delay":int(route["delay"]),"reliability":float(route["reliability"]),"risk":float(route["risk"]),"controlled":bool(route["controlled"]),"owner":String(route["owner"])}

func resource_price(resource:String,regions=null)->int:
    if resource not in valid_resources: return 0
    var base:=float(RESOURCE_BASE_COST.get(resource,40.0)); var pressure:=1.0+float(competitor_pressure)*0.025
    if regions and regions.has_method("regional_resource_bonus"): pressure*=1.0+float(regions.regional_resource_bonus(resource))
    return max(10,int(round(base*pressure)))
func acquire_from_market(resource:String,amount:int,cash:int,regions=null)->Dictionary:
    if resource not in valid_resources or amount<=0: return {"ok":false,"cost":0,"message":"Invalid resource order."}
    var cost:=resource_price(resource,regions)*amount
    if cash<cost: return {"ok":false,"cost":cost,"message":"Market shipment requires $%d."%cost}
    network_stock[resource]=int(network_stock.get(resource,0))+amount; shipped_today+=amount
    return {"ok":true,"cost":cost,"message":"Bought %d %s for $%d."%[amount,resource,cost]}

func move_from_site(resource_site:Dictionary,amount:int,transport_capacity:int)->Dictionary:
    var available:=int(resource_site.get("stock",0)); var moved:=min(min(max(0,amount),available),max(0,transport_capacity))
    if moved<=0: return {"ok":false,"moved":0,"message":"No transferable resource stock."}
    var resource:=String(resource_site.get("resource","materials"))
    if resource not in valid_resources: return {"ok":false,"moved":0,"message":"Unknown resource site."}
    resource_site["stock"]=available-moved; network_stock[resource]=int(network_stock.get(resource,0))+moved; shipped_today+=moved
    return {"ok":true,"moved":moved}

func _extract_from_expansion(expansion)->Dictionary:
    var generated:=0; var disruptions:Array[String]=[]
    if expansion==null: return {"generated":0,"disruptions":[]}
    for site in expansion.resource_sites:
        if not bool(site.get("owned",false)): continue
        var output:=int(site.get("output",0))*max(1,int(site.get("level",1))); var risk:=float(site.get("risk",0))/100.0
        if randf()<risk: output=max(0,int(round(output*0.55))); disruptions.append("%s suffered an extraction disruption."%site.get("name","Resource site"))
        site["stock"]=int(site.get("stock",0))+output; generated+=output
    return {"generated":generated,"disruptions":disruptions}

func execute_shipment(resource:String,amount:int,from_stage:String,to_stage:String)->Dictionary:
    if resource not in valid_resources or amount<=0: return {"ok":false,"moved":0,"cost":0,"delay":0}
    var route:=route_metrics(from_stage,to_stage,amount)
    if not route["ok"]: return {"ok":false,"moved":0,"cost":0,"delay":0}
    var stage_cap:=min(int(stage_state[from_stage]["capacity"])-int(stage_state[from_stage]["used"]),int(stage_state[to_stage]["capacity"])-int(stage_state[to_stage]["used"]))
    var moved:=min(int(route["capacity"]),max(0,stage_cap)); var disrupted:=false
    if moved<=0: return {"ok":false,"moved":0,"cost":0,"delay":int(route["delay"])}
    if randf()>clamp(float(route["reliability"])-float(route["risk"])*0.5,0.05,1.0):
        disrupted=true; disruptions_today.append("Shipment disruption on %s -> %s."%[from_stage,to_stage]); disruption_level=min(100,disruption_level+6); moved=int(floor(float(moved)*0.5))
    stage_state[from_stage]["used"]+=moved; stage_state[to_stage]["used"]+=moved
    var cost:=int(round(float(moved)*float(route["cost_per_unit"]))); transport_cost_today+=cost; delay_today+=int(route["delay"]); shipped_today+=moved
    shipments.append({"day":day,"resource":resource,"from":from_stage,"to":to_stage,"units":moved,"cost":cost,"delay":int(route["delay"]),"reliable":not disrupted,"owner":route["owner"]})
    if shipments.size()>250: shipments.pop_front()
    return {"ok":moved>0,"moved":moved,"cost":cost,"delay":int(route["delay"]),"disrupted":disrupted}

func process_physical_chain(resource:String,units:int)->Dictionary:
    var requested:=max(0,units); var effective:=min(requested,chain_capacity()); effective=int(floor(float(effective)*chain_factor())); var results:Array=[]; var current:=effective
    for i in range(STAGES.size()-1):
        var result:=execute_shipment(resource,current,String(STAGES[i]),String(STAGES[i+1])); results.append(result); current=int(result.get("moved",0));
        if current<=0: break
    return {"ok":current>0 or requested==0,"requested":requested,"delivered":current,"capacity":chain_capacity(),"chain_factor":chain_factor(),"results":results,"cost":transport_cost_today,"delay":delay_today,"disruptions":disruptions_today.duplicate()}

func daily_network_update(expansion,transport_capacity:int)->Dictionary:
    _normalize(); begin_day(day)
    var extraction:=_extract_from_expansion(expansion); disruptions_today=extraction["disruptions"].duplicate(); var moved:=0
    for site in expansion.resource_sites:
        if not bool(site.get("owned",false)): continue
        var transfer:=move_from_site(site,int(site.get("stock",0)),max(0,transport_capacity)); moved+=int(transfer.get("moved",0))
    if disruptions_today.is_empty(): disruption_level=max(0,disruption_level-2)
    return {"generated":int(extraction["generated"]),"moved":moved,"disruptions":disruptions_today.duplicate(),"shortages":shortages_today.duplicate(),"chain_factor":chain_factor(),"transport_cost":transport_cost_today}

func daily_business_check(expansion)->Dictionary:
    var shortages:Array[String]=[]
    if expansion!=null:
        for p in expansion.properties:
            if not bool(p.get("owned",false)) or not bool(p.get("active",false)): continue
            for resource in p.get("input_need",{}):
                if int(p["inputs"].get(resource,0))<int(p["input_need"][resource]): shortages.append("%s lacks %s."%[p["name"],resource])
    shortages_today=shortages; return {"shortages":shortages,"count":shortages.size()}

func begin_day(new_day:int)->void:
    day=max(1,new_day); shipped_today=0; transport_cost_today=0; delay_today=0; disruptions_today.clear()
    for stage in STAGES: stage_state[stage]["used"]=0
func end_day()->Dictionary:
    for stage in STAGES: stage_state[stage]["used"]=0
    return {"disruption_level":disruption_level,"transport_cost":transport_cost_today,"delay":delay_today,"shipments":shipments.size(),"disruptions":disruptions_today.duplicate()}
func reset_day()->void: begin_day(day)

func snapshot()->Dictionary:
    _normalize()
    return {"version":SYSTEM_VERSION,"network_stock":network_stock.duplicate(true),"stage_state":stage_state.duplicate(true),"routes":routes.duplicate(true),"shipments":shipments.duplicate(true),"shortages_today":shortages_today.duplicate(),"disruptions_today":disruptions_today.duplicate(),"shipped_today":shipped_today,"transport_cost_today":transport_cost_today,"delay_today":delay_today,"disruption_level":disruption_level,"competitor_pressure":competitor_pressure,"day":day}
func load_snapshot(state:Dictionary)->void:
    if not (state is Dictionary): return
    network_stock=state.get("network_stock",network_stock).duplicate(true); stage_state=state.get("stage_state",stage_state).duplicate(true); routes=state.get("routes",routes).duplicate(true); shipments=state.get("shipments",[]).duplicate(true); shortages_today=state.get("shortages_today",[]).duplicate(); disruptions_today=state.get("disruptions_today",[]).duplicate(); shipped_today=int(state.get("shipped_today",0)); transport_cost_today=int(state.get("transport_cost_today",0)); delay_today=int(state.get("delay_today",0)); disruption_level=int(state.get("disruption_level",0)); competitor_pressure=int(state.get("competitor_pressure",0)); day=int(state.get("day",1)); _normalize()

# Compatibility APIs.
func supply_business(property:Dictionary,amount:int,transport_capacity:int)->Dictionary:
    var moved:=0; var missing:Array[String]=[]
    for resource in property.get("input_need",{}):
        var need:=int(property["input_need"][resource])*max(1,amount); var available:=int(network_stock.get(resource,0)); var send:=min(min(need,available),max(0,transport_capacity)); network_stock[resource]=available-send; property["inputs"][resource]=int(property["inputs"].get(resource,0))+send; moved+=send
        if send<need: missing.append(resource)
    if not missing.is_empty(): return {"ok":false,"moved":moved,"missing":missing,"message":"Network shortage: %s."%", ".join(missing)}
    return {"ok":true,"moved":moved}
func supply_branch(branch:Dictionary,amount:int,transport_capacity:int)->Dictionary:
    var need:=max(1,amount); var available:=int(network_stock.get("packaging",0)); var moved:=min(min(need,available),max(0,transport_capacity)); network_stock["packaging"]=available-moved; branch["inputs_packaging"]=int(branch.get("inputs_packaging",0))+moved; return {"ok":moved>=need,"moved":moved,"shortage":max(0,need-moved)}
func consume_branch_packaging(branch:Dictionary,units:int)->Dictionary:
    var need:=max(1,units); var stock:=int(branch.get("inputs_packaging",0)); var used:=min(stock,need); branch["inputs_packaging"]=stock-used; return {"ok":used>=need,"used":used,"shortage":need-used}
