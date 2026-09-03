extends Node
class_name RenewProductionSystem

const SYSTEM_VERSION := 4
const MAX_HISTORY := 500

# Product economics are configuration, not simulation logic. Resource costs are
# expressed in the five canonical economy resources.
const PRODUCT_CONFIG := {
    "consumer_goods":{"name":"Consumer Goods","stage":"manufacturing","inputs":{"food":1.0,"electronics":0.5,"energy":2.0},"output_item":"goods","output_per_cycle":2,"production_time":1.0,"employee_capacity":1,"base_price":110,"operating_cost":75,"reputation_effect":1,"base_quality":72,"waste_rate":0.06},
    "furniture":{"name":"Furniture","stage":"manufacturing","inputs":{"timber":1.0,"iron":0.5,"energy":2.0},"output_item":"furniture","output_per_cycle":1,"production_time":2.0,"employee_capacity":2,"base_price":220,"operating_cost":120,"reputation_effect":2,"base_quality":76,"waste_rate":0.08},
    "appliance":{"name":"Appliance","stage":"manufacturing","inputs":{"iron":1.0,"electronics":1.0,"energy":2.0},"output_item":"appliance","output_per_cycle":1,"production_time":2.5,"employee_capacity":2,"base_price":320,"operating_cost":165,"reputation_effect":3,"base_quality":80,"waste_rate":0.10}
}

const RECIPES := {
    "extract_ore":{"stage":"extraction","inputs":{},"outputs":{"iron_ore":4},"machine":"extractor","technology":"extraction","base_quality":58,"waste":0.03},
    "extract_timber":{"stage":"extraction","inputs":{},"outputs":{"timber":5},"machine":"harvester","technology":"extraction","base_quality":62,"waste":0.04},
    "process_steel":{"stage":"processing","inputs":{"iron_ore":2},"outputs":{"steel":1},"machine":"processor","technology":"steel_processing","base_quality":68,"waste":0.06},
    "process_lumber":{"stage":"processing","inputs":{"timber":2},"outputs":{"lumber":2},"machine":"processor","technology":"lumber_processing","base_quality":70,"waste":0.05},
    "manufacture_furniture":{"stage":"manufacturing","inputs":{"lumber":2,"steel":1},"outputs":{"furniture":1},"machine":"factory","technology":"furniture_manufacturing","base_quality":76,"waste":0.08},
    "manufacture_appliance":{"stage":"manufacturing","inputs":{"steel":2,"electronics":1},"outputs":{"appliance":1},"machine":"factory","technology":"appliance_manufacturing","base_quality":80,"waste":0.10},
    "distribute_furniture":{"stage":"distribution","inputs":{"furniture":1},"outputs":{"distributed_furniture":1},"machine":"fleet","technology":"logistics","base_quality":74,"waste":0.03},
    "distribute_appliance":{"stage":"distribution","inputs":{"appliance":1},"outputs":{"distributed_appliance":1},"machine":"fleet","technology":"logistics","base_quality":78,"waste":0.04},
    "retail_furniture":{"stage":"retail","inputs":{"distributed_furniture":1},"outputs":{"customer_furniture":1},"machine":"store","technology":"retail","base_quality":78,"waste":0.01},
    "retail_appliance":{"stage":"retail","inputs":{"distributed_appliance":1},"outputs":{"customer_appliance":1},"machine":"store","technology":"retail","base_quality":82,"waste":0.01}
}

const DEFAULT_MACHINES := {"extractor":{"owned":true,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},"harvester":{"owned":true,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},"processor":{"owned":false,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},"factory":{"owned":false,"condition":100.0,"capacity":2,"maintenance_due":0,"automation":0},"fleet":{"owned":false,"condition":100.0,"capacity":3,"maintenance_due":0,"automation":0},"store":{"owned":false,"condition":100.0,"capacity":4,"maintenance_due":0,"automation":0}}

var inventory:Dictionary={}; var finished_goods:int=0; var quality:int=60; var machines:Dictionary=DEFAULT_MACHINES.duplicate(true); var technologies:Dictionary={"extraction":1,"steel_processing":0,"lumber_processing":0,"furniture_manufacturing":0,"appliance_manufacturing":0,"logistics":0,"retail":0}; var utilization:Dictionary={}; var waste:Dictionary={}; var automation:Dictionary={}; var history:Array[Dictionary]=[]; var last_run:Dictionary={}

func _ready()->void: _ensure_inventory(); _ensure_machine_state()
func get_product_config(product_id:String="consumer_goods")->Dictionary: return PRODUCT_CONFIG.get(product_id,{}).duplicate(true)
func product_ids()->Array: return PRODUCT_CONFIG.keys()
func _ensure_inventory()->void:
    for recipe_id in RECIPES:
        var recipe:Dictionary=RECIPES[recipe_id]
        for item in recipe["inputs"]: inventory[item]=int(inventory.get(item,0))
        for item in recipe["outputs"]: inventory[item]=int(inventory.get(item,0))
    inventory["goods"]=int(inventory.get("goods",finished_goods))
