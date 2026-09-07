extends Node2D

## World-level supply-chain controller (Phase 9).
## Composes the canonical supply-chain model and the supply-contracts ledger so
## rival systems have one stable sibling node to read pressure/rights from.
## Gameplay transactions keep using the GameplayCommandSystem chain; this node
## mirrors the canonical economy and exposes competitor pressure for display
## and market responses. Persistent facts live in GameState.supply_chain.
const SupplyChain = preload("res://scripts/supply_chain_system.gd")
const SupplyContracts = preload("res://scripts/supply_contracts.gd")

var parent = null
var supply = null
var contracts = null

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    supply = SupplyChain.new()
    add_child(supply)
    contracts = SupplyContracts.new()
    _link_economy()

func _process(_delta: float) -> void:
    _link_economy()

func _link_economy() -> void:
    if supply == null:
        return
    if supply.economy != null:
        return
    var game = get_tree().root.get_node_or_null("Renew") if get_tree() != null else null
    if game == null:
        game = parent
    if game == null:
        return
    var command_system = game.get("command_system")
    if command_system != null and command_system.get("supply_system") != null:
        var shared_economy = command_system.supply_system.economy
        if shared_economy != null:
            supply.set_economy(shared_economy)

func capture_state() -> Dictionary:
    return {
        "supply": supply.capture_state() if supply != null and supply.has_method("capture_state") else {},
        "contracts": contracts.snapshot() if contracts != null and contracts.has_method("snapshot") else {},
    }

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    var supply_snapshot = snapshot.get("supply", {})
    if supply != null and supply_snapshot is Dictionary and supply.has_method("restore_state"):
        supply.restore_state(supply_snapshot)
    var contracts_snapshot = snapshot.get("contracts", {})
    if contracts != null and contracts_snapshot is Dictionary and contracts.has_method("load_snapshot"):
        contracts.load_snapshot(contracts_snapshot)
