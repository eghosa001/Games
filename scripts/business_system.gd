extends Node
const DomainSystem=preload("res://scripts/domain_system.gd")
const Economy=preload("res://scripts/economy.gd")
const Production=preload("res://scripts/production.gd")
const SupplyChain=preload("res://scripts/supply_chain_system.gd")
var state_adapter=DomainSystem.new();var economy=Economy.new();var production=Production.new();var supply_chain=SupplyChain.new();var employee_system=null
## Phase 20: complete V1 industry definitions.
const INDUSTRIES:={"furniture":{"id":"furniture","name":"Furniture","inputs":{"timber":1.0,"metal":0.5,"energy":2.0},"output":{"product":"furniture","units":1},"workers":3,"capacity":6,"operating_cost":70,"base_price":220,"market_demand":80},"construction_materials":{"id":"construction_materials","name":"Construction Materials","inputs":{"timber":1.0,"stone":2.0,"energy":2.5},"output":{"product":"construction_materials","units":1},"workers":4,"capacity":5,"operating_cost":95,"base_price":180,"market_demand":100},"consumer_electronics":{"id":"consumer_electronics","name":"Consumer Electronics","inputs":{"metal":1.0,"electronics_components":1.0,"energy":3.0},"output":{"product":"consumer_electronics","units":1},"workers":5,"capacity":4,"operating_cost":130,"base_price":360,"market_demand":70}}
const PURPOSES:={"Warehouse":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}],"Workshop":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}],"Commercial Building":[{"id":"furniture_factory","name":"Furniture Factory","type":"Factory","product":"furniture","industry_id":"furniture"},{"id":"construction_materials_factory","name":"Construction Materials Plant","type":"Factory","product":"construction_materials","industry_id":"construction_materials"},{"id":"consumer_electronics_factory","name":"Consumer Electronics Factory","type":"Factory","product":"consumer_electronics","industry_id":"consumer_electronics"}]}
func _ready()->void:add_child(state_adapter);add_child(supply_chain);supply_chain.set_economy(economy)
func _technology():return get_node_or_null("/root/RenewTechnologySystem")
func get_industries()->Array:
    var result:Array=[];for key in INDUSTRIES.keys():result.append(INDUSTRIES[key].duplicate(true));return result
func get_industry(industry_id:String)->Dictionary:return INDUSTRIES.get(industry_id,{}).duplicate(true)
func get_business_purposes()->Array:return PURPOSES.get(_origin_property_type(),[]).duplicate(true)
func get_business_purpose(index:int)->Dictionary:
    var choices:=get_business_purposes();if index<0 or index>=choices.size():return {};return choices[index].duplicate(true)
func open_business()->void:
    if not bool(state_adapter.get_value("properties","owned",false)) or str(state_adapter.get_value("properties","stage","Neglected"))!="Operational":state_adapter.message("Finish restoration first.");return
    if bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("%s is already open."%_business_name());return
    var existing_purpose:=str(state_adapter.get_value("businesses","business_purpose",""));if existing_purpose.is_empty():state_adapter.message("Choose what this restored property will become: press 4, 5 or 6.");return
    create_business(existing_purpose)
func choose_business_purpose(index:int)->void:
    if not bool(state_adapter.get_value("properties","owned",false)):state_adapter.message("Acquire a property first.");return
    if str(state_adapter.get_value("properties","stage","Neglected"))!="Operational":state_adapter.message("Finish restoring the property before choosing its purpose.");return
    if bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("The property has already been converted into %s."%_business_name());return
    var purpose:=get_business_purpose(index);if purpose.is_empty():state_adapter.message("Invalid business purpose.");return
    state_adapter.set_value("businesses","business_purpose",str(purpose.get("id","")));state_adapter.set_value("businesses","industry_id",str(purpose.get("industry_id","")));state_adapter.log_message("PURPOSE SELECTED: %s -> %s."%[_origin_property_name(),purpose.get("name","Business")]);create_business(str(purpose.get("id","")))