func _ensure_machine_state()->void:
    for id in DEFAULT_MACHINES:
        if not machines.has(id): machines[id]=DEFAULT_MACHINES[id].duplicate(true)
        var m:Dictionary=machines[id]; m["condition"]=clamp(float(m.get("condition",100.0)),0.0,100.0); m["automation"]=clamp(int(m.get("automation",0)),0,5); m["capacity"]=max(1,int(m.get("capacity",1))); m["maintenance_due"]=max(0,int(m.get("maintenance_due",0))); machines[id]=m; utilization[id]=float(utilization.get(id,0.0)); automation[id]=int(m["automation"])
func recipe_ids(stage:String="")->Array:
    var result:Array=[]
    for id in RECIPES:
        if stage.is_empty() or String(RECIPES[id]["stage"])==stage: result.append(id)
    return result
func get_recipe(recipe_id:String)->Dictionary: return RECIPES.get(recipe_id,{}).duplicate(true)
func stock(item:String)->int: return int(inventory.get(item,0))
func add_inventory(item:String,amount:int)->void: inventory[item]=max(0,int(inventory.get(item,0))+amount)
func unlock_technology(technology:String,level:int=1)->void: technologies[technology]=max(int(technologies.get(technology,0)),level)
func acquire_machine(machine_id:String,capacity:int=1)->bool:
    if not machines.has(machine_id): return false
    machines[machine_id]["owned"]=true; machines[machine_id]["capacity"]=max(int(machines[machine_id].get("capacity",1)),capacity); return true
func set_automation(machine_id:String,level:int)->bool:
    if not machines.has(machine_id) or not bool(machines[machine_id].get("owned",false)): return false
    var v:=int(clamp(level,0,5)); machines[machine_id]["automation"]=v; automation[machine_id]=v; return true

func can_run(recipe_id:String,cycles:int=1)->Dictionary:
    if not RECIPES.has(recipe_id) or cycles<=0:return {"ok":false,"reason":"invalid_recipe"}
    var r:Dictionary=RECIPES[recipe_id]; var machine_id:=String(r["machine"]); if not machines.has(machine_id) or not bool(machines[machine_id].get("owned",false)):return {"ok":false,"reason":"machine_required","machine":machine_id}
    if int(technologies.get(r["technology"],0))<=0:return {"ok":false,"reason":"technology_required","technology":r["technology"]}
    var m:Dictionary=machines[machine_id]; if float(m.get("condition",0.0))<=5.0:return {"ok":false,"reason":"maintenance_required","machine":machine_id}
    var requested:=min(cycles,int(m.get("capacity",1))+int(m.get("automation",0)))
    for item in r["inputs"]:
        var required: int = int(r["inputs"][item])*requested
        if stock(item)<required:return {"ok":false,"reason":"missing_input","item":item,"required":required,"available":stock(item)}
    return {"ok":true,"cycles":requested,"machine":machine_id}
func run_recipe(recipe_id:String,cycles:int=1)->Dictionary:
    var check:=can_run(recipe_id,cycles); if not check["ok"]:return check
    var r:Dictionary=RECIPES[recipe_id]; var machine_id:=String(r["machine"]); var run_cycles:=int(check["cycles"]); var m:Dictionary=machines[machine_id]; var condition:=float(m["condition"]); var auto:=int(m["automation"]); var effective_waste:=clamp(float(r["waste"])-auto*0.012+(100.0-condition)*0.0015,0.0,0.35)
    for item in r["inputs"]: add_inventory(item,-int(r["inputs"][item])*run_cycles)
    var outputs:Dictionary={}; var total:=0
    for item in r["outputs"]:
        var planned:=int(r["outputs"][item])*run_cycles; var waste_amount:=int(floor(planned*effective_waste)); var actual:=max(0,planned-waste_amount); add_inventory(item,actual); outputs[item]=actual; total+=actual; waste[item]=int(waste.get(item,0))+waste_amount
        if String(r["stage"]) == "retail":
            finished_goods += actual
    inventory["goods"]=finished_goods
    var run_quality:=clamp(int(r["base_quality"])+randi_range(-2,3)+auto+int(round((condition-80.0)/20.0)),25,100); quality=int(round((quality+run_quality)/2.0)); m["condition"]=max(0.0,condition-(0.7+run_cycles*0.55-auto*0.08)); m["maintenance_due"]=int(m["maintenance_due"])+run_cycles; machines[machine_id]=m; utilization[machine_id]=clamp(float(utilization.get(machine_id,0.0))*0.75+float(run_cycles)/float(max(1,int(m["capacity"])+auto))*25.0,0.0,100.0)
    last_run={"recipe":recipe_id,"stage":r["stage"],"cycles":run_cycles,"outputs":outputs,"quality":run_quality,"waste":effective_waste,"machine":machine_id,"condition":m["condition"]}; history.append(last_run.duplicate(true)); if history.size()>MAX_HISTORY:history.pop_front()
    return {"ok":true,"recipe":recipe_id,"stage":r["stage"],"cycles":run_cycles,"outputs":outputs,"output":total,"quality":run_quality,"waste_rate":effective_waste,"machine":machine_id,"condition":m["condition"],"utilization":utilization[machine_id]}

