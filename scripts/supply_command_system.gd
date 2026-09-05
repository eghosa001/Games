extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")
const SupplyChain = preload("res://scripts/supply_chain_system.gd")

const TRANSPORT_BASE_CAPACITY := 40
const TRANSPORT_CAPACITY_PER_LEVEL := 20
const TRANSPORT_UPGRADE_BASE_COST := 5000

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var rivals = Rivals.new()
var chain = SupplyChain.new()

func _ready() -> void:
    add_child(state_adapter)
    add_child(chain)
    chain.set_economy(economy)

func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem")

func _sync_cash(finance: Node) -> int:
    if finance == null:
        return int(state_adapter.get_value("economy", "cash", 25000))
    var cash: int = int(finance.get("cash"))
    state_adapter.set_value("economy", "cash", cash)
    return cash

func set_chain(value) -> void:
    if value != null:
        chain = value
        chain.set_economy(economy)

func cycle_supplier() -> void:
    var choice: int = (int(state_adapter.get_value("supply_chain", "supplier_choice", 0)) + 1) % 3
    state_adapter.set_value("supply_chain", "supplier_choice", choice)
    state_adapter.message("Supplier changed to option %d." % (choice + 1))

func procure(resource: String, amount: float, cash: int, transport_level: int = 1) -> Dictionary:
    return chain.procure(resource, amount, cash, transport_level)

func procure_bundle(orders: Array, cash: int, transport_level: int = 1) -> Dictionary:
    return chain.procure_bundle(orders, cash, transport_level)

func buy_inputs() -> void:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return
    var cash: int = _sync_cash(finance)
    var transport_level: int = int(state_adapter.get_value("supply_chain", "transport_level", 1))
    var finance_before: Dictionary = finance.capture_state()
    var chain_before: Dictionary = chain.capture_state()
    var result: Dictionary = chain.procure_bundle([
        {"resource": "timber", "amount": 10.0},
        {"resource": "iron", "amount": 10.0},
        {"resource": "energy", "amount": 20.0}
    ], cash, transport_level)
    if not bool(result.get("ok", false)):
        state_adapter.message("Input delivery failed (%s)." % str(result.get("reason", "unknown")))
        return
    var procurement_cost: int = int(result.get("cost", 0))
    if procurement_cost < 0:
        chain.restore_state(chain_before)
        finance.restore_state(finance_before)
        _sync_cash(finance)
        state_adapter.message("Input purchase was rejected because its cost was invalid.")
        return
    var spend_result: Dictionary = finance.spend(procurement_cost, "input procurement")
    if not bool(spend_result.get("ok", false)):
        chain.restore_state(chain_before)
        finance.restore_state(finance_before)
        _sync_cash(finance)
        state_adapter.message(str(spend_result.get("message", "Input purchase could not be funded.")))
        return
    _sync_cash(finance)
    state_adapter.message("Inputs delivered to the warehouse.")
    state_adapter.log_message("INPUTS: timber, iron and energy delivered (-$%d)." % procurement_cost)

func process_iron_to_metal(cycles: int = 1) -> Dictionary:
    return chain.process_iron_to_metal(cycles)

func can_make_furniture(cycles: int = 1) -> Dictionary:
    return chain.can_make_furniture(cycles)

func consume_furniture_inputs(cycles: int) -> Dictionary:
    return chain.consume_furniture_inputs(cycles)

func receive_furniture(amount: int) -> void:
    chain.receive_furniture(amount)

func sell_furniture(amount: int, price: int) -> Dictionary:
    var finance := _finance()
    if finance == null:
        return {"ok": false, "reason": "finance_unavailable"}
    var finance_before: Dictionary = finance.capture_state()
    var chain_before: Dictionary = chain.capture_state()
    var sale: Dictionary = chain.sell_furniture(amount, price)
    if not bool(sale.get("ok", false)):
        return sale
    var revenue: int = int(sale.get("revenue", 0))
    if revenue < 0:
        chain.restore_state(chain_before)
        return {"ok": false, "reason": "invalid_revenue"}
    var receipt: Dictionary = finance.receive(revenue, "furniture sale")
    if not bool(receipt.get("ok", false)):
        chain.restore_state(chain_before)
        finance.restore_state(finance_before)
        _sync_cash(finance)
        return {"ok": false, "reason": "finance_failed", "message": str(receipt.get("message", "Furniture sale could not be recorded."))}
    _sync_cash(finance)
    return sale

func upgrade_transport() -> Dictionary:
    var finance := _finance()
    if finance == null:
        state_adapter.message("Finance system unavailable.")
        return {"ok": false, "reason": "finance_unavailable"}
    var current_level: int = max(1, int(state_adapter.get_value("supply_chain", "transport_level", 1)))
    var cost: int = TRANSPORT_UPGRADE_BASE_COST * current_level
    var cash: int = _sync_cash(finance)
    if cash < cost:
        var failure: Dictionary = {"ok": false, "reason": "cash", "cost": cost, "cash": cash, "level": current_level}
        state_adapter.message("Transport upgrade costs %s." % state_adapter.money(cost))
        return failure
    var spend_result: Dictionary = finance.spend(cost, "transport upgrade")
    if not bool(spend_result.get("ok", false)):
        state_adapter.message(str(spend_result.get("message", "Transport upgrade could not be funded.")))
        return {"ok": false, "reason": "cash", "cost": cost, "cash": cash, "level": current_level}
    var new_level: int = current_level + 1
    var capacity: int = TRANSPORT_BASE_CAPACITY + (new_level - 1) * TRANSPORT_CAPACITY_PER_LEVEL
    _sync_cash(finance)
    state_adapter.set_value("supply_chain", "transport_level", new_level)
    state_adapter.set_value("supply_chain", "transport_capacity", capacity)
    state_adapter.log_message("TRANSPORT UPGRADE: Level %d (%d capacity) for %s." % [new_level, capacity, state_adapter.money(cost)])
    state_adapter.message("Transport upgraded to level %d (%d capacity)." % [new_level, capacity])
    return {"ok": true, "cost": cost, "level": new_level, "capacity": capacity}

func capture_state() -> Dictionary:
    return {"system_version": 1, "supplier_choice": state_adapter.get_value("supply_chain", "supplier_choice", 0), "chain": chain.capture_state()}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    state_adapter.set_value("supply_chain", "supplier_choice", int(snapshot.get("supplier_choice", 0)))
    var chain_snapshot = snapshot.get("chain", {})
    if chain_snapshot is Dictionary:
        chain.restore_state(chain_snapshot)
