extends Node2D

# RENEW Prototype 07.
# Main is the presentation/controller boundary: input, command dispatch,
# screen/UI refresh hooks, and compatibility accessors only.
# Gameplay mutations live in GameplayCommandSystem and persist through GameState.
const GameplayCommandSystem = preload("res://scripts/gameplay_command_system.gd")
const CustomerSegmentsUI = preload("res://scripts/customer_segments_ui.gd")

var command_system = GameplayCommandSystem.new()
var customer_segments_ui = CustomerSegmentsUI.new()

var cash: int:
    get: return _state_value("economy", "cash", 25000)
    set(value): _set_state_value("economy", "cash", value)
var reputation: int:
    get: return _state_value("player", "reputation", 0)
    set(value): _set_state_value("player", "reputation", value)
var day: int:
    get: return _state_value("player", "day", 1)
    set(value): _set_state_value("player", "day", value)
var debt: int:
    get: return _state_value("finance", "debt", 0)
    set(value): _set_state_value("finance", "debt", value)
var loan_payment: int:
    get: return _state_value("finance", "loan_payment", 0)
    set(value): _set_state_value("finance", "loan_payment", value)
var owned: bool:
    get: return _state_value("properties", "owned", false)
    set(value): _set_state_value("properties", "owned", value)
var inspected: bool:
    get: return _state_value("properties", "inspected", false)
    set(value): _set_state_value("properties", "inspected", value)
var restoration: int:
    get: return _state_value("properties", "restoration", 0)
    set(value): _set_state_value("properties", "restoration", value)
var stage: String:
    get: return _state_value("properties", "stage", "Neglected")
    set(value): _set_state_value("properties", "stage", value)
var business_open: bool:
    get: return _state_value("businesses", "business_open", false)
    set(value): _set_state_value("businesses", "business_open", value)
var employees: int:
    get: return command_system.employee_system.get_active_employee_count() if command_system != null else 0
    set(_value): pass
var capacity_level: int:
    get: return _state_value("businesses", "capacity_level", 1)
    set(value): _set_state_value("businesses", "capacity_level", value)
var marketing_level: int:
    get: return _state_value("businesses", "marketing_level", 0)
    set(value): _set_state_value("businesses", "marketing_level", value)
var player_price: int:
    get: return _state_value("businesses", "player_price", 110)
    set(value): _set_state_value("businesses", "player_price", value)
var finished_goods: int:
    get: return _state_value("production", "finished_goods", 0)
    set(value): _set_state_value("production", "finished_goods", value)
var last_sales: int:
    get: return _state_value("economy", "last_sales", 0)
    set(value): _set_state_value("economy", "last_sales", value)
var last_profit: int:
    get: return _state_value("economy", "last_profit", 0)
    set(value): _set_state_value("economy", "last_profit", value)
var total_profit: int:
    get: return _state_value("economy", "total_profit", 0)
    set(value): _set_state_value("economy", "total_profit", value)
var relationship: int:
    get: return _state_value("competitors", "relationship", 15)
    set(value): _set_state_value("competitors", "relationship", value)
var selected_rival: int:
    get: return _state_value("competitors", "selected_rival", 0)
    set(value): _set_state_value("competitors", "selected_rival", value)
var selected_expansion: int:
    get: return _state_value("branches", "selected_expansion", 0)
    set(value): _set_state_value("branches", "selected_expansion", value)
var supplier_choice: int:
    get: return _state_value("supply_chain", "supplier_choice", 0)
    set(value): _set_state_value("supply_chain", "supplier_choice", value)
var contract_days: int:
    get: return _state_value("contracts", "contract_days", 0)
    set(value): _set_state_value("contracts", "contract_days", value)
var contract_bonus: int:
    get: return _state_value("contracts", "contract_bonus", 0)
    set(value): _set_state_value("contracts", "contract_bonus", value)
var acquisition_count: int:
    get: return _state_value("ownership", "acquisition_count", 0)
    set(value): _set_state_value("ownership", "acquisition_count", value)
var transport_level: int:
    get: return _state_value("supply_chain", "transport_level", 1)
    set(value): _set_state_value("supply_chain", "transport_level", value)
var transport_capacity: int:
    get: return _state_value("supply_chain", "transport_capacity", 40)
    set(value): _set_state_value("supply_chain", "transport_capacity", value)
var selected_district: int:
    get: return _state_value("regions", "selected_district", 0)
    set(value): _set_state_value("regions", "selected_district", value)
var message: String:
    get: return _state_value("company", "message", "Inspect the abandoned warehouse. Your empire starts here.")
    set(value): _set_state_value("company", "message", value)