func create_business(purpose_id:String="")->void:
    if not bool(state_adapter.get_value("properties","owned",false)) or str(state_adapter.get_value("properties","stage","Neglected"))!="Operational":state_adapter.message("Finish restoration first.");return
    if bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("%s is already open."%_business_name());return
    var purpose:=_purpose_by_id(purpose_id if not purpose_id.is_empty() else str(state_adapter.get_value("businesses","business_purpose","")));if purpose.is_empty():state_adapter.message("Choose a business purpose first: press 4, 5 or 6.");return
    var industry_id:=str(purpose.get("industry_id",""));var industry:=get_industry(industry_id);if industry.is_empty():state_adapter.message("Selected business has no valid V1 industry.");return
    var cash:=int(state_adapter.get_value("economy","cash",25000));if cash<3000:state_adapter.message("Need $3,000 working capital to launch the business.");return
    var property:=_selected_property();var property_id:=str(property.get("id",""));var business_id:="%s_%s"%[purpose.get("id","business"),property_id]
    state_adapter.set_value("economy","cash",cash-3000);state_adapter.set_value("businesses","business_open",true);state_adapter.set_value("businesses","business_id",business_id);state_adapter.set_value("businesses","business_name",str(purpose.get("name","Business")));state_adapter.set_value("businesses","business_type",str(purpose.get("type","Business")));state_adapter.set_value("businesses","business_purpose",str(purpose.get("id","")));state_adapter.set_value("businesses","industry_id",industry_id);state_adapter.set_value("businesses","origin_property_id",property_id);state_adapter.set_value("businesses","origin_property_name",str(property.get("name","Property")));state_adapter.set_value("businesses","origin_property_type",str(property.get("type","Property")));state_adapter.set_value("player","reputation",int(state_adapter.get_value("player","reputation",0))+2);state_adapter.message("%s created inside %s. The restored property is now the origin of your business."%[purpose.get("name","Business"),property.get("name","Property")]);state_adapter.log_message("BUSINESS CREATED: %s — %s industry — origin %s (%s)."%[purpose.get("name","Business"),industry.get("name","Industry"),property.get("name","Property"),property_id])
func _purpose_by_id(purpose_id:String)->Dictionary:
    for purpose in get_business_purposes():
        if str(purpose.get("id",""))==purpose_id:return purpose
    return {}
func _selected_property()->Dictionary:
    var catalog=state_adapter.get_value("properties","catalog",[]);if not catalog is Array or catalog.is_empty():return {}
    var index:=clampi(int(state_adapter.get_value("properties","selected_property",0)),0,catalog.size()-1);return catalog[index].duplicate(true)
func _origin_property_type()->String:
    var stored:=str(state_adapter.get_value("businesses","origin_property_type",""));if not stored.is_empty():return stored
    return str(_selected_property().get("type",""))
func _origin_property_name()->String:
    var stored:=str(state_adapter.get_value("businesses","origin_property_name",""));if not stored.is_empty():return stored
    return str(_selected_property().get("name","Property"))
func _business_name()->String:return str(state_adapter.get_value("businesses","business_name","RENEW Goods"))
func upgrade_business()->void:
    if not bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("Create the business first.");return
    var level:=int(state_adapter.get_value("businesses","capacity_level",1));var cost:=4500*level;var cash:=int(state_adapter.get_value("economy","cash",25000));if cash<cost:state_adapter.message("Capacity upgrade requires $%s."%state_adapter.money(cost));return
    state_adapter.set_value("economy","cash",cash-cost);state_adapter.set_value("businesses","capacity_level",level+1);state_adapter.set_value("player","reputation",int(state_adapter.get_value("player","reputation",0))+2);state_adapter.log_message("UPGRADE: %s capacity level %d."%[_business_name(),level+1]);state_adapter.message("%s production capacity upgraded to level %d."%[_business_name(),level+1])
func marketing_campaign()->void:
    if not bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("Create the business first.");return
    var level:=int(state_adapter.get_value("businesses","marketing_level",0));var cost:=1800+level*700;var cash:=int(state_adapter.get_value("economy","cash",25000));if cash<cost:state_adapter.message("Marketing requires $%s."%state_adapter.money(cost));return
    state_adapter.set_value("economy","cash",cash-cost);state_adapter.set_value("businesses","marketing_level",level+1);state_adapter.set_value("player","reputation",int(state_adapter.get_value("player","reputation",0))+2);state_adapter.log_message("MARKETING: %s campaign %d launched (-$%s)."%[_business_name(),level+1,state_adapter.money(cost)]);state_adapter.message("Brand strength increased.")
func change_price()->void:
    if not bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("Create the business first.");return
    var price:=int(state_adapter.get_value("businesses","player_price",110))+10;if price>160:price=80;state_adapter.set_value("businesses","player_price",price);state_adapter.message("Selling price is now $%s."%state_adapter.money(price))
