extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Production = preload("res://scripts/production.gd")
const SupplyChain = preload("res://scripts/supply_chain_system.gd")

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var production = Production.new()
var supply_chain = SupplyChain.new()
var employee_system = null

func _ready() -> void:
    add_child(state_adapter)
    add_child(supply_chain)
    supply_chain.set_economy(economy)

func open_business() -> void:
    if not bool(state_adapter.get_value("properties", "owned", false)) or str(state_adapter.get_value("properties", "stage", "Neglected")) != "Operational":
        state_adapter.message("Finish restoration first."); return
    if bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("RENEW Goods is already open."); return
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < 3000: state_adapter.message("Need $3,000 working capital."); return
    state_adapter.set_value("economy", "cash", cash - 3000)
    state_adapter.set_value("businesses", "business_open", true)
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.message("RENEW Goods is open. Build inventory, win customers and reinvest.")
    state_adapter.log_message("OPENED: RENEW Goods with 3 employees.")

func upgrade_business() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)): state_adapter.message("Open the business first."); return
    var level := int(state_adapter.get_value("businesses", "capacity_level", 1)); var cost := 4500 * level; var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost: state_adapter.message("Capacity upgrade requires $%s." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost); state_adapter.set_value("businesses", "capacity_level", level + 1); state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("UPGRADE: RENEW Goods capacity level %d." % (level + 1)); state_adapter.message("Production capacity upgraded to level %d." % (level + 1))

func marketing_campaign() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)): state_adapter.message("Open the business first."); return
    var level := int(state_adapter.get_value("businesses", "marketing_level", 0)); var cost := 1800 + level * 700; var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost: state_adapter.message("Marketing requires $%s." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost); state_adapter.set_value("businesses", "marketing_level", level + 1); state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 2)
    state_adapter.log_message("MARKETING: campaign %d launched (-$%s)." % [level + 1, state_adapter.money(cost)]); state_adapter.message("Brand strength increased.")

func change_price() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)): state_adapter.message("Open the business first."); return
    var price := int(state_adapter.get_value("businesses", "player_price", 110)) + 10
    if price > 160: price = 80
    state_adapter.set_value("businesses", "player_price", price); state_adapter.message("Selling price is now $%s." % state_adapter.money(price))

func _property_condition_multiplier() -> float:
    var restoration:=int(state_adapter.get_value("properties","restoration",100)); return clamp(0.70+float(restoration)/100.0*0.30,0.70,1.0)
func _technology_multiplier() -> float:
    var technology=state_adapter.get_value("technology","technology",{})
    if not technology is Dictionary: return 1.0
    var level:=0
    for key in technology.keys(): level+=int(technology[key])
    return clamp(1.0+float(level)*0.025,1.0,1.35)

# Phase 9 factory flow: market resources -> warehouse -> metal factory -> furniture factory.
func produce_goods() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)): state_adapter.message("Open the business first."); return
    var employee_count:=3
    var employee_factor:=1.0
    var morale_multiplier:=1.0
    if employee_system != null:
        employee_count=employee_system.get_active_employee_count()
        employee_factor=employee_system.get_productivity_multiplier("factory_001")
        morale_multiplier=employee_system.get_morale_multiplier()
    var capacity:=int(state_adapter.get_value("businesses", "capacity_level", 1))
    var business_efficiency:=clamp(0.85+float(capacity)*0.10,0.85,1.50)
    var base_output:=max(1,employee_count+capacity-1)
    var output_factor:=employee_factor*business_efficiency*_technology_multiplier()*_property_condition_multiplier()*morale_multiplier
    var cycles:=max(1,int(floor(float(base_output)*output_factor)) )

    var cash:=int(state_adapter.get_value("economy","cash",25000))
    # Timber and energy feed the factory directly; iron first goes through the metal factory.
    var timber_need:=float(cycles)
    var iron_need:=float(cycles) * 2.0
    var energy_need:=float(cycles) * 2.5
    var orders:=[]
    if supply_chain.stock("timber") < timber_need: orders.append({"resource":"timber","amount":max(0.0,timber_need-supply_chain.stock("timber"))})
    if supply_chain.stock("iron") < iron_need: orders.append({"resource":"iron","amount":max(0.0,iron_need-supply_chain.stock("iron"))})
    if supply_chain.stock("energy") < energy_need: orders.append({"resource":"energy","amount":max(0.0,energy_need-supply_chain.stock("energy"))})
    if not orders.is_empty():
        var transport_level:=int(state_adapter.get_value("supply_chain","transport_level",1))
        var delivery:=supply_chain.procure_bundle(orders,cash,transport_level)
        if not delivery["ok"]:
            state_adapter.message("Factory stopped: supply delivery failed (%s)." % str(delivery.get("reason","unknown")))
            return
        cash -= int(delivery["cost"])
        state_adapter.set_value("economy","cash",cash)
        state_adapter.log_message("SUPPLY: market resources delivered to warehouse for production.")

    var metal_have:=supply_chain.stock("metal")
    var metal_needed:=float(cycles) * 0.5
    if metal_have < metal_needed:
        var metal_cycles:=int(ceil((metal_needed-metal_have) / 1.0))
        var metal_result:=supply_chain.process_iron_to_metal(metal_cycles)
        if not metal_result["ok"]:
            state_adapter.message("Metal Factory stopped: not enough Iron/Energy."); return

    var input_result:=supply_chain.consume_furniture_inputs(cycles)
    if not input_result["ok"]:
        state_adapter.message("Furniture Factory stopped: warehouse inputs are too low."); return

    # Production is still recorded in the existing production state so the rest of the game
    # can sell inventory normally. The supply chain remains the physical source of inputs.
    var quality:=clamp(int(round(72.0 + employee_factor * 5.0 + morale_multiplier * 4.0 + _technology_multiplier() * 3.0 + randi_range(-3,4))),30,100)
    var output:=max(1,cycles - int(floor(float(cycles) * 0.08)))
    production.system.finished_goods += output
    production.system.inventory["goods"] = production.system.finished_goods
    production.system.last_run={"product":"furniture","stage":"manufacturing","cycles":cycles,"output":output,"quality":quality,"resources":{"timber":float(cycles),"metal":float(cycles)*0.5,"energy":float(cycles)*2.0},"resource_requirements":{"timber":1.0,"metal":0.5,"energy":2.0},"production_time":2.0,"employee_capacity":2,"base_price":220,"operating_cost":0,"reputation_effect":2}
    supply_chain.receive_furniture(output)
    state_adapter.set_value("production", "finished_goods", production.system.finished_goods)
    state_adapter.message("Furniture Factory produced %d furniture at quality %d. Staff efficiency %.2fx." % [output,quality,output_factor])
    state_adapter.log_message("FACTORY: Timber -> Furniture Factory -> Warehouse -> Customer; %d furniture produced." % output)