var log_lines: Array:
    get:
        var value = _state_value("company", "log_lines", [])
        return value.duplicate(true) if value is Array else []
    set(value): _set_state_value("company", "log_lines", value.duplicate(true))

func _game_state(): return get_node_or_null("/root/RenewGameState")
func _state_value(domain: String, key: String, default_value):
    var state = _game_state()
    return default_value if state == null else state.get_value(domain, key, default_value)
func _set_state_value(domain: String, key: String, value) -> void:
    var state = _game_state()
    if state != null: state.set_value(domain, key, value)

func _ready() -> void:
    add_child(command_system)
    command_system.initialize()
    add_child(customer_segments_ui)
    refresh_ui()

func _process(_delta: float) -> void: refresh_ui()
func refresh_ui() -> void: queue_redraw()

func _dispatch(command: String, args: Array = []) -> void:
    if command_system == null: return
    command_system.callv(command, args)
    refresh_ui()

func _input(event: InputEvent) -> void:
    if event is not InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_I: _dispatch("inspect_property")
        KEY_A: _dispatch("acquire_property")
        KEY_R: _dispatch("restore_property")
        KEY_O: _dispatch("open_business")
        KEY_4: _dispatch("choose_business_purpose", [0])
        KEY_5: _dispatch("choose_business_purpose", [1])
        KEY_6: _dispatch("choose_business_purpose", [2])
        KEY_N: _dispatch("advance_day")
        KEY_P: _dispatch("change_price")
        KEY_S: _dispatch("buy_inputs")
        KEY_B: _dispatch("produce_goods")
        KEY_H: _dispatch("hire_employee")
        KEY_U: _dispatch("upgrade_business")
        KEY_M: _dispatch("marketing_campaign")
        KEY_L: _dispatch("improve_alliance")
        KEY_C: _dispatch("make_alliance_offer")
        KEY_E: _dispatch("buy_expansion")
        KEY_Q: _dispatch("upgrade_expansion")
        KEY_K: _dispatch("sign_contract")
        KEY_J: _dispatch("take_loan")
        KEY_V: _dispatch("repay_loan")
        KEY_X: _dispatch("acquire_rival_asset")
        KEY_1: _dispatch("select_rival", [0])
        KEY_2: _dispatch("select_rival", [1])
        KEY_3: _dispatch("select_rival", [2])
        KEY_7: _dispatch("select_expansion", [0])
        KEY_8: _dispatch("select_expansion", [1])
        KEY_9: _dispatch("select_expansion", [2])
        KEY_T: _dispatch("cycle_supplier")
        KEY_F5: _dispatch("save_game")
        KEY_F9: _dispatch("load_game")

func inspect_property() -> void: _dispatch("inspect_property")
func acquire_property() -> void: _dispatch("acquire_property")
func restore_property() -> void: _dispatch("restore_property")
func open_business() -> void: _dispatch("open_business")
func choose_business_purpose(index: int) -> void: _dispatch("choose_business_purpose", [index])
func create_business() -> void: _dispatch("create_business")
func buy_inputs() -> void: _dispatch("buy_inputs")
func produce_goods() -> void: _dispatch("produce_goods")
func hire_employee() -> void: _dispatch("hire_employee")
func upgrade_business() -> void: _dispatch("upgrade_business")
func marketing_campaign() -> void: _dispatch("marketing_campaign")
func change_price() -> void: _dispatch("change_price")
func advance_day() -> void: _dispatch("advance_day")
func cycle_supplier() -> void: _dispatch("cycle_supplier")
func select_rival(index: int) -> void: _dispatch("select_rival", [index])
func select_expansion(index: int) -> void: _dispatch("select_expansion", [index])
func select_district(index: int) -> void: _dispatch("select_district", [index])
func improve_alliance() -> void: _dispatch("improve_alliance")
func make_alliance_offer() -> void: _dispatch("make_alliance_offer")
func propose_supply_deal() -> void: _dispatch("propose_supply_deal")
func propose_customer_partnership() -> void: _dispatch("propose_customer_partnership")
func negotiate_selected_acquisition() -> void: _dispatch("negotiate_selected_acquisition")
func reject_selected_acquisition() -> void: _dispatch("reject_selected_acquisition")
func sign_contract() -> void: _dispatch("sign_contract")
func take_loan() -> void: _dispatch("take_loan")
func repay_loan() -> void: _dispatch("repay_loan")
func buy_expansion() -> void: _dispatch("buy_expansion")
func upgrade_expansion() -> void: _dispatch("upgrade_expansion")
func acquire_rival_asset() -> void: _dispatch("acquire_rival_asset")
func save_game() -> void: _dispatch("save_game")
func load_game() -> void: _dispatch("load_game")