func _property_condition_multiplier()->float:
    var restoration:=int(state_adapter.get_value("properties","restoration",100));return clamp(0.70+float(restoration)/100.0*0.30,0.70,1.0)
func _technology_multiplier()->float:
    var tech=_technology();return tech.production_multiplier() if tech!=null else 1.0
func produce_goods()->void:
    if not bool(state_adapter.get_value("businesses","business_open",false)):state_adapter.message("Create the business first.");return
    var industry_id:=str(state_adapter.get_value("businesses","industry_id",""));var industry:=get_industry(industry_id);if industry.is_empty():state_adapter.message("Business has no valid V1 industry.");return
    if industry_id!="furniture":state_adapter.message("%s is defined as a V1 industry but its production pipeline is not yet connected."%industry.get("name","Industry"));return
    var tech=_technology();var required_workers:=int(industry.get("workers",3));if tech!=null:required_workers=max(1,required_workers-tech.worker_reduction())
    var employee_count:=int(industry.get("workers",3));var employee_factor:=1.0;var morale_multiplier:=1.0
    if employee_system!=null:employee_count=employee_system.get_active_employee_count();employee_factor=employee_system.get_productivity_multiplier("factory_001");morale_multiplier=employee_system.get_morale_multiplier()
    if employee_count<required_workers:state_adapter.message("%s requires %d active workers; you have %d."%[_business_name(),required_workers,employee_count]);return
    var capacity:=int(state_adapter.get_value("businesses","capacity_level",1));var business_efficiency:=clamp(0.85+float(capacity)*0.10,0.85,1.50);var base_output:=max(1,employee_count+capacity-1);var output_factor: float = employee_factor*business_efficiency*_technology_multiplier()*_property_condition_multiplier()*morale_multiplier;var cycles:=max(1,int(floor(float(base_output)*output_factor)))
    var cash:=int(state_adapter.get_value("economy","cash",25000));var orders:=[]
    for resource in industry.inputs.keys():
        var need: float = float(industry.inputs[resource])*cycles;if tech!=null:need*=1.0-tech.input_efficiency()
        if supply_chain.stock(resource)<need:orders.append({"resource":resource,"amount":max(0.0,need-supply_chain.stock(resource))})
    if not orders.is_empty():
        var transport_level:=int(state_adapter.get_value("supply_chain","transport_level",1));var delivery: Dictionary = supply_chain.procure_bundle(orders,cash,transport_level);if not delivery["ok"]:state_adapter.message("Factory stopped: supply delivery failed (%s)."%str(delivery.get("reason","unknown")));return
        cash-=int(delivery["cost"]);state_adapter.set_value("economy","cash",cash);state_adapter.log_message("SUPPLY: V1 industry inputs delivered to %s."%_business_name())
    var input_result: Dictionary = supply_chain.consume_furniture_inputs(cycles)
    if not input_result["ok"]:state_adapter.message("%s stopped: warehouse inputs are too low."%_business_name());return
    var quality:=clamp(int(round(72.0+employee_factor*5.0+morale_multiplier*4.0+_technology_multiplier()*3.0+randi_range(-3,4))),30,100);var output:int=max(1,cycles-int(floor(float(cycles)*0.08)));production.system.finished_goods+=output;production.system.inventory["goods"]=production.system.finished_goods
    var operating_cost:=int(round(float(industry.operating_cost)*float(cycles)*(tech.operating_cost_multiplier() if tech!=null else 1.0)));var price:=int(round(float(industry.base_price)*(tech.base_price_multiplier() if tech!=null else 1.0)))
    production.system.last_run={"product":industry.output.product,"stage":"manufacturing","cycles":cycles,"output":output,"quality":quality,"inputs":industry.inputs,"workers":required_workers,"capacity":industry.capacity,"base_price":price,"operating_cost":operating_cost,"market_demand":int(round(float(industry.market_demand)*(tech.market_demand_multiplier() if tech!=null else 1.0))),"technology_multiplier":_technology_multiplier()}
    supply_chain.receive_furniture(output);state_adapter.set_value("production","finished_goods",production.system.finished_goods);cash=int(state_adapter.get_value("economy","cash",cash))-operating_cost;state_adapter.set_value("economy","cash",cash)
    state_adapter.message("%s produced %d %s. Staff efficiency %.2fx."%[_business_name(),output,industry.output.product,output_factor]);state_adapter.log_message("INDUSTRY: %s — %d units produced from %s; operating cost $%d."%[industry.name,output,_origin_property_name(),operating_cost])
