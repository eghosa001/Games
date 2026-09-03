extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Rivals = preload("res://scripts/competitors.gd")

var state_adapter = DomainSystem.new()
var rivals = Rivals.new()

func _ready() -> void:
    add_child(state_adapter)

func select_rival(index: int) -> void:
    if index < 0 or index >= rivals.rivals.size(): return
    state_adapter.set_value("competitors", "selected_rival", index)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[index]["relationship"]))
    state_adapter.message("Selected %s." % rivals.rivals[index]["name"])

func improve_alliance() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var text: Variant = rivals.improve_relationship(selected)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    state_adapter.message(text); state_adapter.log_message("RELATIONSHIP: " + text)

func make_alliance_offer() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var result = rivals.offer_alliance(selected)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    state_adapter.message(result["message"]); state_adapter.log_message("ALLIANCE: " + result["message"])

func propose_supply_deal() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var result = rivals.propose_supply_deal(selected)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    state_adapter.message(result["message"]); state_adapter.log_message("DEAL: " + result["message"])

func propose_customer_partnership() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var result = rivals.propose_customer_partnership(selected)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected]["relationship"]))
    state_adapter.message(result["message"]); state_adapter.log_message("DEAL: " + result["message"])

func acquire_rival_asset() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var cash: Variant = int(state_adapter.get_value("economy", "cash", 25000))
    var reputation: Variant = int(state_adapter.get_value("player", "reputation", 0))
    var result = rivals.negotiate_acquisition(selected, cash, reputation)
    if not result["ok"]: state_adapter.message(result["message"]); return
    state_adapter.set_value("economy", "cash", cash - int(result["cost"]))
    state_adapter.set_value("ownership", "acquisition_count", int(state_adapter.get_value("ownership", "acquisition_count", 0)) + 1)
    state_adapter.set_value("player", "reputation", reputation + 8)
    state_adapter.message(result["message"])
    state_adapter.log_message("ACQUISITION: strategic foothold purchased for $%s." % state_adapter.money(int(result["cost"])))

func negotiate_selected_acquisition() -> void: acquire_rival_asset()
func reject_selected_acquisition() -> void:
    var selected: Variant = int(state_adapter.get_value("competitors", "selected_rival", 0))
    var result = rivals.reject_acquisition(selected)
    state_adapter.message(result["message"]); state_adapter.log_message("BOARDROOM: " + result["message"])
