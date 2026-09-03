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
    var choice := (int(state_adapter.get_value("supply_chain", "supplier_choice", 0)) + 1) % 3
    state_adapter.set_value("supply_chain", "supplier_choice", choice)
    state_adapter.message("Supplier tier %d selected: lower price tiers trade reliability for savings." % (choice + 1))

func buy_inputs() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var cash:=int(state_adapter.get_value("economy","cash",25000))
    var transport_level:=int(state_adapter.get_value("supply_chain","transport_level",1))
    # V1 deliberately buys the resources used by the complete Timber -> Furniture chain.
    var orders := [{"resource":"timber","amount":12.0},{"resource":"iron","amount":12.0},{"resource":"energy","amount":24.0}]
    var result=chain.procure_bundle(orders,cash,transport_level)
    if not result["ok"]:
        state_adapter.message("Supply delivery failed: %s." % str(result.get("reason","unknown")))
        state_adapter.log_message("SUPPLY FAILURE: %s." % str(result.get("reason","unknown"))); return
    state_adapter.set_value("economy","cash",cash-int(result["cost"]))
    var reaction_system=get_node_or_null("/root/RenewCompetitorReactionSystem")
    if reaction_system != null:
        var day:=int(state_adapter.get_value("player","day",1))
        for reaction in reaction_system.notify_resource_capture("timber",12,day):
            state_adapter.log_message("COMPETITOR REACTION: " + reaction)
    state_adapter.log_message("SUPPLY ORDER: Timber 12, Iron 12, Energy 24 delivered to warehouse.")
    state_adapter.message("Timber, Iron and Energy delivered to the warehouse. Total $%s." % state_adapter.money(int(result["cost"])))
