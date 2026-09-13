# ===============================================
# File: scripts/main.gd
# ===============================================
extends Node2D

const GameplayCommandSystem = preload("res://scripts/gameplay_command_system.gd")
var command_system: GameplayCommandSystem
var stages: Array = [["Neglected", 0, 0], ["Cleaned", 25, 500], ["Repaired", 50, 1500], ["Painted", 75, 900], ["Operational", 100, 1200]]
var economy:
    get:
        return command_system.supply_system.economy if command_system else null
var expansion:
    get:
        return command_system.expansion_system.expansion if command_system else null
var rivals:
    get:
        return command_system.relationship_system.rivals if command_system else null
var districts:
    get:
        return command_system.expansion_system.districts if command_system else null
func _game_state(): return get_node_or_null("/root/RenewGameState")
func _finance(): return get_node_or_null("/root/RenewFinanceSystem")
func _read(domain: String, key: String, default_value = null):
    var state = _game_state(); return state.get_value(domain, key, default_value) if state else default_value
func _write(domain: String, key: String, value) -> void:
    var state = _game_state()
    if state: state.set_value(domain, key, value)
func _money(value: int) -> String: return String.num_int64(value)
func _log(text: String) -> void:
    var logs = _read("company", "log_lines", [])
    if not logs is Array: logs = []
    logs = logs.duplicate(true); logs.append(text)
    if logs.size() > 100: logs.pop_front()
    _write("company", "log_lines", logs)
func _next_cost() -> int:
    if stage == "Operational": return 0
    for index in range(stages.size()):
        if stages[index][0] == stage and index + 1 < stages.size(): return int(stages[index + 1][2])
    return 0
var cash: int:
    get:
        var finance = _finance()
        if finance != null and finance.has_method("available_cash"): return int(finance.available_cash())
        return int(_read("economy", "cash", 0))
    set(value):
        var finance = _finance()
        if finance != null and finance.has_method("available_cash"):
            var current := int(finance.available_cash()); var target := int(value); var delta := target - current
            if delta > 0 and finance.has_method("receive"): finance.receive(delta, "legacy Main cash credit")
            elif delta < 0 and finance.has_method("spend"): finance.spend(-delta, "legacy Main cash debit")
            return
        _write("economy", "cash", int(value))
var reputation: int:
    get:
        return _read("player", "reputation", 0)
    set(value):
        _write("player", "reputation", value)
var day: int:
    get:
        return _read("player", "day", 1)
    set(value):
        _write("player", "day", value)
var debt: int:
    get:
        return _read("finance", "debt", 0)
    set(value):
        _write("finance", "debt", value)
var loan_payment: int:
    get:
        return _read("finance", "loan_payment", 0)
    set(value):
        _write("finance", "loan_payment", value)
var owned: bool:
    get:
        return _read("properties", "owned", false)
    set(value):
        _write("properties", "owned", value)
var inspected: bool:
    get:
        return _read("properties", "inspected", false)
    set(value):
        _write("properties", "inspected", value)
var restoration: int:
    get:
        return _read("properties", "restoration", 0)
    set(value):
        _write("properties", "restoration", value)
var stage: String:
    get:
        return _read("properties", "stage", "Neglected")
    set(value):
        _write("properties", "stage", value)
var business_open: bool:
    get:
        return _read("businesses", "business_open", false)
    set(value):
        _write("businesses", "business_open", value)
var employees: int:
    get:
        return command_system.employee_system.get_active_employee_count() if command_system else 0
var capacity_level: int:
    get:
        return _read("businesses", "capacity_level", 1)
    set(value):
        _write("businesses", "capacity_level", value)
var marketing_level: int:
    get:
        return _read("businesses", "marketing_level", 0)
    set(value):
        _write("businesses", "marketing_level", value)
var player_price: int:
    get:
        return _read("businesses", "player_price", 110)
    set(value):
        _write("businesses", "player_price", value)
var finished_goods: int:
    get:
        return _read("production", "finished_goods", 0)
    set(value):
        _write("production", "finished_goods", value)
var last_sales: int:
    get:
        return _read("economy", "last_sales", 0)
    set(value):
        _write("economy", "last_sales", value)
var last_profit: int:
    get:
        return _read("economy", "last_profit", 0)
    set(value):
        _write("economy", "last_profit", value)
var total_profit: int:
    get:
        return _read("economy", "total_profit", 0)
    set(value):
        _write("economy", "total_profit", value)
var relationship: int:
    get:
        return _read("competitors", "relationship", 15)
    set(value):
        _write("competitors", "relationship", value)
var selected_rival: int:
    get:
        return _read("competitors", "selected_rival", 0)
    set(value):
        _write("competitors", "selected_rival", value)
var selected_expansion: int:
    get:
        return _read("branches", "selected_expansion", 0)
    set(value):
        _write("branches", "selected_expansion", value)
