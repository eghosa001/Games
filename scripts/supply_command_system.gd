extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")
const SupplyChain = preload("res://scripts/supply_chain_system.gd")

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var rivals = Rivals.new()
var chain = SupplyChain.new()

func _ready() -> void:
    add_child(state_adapter)
    add_child(chain)
    chain.set_economy(economy)

func set_chain(value) -> void:
    if value != null:
        chain = value
        chain.set_economy(economy)

func cycle_supplier() -> void:
    var choice: int = (int(state_adapter.get_value("supply_chain", "supplier_choice", 0)) + 1) % 3
    state_adapter.set_value("supply_chain", "supplier_choice", choice)

func procure(resource: String, amount: float, cash: int, transport_level: int = 1) -> Dictionary:
    return chain.procure(resource, amount, cash, transport_level)

func procure_bundle(orders: Array, cash: int, transport_level: int = 1) -> Dictionary:
    return chain.procure_bundle(orders, cash, transport_level)

func process_iron_to_metal(cycles: int = 1) -> Dictionary:
    return chain.process_iron_to_metal(cycles)

func can_make_furniture(cycles: int = 1) -> Dictionary:
    return chain.can_make_furniture(cycles)

func consume_furniture_inputs(cycles: int) -> Dictionary:
    return chain.consume_furniture_inputs(cycles)

func receive_furniture(amount: int) -> void:
    chain.receive_furniture(amount)

func sell_furniture(amount: int, price: int) -> Dictionary:
    return chain.sell_furniture(amount, price)

func capture_state() -> Dictionary:
    return {"system_version": 1, "supplier_choice": state_adapter.get_value("supply_chain", "supplier_choice", 0), "chain": chain.capture_state()}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    state_adapter.set_value("supply_chain", "supplier_choice", int(snapshot.get("supplier_choice", 0)))
    var chain_snapshot = snapshot.get("chain", {})
    if chain_snapshot is Dictionary:
        chain.restore_state(chain_snapshot)
