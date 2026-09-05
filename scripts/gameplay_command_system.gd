extends Node
const PropertySystem=preload("res://scripts/property_system.gd")
const BusinessSystem=preload("res://scripts/business_system_fixed.gd")
const EmployeeCommandSystem=preload("res://scripts/employee_command_system.gd")
const FinanceCommandSystem=preload("res://scripts/finance_command_system.gd")
const SupplyCommandSystem=preload("res://scripts/supply_command_system.gd")
const ContractCommandSystem=preload("res://scripts/contract_command_system.gd")
const RelationshipCommandSystem=preload("res://scripts/relationship_command_system.gd")
const ExpansionCommandSystem=preload("res://scripts/expansion_command_system.gd")
const SaveSystem=preload("res://scripts/save_system.gd")
var property_system=PropertySystem.new();var business_system=BusinessSystem.new();var employee_system=EmployeeCommandSystem.new();var finance_system=FinanceCommandSystem.new();var supply_system=SupplyCommandSystem.new();var contract_system=ContractCommandSystem.new();var relationship_system=RelationshipCommandSystem.new();var expansion_system=ExpansionCommandSystem.new();var technology_system=null;var competitor_reactions=null
func _ready()->void:
    add_child(property_system);add_child(business_system);add_child(employee_system);add_child(finance_system);add_child(supply_system);add_child(contract_system);add_child(relationship_system);add_child(expansion_system)
    technology_system=get_node_or_null("/root/RenewTechnologySystem")
    business_system.economy=supply_system.economy;business_system.employee_system=employee_system;business_system.supply_chain.set_economy(supply_system.economy);supply_system.set_chain(business_system.supply_chain);supply_system.rivals=relationship_system.rivals
    competitor_reactions=get_node_or_null("/root/RenewCompetitorReactionSystem")
    if competitor_reactions!=null:competitor_reactions.set_rivals(relationship_system.rivals)
func _state_value(domain:String,key:String,default_value):var state=get_node_or_null("/root/RenewGameState");return default_value if state==null else state.get_value(domain,key,default_value)
func _set_state(domain:String,key:String,value)->void:var state=get_node_or_null("/root/RenewGameState");if state!=null:state.set_value(domain,key,value)
func _log(text:String)->void:
    var logs=_state_value("company","log_lines",[]);if not logs is Array:logs=[];logs=logs.duplicate(true);logs.append(text);if logs.size()>100:logs.pop_front();_set_state("company","log_lines",logs)
func initialize()->void:
    randomize();relationship_system.rivals._normalize();expansion_system.initialize();employee_system.sync_roster()
    if competitor_reactions!=null:competitor_reactions.set_rivals(relationship_system.rivals);competitor_reactions.prime_player_state(_simulation_state())
    if _state_value("company","log_lines",[]).is_empty():_log("Opportunity discovered: an abandoned warehouse in a growing district.")
func inspect_property()->void:property_system.inspect_property()
func acquire_property()->void:property_system.acquire_property()
func restore_property()->void:property_system.restore_property()
func open_business()->void:business_system.open_business()
func choose_business_purpose(index:int)->void:business_system.choose_business_purpose(index)
func create_business()->void:business_system.create_business()
func buy_inputs()->void:supply_system.buy_inputs()

# Production is a cross-ledger operation. BusinessSystem predates the current
# transaction boundary, so the gameplay command captures every mutable ledger
# before entering it and restores all of them if the operation reports failure.
# This keeps the public gameplay path atomic even when an internal operation
# fails after partially mutating SupplyChain, Production, Economy or Finance.
func _production_transaction_participants()->Array:
    return [
        {"name":"game_state","node":get_node_or_null("/root/RenewGameState")},
        {"name":"finance","node":get_node_or_null("/root/RenewFinanceSystem")},
        {"name":"production","node":business_system.production},
        {"name":"economy","node":supply_system.economy},
        {"name":"supply_chain","node":business_system.supply_chain},
        {"name":"business","node":business_system},
    ]