var supplier_choice: int:
    get:
        return _read("supply_chain", "supplier_choice", 0)
    set(value):
        _write("supply_chain", "supplier_choice", value)
var contract_days: int:
    get:
        return _read("contracts", "contract_days", 0)
    set(value):
        _write("contracts", "contract_days", value)
var contract_bonus: int:
    get:
        return _read("contracts", "contract_bonus", 0)
    set(value):
        _write("contracts", "contract_bonus", value)
var acquisition_count: int:
    get:
        return _read("ownership", "acquisition_count", 0)
    set(value):
        _write("ownership", "acquisition_count", value)
var transport_level: int:
    get:
        return _read("supply_chain", "transport_level", 1)
    set(value):
        _write("supply_chain", "transport_level", value)
var transport_capacity: int:
    get:
        return _read("supply_chain", "transport_capacity", 40)
    set(value):
        _write("supply_chain", "transport_capacity", value)
var selected_district: int:
    get:
        return _read("regions", "selected_district", 0)
    set(value):
        _write("regions", "selected_district", value)
var message: String:
    get:
        return _read("company", "message", "")
    set(value):
        _write("company", "message", value)
var log_lines: Array:
    get:
        var logs = _read("company", "log_lines", [])
        return logs if logs is Array else []
    set(value):
        _write("company", "log_lines", value)
func _ready():
    command_system = GameplayCommandSystem.new(); command_system.name = "GameplayCommandSystem"; add_child(command_system); command_system.initialize()
func inspect_property() -> void: command_system.inspect_property()
func acquire_property() -> void: command_system.acquire_property()
func restore_property() -> void: command_system.restore_property()
func sell_property() -> void: command_system.sell_property()
func lease_property() -> void: command_system.lease_property()
func open_business() -> void: command_system.open_business()
func choose_business_purpose(index: int) -> void: command_system.choose_business_purpose(index)
func create_business() -> void: command_system.create_business()
func get_business_purposes() -> Array: return command_system.business_system.get_business_purposes()
func buy_inputs() -> void: command_system.buy_inputs()
func produce_goods() -> void: command_system.produce_goods()
func hire_employee() -> Dictionary: return command_system.hire_employee()
func train_employee(employee_id: String) -> void: command_system.train_employee(employee_id)
func promote_employee(employee_id: String) -> void: command_system.promote_employee(employee_id)
func assign_employee(employee_id: String, assignment: String) -> void: command_system.assign_employee(employee_id, assignment)
func fire_employee(employee_id: String) -> void: command_system.fire_employee(employee_id)
func appoint_executive(employee_id: String) -> Dictionary: return command_system.appoint_executive(employee_id)
func upgrade_business() -> void: command_system.upgrade_business()
func marketing_campaign() -> void: command_system.marketing_campaign()
func change_price() -> void: command_system.change_price()
func cycle_supplier() -> void: command_system.cycle_supplier()
func sign_contract() -> void: command_system.sign_contract()
func haggle_contract() -> void: command_system.haggle_contract()
func sign_exclusive_contract() -> void: command_system.sign_exclusive_contract()
func sign_construction_contract() -> void: command_system.sign_construction_contract()
func sign_government_contract() -> void: command_system.sign_government_contract()
func sign_export_contract() -> void: command_system.sign_export_contract()
func buy_international() -> void: command_system.buy_international()
func cancel_active_contract(reason: String = "player cancelled") -> void: command_system.cancel_active_contract(reason)
func take_loan() -> void: command_system.take_loan()
func repay_loan() -> void: command_system.repay_loan()
func request_investment() -> void: command_system.request_investment()
func accept_investment() -> void: command_system.accept_investment()
func decline_investment() -> void: command_system.decline_investment()
func invest_term() -> void: command_system.invest_term()
func pay_dividend() -> void:
    var corporate = get_node_or_null("World/Corporate")
    if corporate != null and corporate.has_method("pay_dividend"): corporate.pay_dividend()
func go_public() -> void:
    var corporate = get_node_or_null("World/Corporate")
    if corporate != null and corporate.has_method("go_public"): corporate.go_public()
func cap_table() -> void:
    var corporate = get_node_or_null("World/Corporate")
    if corporate != null and corporate.has_method("cap_table_text"): message = str(corporate.cap_table_text())
