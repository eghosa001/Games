extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const Rivals = preload("res://scripts/competitors.gd")

var state_adapter = DomainSystem.new()
var rivals = Rivals.new()

func _ready() -> void:
    add_child(state_adapter)

func _selected_index() -> int:
    if rivals.rivals.is_empty(): return -1
    return clamp(int(state_adapter.get_value("competitors", "selected_rival", 0)), 0, rivals.rivals.size() - 1)
func _selected_rival() -> Dictionary:
    var index := _selected_index()
    return {} if index < 0 else rivals.rivals[index]
func select_rival(index: int) -> void:
    if index < 0 or index >= rivals.rivals.size(): state_adapter.message("No such rival is available."); return
    state_adapter.set_value("competitors", "selected_rival", index); state_adapter.set_value("competitors", "relationship", int(rivals.rivals[index].get("relationship", 0))); state_adapter.message("Selected %s." % rivals.rivals[index].get("name", "rival"))
func improve_alliance() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for relationship actions."); return
    var text: Variant = rivals.improve_relationship(selected); state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected].get("relationship", 0))); state_adapter.message(text); state_adapter.log_message("RELATIONSHIP: " + text)
func make_alliance_offer() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for an alliance offer."); return
    var result = rivals.offer_alliance(selected); state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected].get("relationship", 0))); state_adapter.message(result["message"]); state_adapter.log_message("ALLIANCE: " + result["message"])
func propose_supply_deal() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for a supply deal."); return
    var result = rivals.propose_supply_deal(selected); state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected].get("relationship", 0))); state_adapter.message(result["message"]); state_adapter.log_message("DEAL: " + result["message"])
func propose_customer_partnership() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for a customer partnership."); return
    var result = rivals.propose_customer_partnership(selected); state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected].get("relationship", 0))); state_adapter.message(result["message"]); state_adapter.log_message("DEAL: " + result["message"])
func acquire_rival_asset() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival asset is currently available."); return
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000)); var reputation: int = int(state_adapter.get_value("player", "reputation", 0)); var result = rivals.negotiate_acquisition(selected, cash, reputation)
    if not bool(result.get("ok", false)): state_adapter.message(result.get("message", "The acquisition could not be completed.")); return
    var cost:=int(result.get("cost",0)); var spend:=state_adapter.spend(cost,"rival asset acquisition")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Insufficient cash."))); return
    state_adapter.set_value("ownership", "acquisition_count", int(state_adapter.get_value("ownership", "acquisition_count", 0)) + 1); state_adapter.set_value("player", "reputation", reputation + 8); state_adapter.message(result.get("message", "Acquisition completed.")); state_adapter.log_message("ACQUISITION: strategic foothold purchased for $%s." % state_adapter.money(cost))
func negotiate_selected_acquisition() -> void: acquire_rival_asset()
func reject_selected_acquisition() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival acquisition is available to reject."); return
    var result = rivals.reject_acquisition(selected); state_adapter.message(result.get("message", "Acquisition declined.")); state_adapter.log_message("BOARDROOM: " + result.get("message", "Acquisition declined."))