func _capture_production_transaction()->Dictionary:
    var snapshot:Dictionary={"participants":{}}
    for participant in _production_transaction_participants():
        var node=participant.get("node")
        var name:=str(participant.get("name","unknown"))
        if node==null:return {"ok":false,"message":"Production transaction cannot start: %s is unavailable."%name}
        if not node.has_method("capture_state") or not node.has_method("restore_state"):return {"ok":false,"message":"Production transaction cannot start: %s is not rollback-capable."%name}
        snapshot["participants"][name]=node.capture_state()
    return {"ok":true,"snapshot":snapshot}
func _restore_production_transaction(snapshot:Dictionary)->void:
    var participants:Dictionary=snapshot.get("participants",{})
    var ordered:Array=["business","supply_chain","economy","production","finance","game_state"]
    var by_name:Dictionary={}
    for participant in _production_transaction_participants():by_name[str(participant.get("name","unknown"))]=participant.get("node")
    for name in ordered:
        var node=by_name.get(name);var state=participants.get(name,null)
        if node!=null and state is Dictionary:node.restore_state(state)
func produce_goods()->void:
    var transaction:=_capture_production_transaction()
    if not bool(transaction.get("ok",false)):_set_state("company","message",str(transaction.get("message","Production transaction could not start.")));return
    var before_message:=str(_state_value("company","message",""))
    business_system.produce_goods()
    var after_message:=str(_state_value("company","message",""))
    var success:=after_message.find(" produced ")>=0 and after_message.find("stopped")<0
    if success:return
    _restore_production_transaction(transaction["snapshot"])
    _set_state("company","message",after_message if after_message!=before_message else "Production transaction failed and was rolled back.")
func hire_employee()->void:employee_system.hire_employee()
func upgrade_business()->void:business_system.upgrade_business()
func marketing_campaign()->void:business_system.marketing_campaign()
func change_price()->void:business_system.change_price()
func cycle_supplier()->void:supply_system.cycle_supplier()
func select_rival(index:int)->void:relationship_system.select_rival(index)
func improve_alliance()->void:relationship_system.improve_alliance()
func make_alliance_offer()->void:relationship_system.make_alliance_offer()
func propose_supply_deal()->void:relationship_system.propose_supply_deal()
func propose_customer_partnership()->void:relationship_system.propose_customer_partnership()
func negotiate_selected_acquisition()->void:relationship_system.negotiate_selected_acquisition()
func reject_selected_acquisition()->void:relationship_system.reject_selected_acquisition()
func acquire_rival_asset()->void:relationship_system.acquire_rival_asset()
func select_expansion(index:int)->void:expansion_system.select_expansion(index)
func select_district(index:int)->void:expansion_system.select_district(index)
func buy_expansion()->void:expansion_system.buy_expansion()
func upgrade_transport()->Dictionary:return supply_system.upgrade_transport()
func upgrade_expansion()->void:expansion_system.upgrade_expansion()
func sign_contract()->void:contract_system.sign_contract()
func cancel_active_contract(reason:String="player cancelled")->void:contract_system.cancel_active_contract(reason)
func take_loan()->void:finance_system.take_loan()
func repay_loan()->void:finance_system.repay_loan()
func research_technology(id:String)->void:
    if technology_system==null:return
    if not bool(_state_value("businesses","business_open",false)):_set_state("company","message","Open an operating business before researching technology.");return
    if not technology_system.research(id):return
    _simulate_elapsed_days(int(technology_system.get_last_research_days()))
func research_next_technology()->void:
    if technology_system==null:return
    if not bool(_state_value("businesses","business_open",false)):_set_state("company","message","Open an operating business before researching technology.");return
    if not technology_system.research_next():return
    _simulate_elapsed_days(int(technology_system.get_last_research_days()))