func select_rival(index: int) -> void: command_system.select_rival(index)
func select_expansion(index: int) -> void: command_system.select_expansion(index)
func select_district(index: int) -> void: command_system.select_district(index)
func improve_alliance() -> void: command_system.improve_alliance()
func send_envoy_gift() -> void: command_system.send_envoy_gift()
func make_alliance_offer() -> void: command_system.make_alliance_offer()
func compete_alliance() -> void: command_system.compete_alliance()
func victory_progress() -> void: command_system.victory_progress()
func found_new_company() -> Dictionary: return command_system.found_new_company()
func identity_status() -> void: command_system.identity_status()
func reputation_status() -> void: command_system.reputation_status()
func world_power() -> void: command_system.world_power()
func check_notifications() -> void: command_system.check_notifications()
func propose_supply_deal() -> void: command_system.propose_supply_deal()
func propose_customer_partnership() -> void: command_system.propose_customer_partnership()
func negotiate_selected_acquisition() -> void: command_system.negotiate_selected_acquisition()
func buy_rival_shares() -> void: command_system.buy_rival_shares()
func sell_rival_shares() -> void: command_system.sell_rival_shares()
func start_acquisition_battle() -> void: command_system.start_acquisition_battle()
func raise_acquisition_bid() -> void: command_system.raise_acquisition_bid()
func walk_away_acquisition() -> void: command_system.walk_away_acquisition()
func reject_selected_acquisition() -> void: command_system.reject_selected_acquisition()
func buy_expansion() -> void: command_system.buy_expansion()
func upgrade_transport() -> Dictionary: return command_system.upgrade_transport()
func next_region() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("next_region"): controller.next_region()
func previous_region() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("previous_region"): controller.previous_region()
func establish_region() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("establish_region"): controller.establish_region()
func upgrade_regional_infrastructure() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("upgrade_infrastructure"): controller.upgrade_infrastructure()
func establish_trade_route() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("establish_trade_route"): controller.establish_trade_route()
func dispatch_goods() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("dispatch_goods"): controller.dispatch_goods()
func charter_basin() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("charter_basin"): controller.charter_basin()
func charter_valley() -> void:
    var controller = get_node_or_null("World/RegionController")
    if controller != null and controller.has_method("charter_valley"): controller.charter_valley()
func infra_build() -> void:
    var panel = get_node_or_null("UI/InfrastructurePanel")
    if panel != null and panel.has_method("build_selected"): panel.build_selected()
func infra_type() -> void:
    var panel = get_node_or_null("UI/InfrastructurePanel")
    if panel != null and panel.has_method("cycle_type"): panel.cycle_type()
func infra_repair() -> void:
    var panel = get_node_or_null("UI/InfrastructurePanel")
    if panel != null and panel.has_method("repair_damaged"): panel.repair_damaged()
func upgrade_expansion() -> void: command_system.upgrade_expansion()
func acquire_rival_asset() -> void: command_system.acquire_rival_asset()
func advance_day() -> void: command_system.advance_day()
func save_game() -> void:
    _set_runtime_save_state(); command_system.save_game()
func load_game() -> void:
    command_system.load_game(); _restore_runtime_state()
func _set_runtime_save_state() -> void:
    if command_system == null: return
    var expansion_system = command_system.expansion_system
    if expansion_system != null and expansion_system.has_method("capture_state"): _write("branches", "expansion", expansion_system.capture_state())
func _restore_runtime_state() -> void:
    if command_system == null: return
    var expansion_system = command_system.expansion_system
    var saved_expansion = _read("branches", "expansion", {})
    if expansion_system != null and expansion_system.has_method("restore_state") and saved_expansion is Dictionary and not saved_expansion.is_empty(): expansion_system.restore_state(saved_expansion)
func research_technology(id: String) -> void:
    command_system.research_technology(id)
func research_next_technology() -> void:
    command_system.research_next_technology()
func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    if event.shift_pressed:
        match event.keycode:
            KEY_1: research_technology("efficient_production")
            KEY_2: research_technology("better_logistics")
            KEY_3: research_technology("market_analysis")
            KEY_4: research_technology("automation")
            KEY_5: research_technology("advanced_materials")
            KEY_6: research_technology("supply_optimization")
            KEY_7: research_technology("smart_factory")
            KEY_8: research_technology("advanced_logistics")
            KEY_9: research_technology("premium_manufacturing")
            KEY_0: research_next_technology()
        return
    match event.keycode:
        KEY_I: inspect_property()
        KEY_A: acquire_property()
        KEY_R: restore_property()
        KEY_B: open_business()
        KEY_P: produce_goods()
        KEY_H: hire_employee()
        KEY_U: upgrade_business()
        KEY_M: marketing_campaign()
        KEY_C: change_price()
        KEY_S: cycle_supplier()
        KEY_O: select_rival(selected_rival + 1)
        KEY_L: improve_alliance()
        KEY_F: compete_alliance()
        KEY_G: victory_progress()
        KEY_D: found_new_company()
        KEY_T: make_alliance_offer()
        KEY_Q: upgrade_expansion()
        KEY_K: sign_contract()
        KEY_J: take_loan()
        KEY_V: repay_loan()
        KEY_N: advance_day()
        KEY_F5: save_game()
        KEY_F9: load_game()
        KEY_TAB: buy_inputs()
        KEY_X: buy_international()
        KEY_Z: buy_expansion()