func produce(economy:RenewEconomy,cycles:int,product_id:String="consumer_goods")->Dictionary:
    if economy==null or cycles<=0:return {"ok":false,"cycles":0,"output":0,"quality":quality}
    var c:=get_product_config(product_id); if c.is_empty():return {"ok":false,"cycles":0,"output":0,"quality":quality,"reason":"invalid_product"}
    var possible:=cycles
    for resource in c["inputs"]:
        if not economy.resources.has(resource):return {"ok":false,"cycles":0,"output":0,"quality":quality,"reason":"missing_market_resource","resource":resource}
        var required:=float(c["inputs"][resource]); possible=min(possible,int(floor(float(economy.resources[resource].get("stock",0.0))/required)))
    if possible<=0:return {"ok":false,"cycles":0,"output":0,"quality":quality,"reason":"insufficient_resources"}
    var consumed:Dictionary={}; var input_cost:=0.0
    for resource in c["inputs"]:
        var amount:=float(c["inputs"][resource])*possible; var unit:=float(economy.resources[resource].get("current_price",economy.resources[resource].get("price",0.0))); input_cost+=amount*unit; economy.resources[resource]["stock"]=max(0.0,float(economy.resources[resource]["stock"])-amount); consumed[resource]=amount
    var planned:=possible*int(c["output_per_cycle"]); var waste_amount:=int(floor(planned*float(c["waste_rate"]))); var output:=max(0,planned-waste_amount); finished_goods+=output; inventory["goods"]=finished_goods; quality=clamp(int(round((quality+float(c["base_quality"])+randi_range(-3,4))/2.0)),30,100)
    var operating_cost:=possible*int(c["operating_cost"]); last_run={"product":product_id,"stage":c["stage"],"cycles":possible,"output":output,"quality":quality,"resources":consumed,"resource_requirements":c["inputs"].duplicate(true),"resource_cost":input_cost,"production_time":float(c["production_time"]),"employee_capacity":int(c["employee_capacity"]),"base_price":int(c["base_price"]),"operating_cost":operating_cost,"reputation_effect":int(c["reputation_effect"]),"waste":waste_amount}; history.append(last_run.duplicate(true)); if history.size()>MAX_HISTORY:history.pop_front()
    return {"ok":true,"product":product_id,"cycles":possible,"output":output,"quality":quality,"finished_goods":finished_goods,"waste":waste_amount,"resources":consumed,"resource_cost":input_cost,"operating_cost":operating_cost,"base_price":int(c["base_price"]),"reputation_effect":int(c["reputation_effect"])}
func consume_goods(amount:int)->bool:
    if amount<0 or amount>finished_goods:return false
    finished_goods-=amount; inventory["goods"]=finished_goods; return true
func maintain_machine(machine_id:String,finance=null)->Dictionary:
    if not machines.has(machine_id) or not bool(machines[machine_id].get("owned",false)):return {"ok":false,"reason":"machine_not_owned"}
    var m:Dictionary=machines[machine_id]; var condition:=float(m.get("condition",100.0)); var cost:=int(round((100.0-condition)*35.0+int(m.get("maintenance_due",0))*12.0))
    if cost>0 and finance!=null:
        var payment=finance.spend(cost,"maintenance:%s"%machine_id); if not payment["ok"]:return {"ok":false,"reason":"insufficient_funds","cost":cost}
    m["condition"]=100.0; m["maintenance_due"]=0; machines[machine_id]=m; return {"ok":true,"machine":machine_id,"cost":cost,"condition":100.0}
func advance_day()->void:
    for id in machines: machines[id]["condition"]=max(0.0,float(machines[id].get("condition",100.0))-0.25)
func capture_state()->Dictionary: return {"system_version":SYSTEM_VERSION,"finished_goods":finished_goods,"quality":quality,"inventory":inventory.duplicate(true),"machines":machines.duplicate(true),"technologies":technologies.duplicate(true),"utilization":utilization.duplicate(true),"waste":waste.duplicate(true),"automation":automation.duplicate(true),"history":history.duplicate(true),"last_run":last_run.duplicate(true)}
func restore_state(snapshot:Dictionary)->void:
    if snapshot.is_empty():return
    finished_goods=int(snapshot.get("finished_goods",0)); quality=int(snapshot.get("quality",60)); inventory=snapshot.get("inventory",{}).duplicate(true); machines=snapshot.get("machines",DEFAULT_MACHINES).duplicate(true); technologies=snapshot.get("technologies",technologies).duplicate(true); utilization=snapshot.get("utilization",{}).duplicate(true); waste=snapshot.get("waste",{}).duplicate(true); automation=snapshot.get("automation",{}).duplicate(true); history=snapshot.get("history",[]).duplicate(true); last_run=snapshot.get("last_run",{}).duplicate(true); _ensure_inventory(); _ensure_machine_state()