func _simulate_elapsed_days(days:int)->bool:
    var count:=max(0,days)
    for _i in range(count):
        var before_day:=int(_state_value("player","day",1));advance_day();var after_day:=int(_state_value("player","day",before_day))
        if after_day<=before_day:_set_state("company","message","Elapsed-day simulation stopped before completing the research period.");return false
    return true
func _daily_transaction_participants()->Array:
    return [{"name":"game_state","node":get_node_or_null("/root/RenewGameState")},{"name":"finance","node":get_node_or_null("/root/RenewFinanceSystem")},{"name":"production","node":get_node_or_null("/root/RenewProductionSystem")},{"name":"contracts","node":get_node_or_null("/root/RenewContractSystem")},{"name":"rivals","node":relationship_system.rivals},{"name":"economy","node":supply_system.economy},{"name":"supply_chain","node":business_system.supply_chain},{"name":"expansion","node":expansion_system.expansion},{"name":"districts","node":expansion_system.districts},{"name":"employees","node":employee_system},{"name":"business","node":business_system},{"name":"competitor_reactions","node":competitor_reactions}]
func _capture_daily_transaction()->Dictionary:
    var snapshot:Dictionary={"participants":{}}
    for participant in _daily_transaction_participants():
        var node=participant.get("node");var name:=str(participant.get("name","unknown"))
        if node==null:return {"ok":false,"message":"Daily transaction cannot start: %s is unavailable."%name}
        if not node.has_method("capture_state") or not node.has_method("restore_state"):return {"ok":false,"message":"Daily transaction cannot start: %s is not rollback-capable."%name}
        snapshot["participants"][name]=node.capture_state()
    return {"ok":true,"snapshot":snapshot}
func _restore_daily_transaction(snapshot:Dictionary)->void:
    var participants:Dictionary=snapshot.get("participants",{})
    for participant in _daily_transaction_participants():
        var node=participant.get("node");var name:=str(participant.get("name","unknown"))
        if node!=null and participants.get(name,null) is Dictionary:node.restore_state(participants[name])
func advance_day()->void:
    var simulation=get_node_or_null("/root/RenewSimulationSystem");if simulation==null:_set_state("company","message","SimulationSystem is unavailable.");return
    var transaction:=_capture_daily_transaction()
    if not bool(transaction.get("ok",false)):_set_state("company","message",str(transaction.get("message","Daily transaction could not start.")));return
    var context={"economy":supply_system.economy,"rivals":relationship_system.rivals,"events":_events(),"expansion":expansion_system.expansion,"districts":expansion_system.districts,"employee_system":employee_system,"business_system":business_system,"production":business_system.production,"contracts":get_node_or_null("/root/RenewContractSystem")}
    var result:Dictionary=simulation.advance_day(_simulation_state(),context)
    if not bool(result.get("ok",false)):_restore_daily_transaction(transaction["snapshot"]);_set_state("company","message",str(result.get("message","Unable to advance the day.")));return
    _apply_simulation_state(result.get("state",{}));employee_system.sync_roster()
    if technology_system!=null:technology_system.add_daily_research_points(3)
    if competitor_reactions!=null:
        for reaction in competitor_reactions.observe_and_react(_simulation_state(),business_system.supply_chain,result.get("contract",{})):_log("COMPETITOR REACTION: "+reaction)
        competitor_reactions.daily_decay()
    var player_price:=max(1,int(_state_value("businesses","player_price",110)));var units_sold:=int(floor(float(_state_value("economy","last_sales",0))/float(player_price)))
    if units_sold>0:
        var demand_result:Dictionary=supply_system.economy.register_customer_demand("furniture",units_sold)
        if bool(demand_result.get("ok",false)):_log("MARKET: customers bought %d furniture; upstream resource demand increased."%units_sold)
    if business_system.supply_chain.has_method("_sync_production_mirror"):business_system.supply_chain._sync_production_mirror(business_system.supply_chain.warehouse.keys())
func _events():
    if not has_meta("events_model"):set_meta("events_model",load("res://scripts/events.gd").new())
    return get_meta("events_model")
