extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Economy = preload("res://scripts/economy.gd")
const Rivals = preload("res://scripts/competitors.gd")

var state_adapter = DomainSystem.new()
var economy = Economy.new()
var rivals = Rivals.new()

func _ready() -> void:
    add_child(state_adapter)

func cycle_supplier() -> void:
    var choice := (int(state_adapter.get_value("supply_chain", "supplier_choice", 0)) + 1) % 3
    state_adapter.set_value("supply_chain", "supplier_choice", choice)
    state_adapter.message("Supplier tier %d selected: lower price tiers trade reliability for savings." % (choice + 1))

func buy_inputs() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var supplier := int(state_adapter.get_value("supply_chain", "supplier_choice", 0))
    var rival := int(state_adapter.get_value("competitors", "selected_rival", 0))
    var district := int(state_adapter.get_value("regions", "selected_district", 0))
    var orders := [{"resource":"materials","amount":12},{"resource":"packaging","amount":12},{"resource":"fuel","amount":12}]
    var deal := rivals.deal_bonus(rival)
    var pressure := rivals.supplier_pressure(district)
    var result = economy.buy_bundle(orders, int(state_adapter.get_value("economy", "cash", 25000)), supplier, float(deal["discount"]), pressure * 120)
    if not result["ok"]:
        state_adapter.message("%s could not complete delivery." % result.get("supplier", "Supplier"))
        state_adapter.log_message("SUPPLY FAILURE: %s." % result.get("supplier", "Supplier")); return
    state_adapter.set_value("economy", "cash", int(state_adapter.get_value("economy", "cash", 25000)) - int(result["cost"]))
    state_adapter.log_message("SUPPLY ORDER: 12 units of every input; district pressure %d." % pressure)
    state_adapter.message("Inputs delivered. Supplier pressure: %d." % pressure)