func _simulation_state()->Dictionary:return {"cash":_state_value("economy","cash",25000),"reputation":_state_value("player","reputation",0),"day":_state_value("player","day",1),"debt":_state_value("finance","debt",0),"loan_payment":_state_value("finance","loan_payment",0),"business_open":_state_value("businesses","business_open",false),"employees":employee_system.get_active_employee_count(),"wages":employee_system.get_daily_wage_total(),"capacity_level":_state_value("businesses","capacity_level",1),"marketing_level":_state_value("businesses","marketing_level",0),"player_price":_state_value("businesses","player_price",110),"finished_goods":_state_value("production","finished_goods",0),"last_sales":_state_value("economy","last_sales",0),"last_profit":_state_value("economy","last_profit",0),"total_profit":_state_value("economy","total_profit",0),"relationship":_state_value("competitors","relationship",15),"selected_rival":_state_value("competitors","selected_rival",0),"selected_expansion":_state_value("branches","selected_expansion",0),"supplier_choice":_state_value("supply_chain","supplier_choice",0),"contract_days":_state_value("contracts","contract_days",0),"contract_bonus":_state_value("contracts","contract_bonus",0),"acquisition_count":_state_value("ownership","acquisition_count",0),"transport_level":_state_value("supply_chain","transport_level",1),"transport_capacity":_state_value("supply_chain","transport_capacity",40),"selected_district":_state_value("regions","selected_district",0),"message":_state_value("company","message",""),"log_lines":_state_value("company","log_lines",[]).duplicate(true)}
func _apply_simulation_state(state:Dictionary)->void:
    var map={"cash":["economy","cash"],"reputation":["player","reputation"],"day":["player","day"],"debt":["finance","debt"],"loan_payment":["finance","loan_payment"],"business_open":["businesses","business_open"],"capacity_level":["businesses","capacity_level"],"marketing_level":["businesses","marketing_level"],"player_price":["businesses","player_price"],"finished_goods":["production","finished_goods"],"last_sales":["economy","last_sales"],"last_profit":["economy","last_profit"],"total_profit":["economy","total_profit"],"relationship":["competitors","relationship"],"selected_rival":["competitors","selected_rival"],"selected_expansion":["branches","selected_expansion"],"supplier_choice":["supply_chain","supplier_choice"],"contract_days":["contracts","contract_days"],"contract_bonus":["contracts","contract_bonus"],"acquisition_count":["ownership","acquisition_count"],"transport_level":["supply_chain","transport_level"],"transport_capacity":["supply_chain","transport_capacity"],"selected_district":["regions","selected_district"],"message":["company","message"]}
    for key in map:
        if state.has(key):_set_state(map[key][0],map[key][1],state[key])
    if state.get("log_lines",[]) is Array:_set_state("company","log_lines",state["log_lines"].duplicate(true))
func save_game()->void:
    _set_state("supply_chain","resource_sites",business_system.supply_chain.warehouse_snapshot())
    var state=get_node_or_null("/root/RenewGameState");var snapshot=state.capture() if state!=null else {}
    _set_state("company","message","Game saved." if SaveSystem.save_game(snapshot) else "Save failed.")
func load_game()->void:
    var snapshot=SaveSystem.load_game();if snapshot.is_empty():_set_state("company","message","No save file found.");return
    var state=get_node_or_null("/root/RenewGameState");if state!=null:state.restore(snapshot)
    var roster=_state_value("employees","roster",[]);if roster is Array:employee_system.employee_system.restore_state({"employees":roster})
    var saved_warehouse=_state_value("supply_chain","resource_sites",{});if saved_warehouse is Dictionary:business_system.supply_chain.restore_state({"warehouse":saved_warehouse})
    if competitor_reactions!=null:competitor_reactions.set_rivals(relationship_system.rivals)
    employee_system.sync_roster();_set_state("company","message","Game loaded.")