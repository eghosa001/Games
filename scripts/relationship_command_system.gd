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
func send_envoy_gift() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("Select a rival to court first."); return
    var rival_id := str(rivals.rivals[selected].get("id", ""))
    var rival_name := str(rivals.rivals[selected].get("name", "rival"))
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000))
    var amount := 5000 if cash >= 20000 else 1000
    if cash < amount: state_adapter.message("Envoy gifts start at $1,000."); return
    var spend: Dictionary = state_adapter.spend(amount, "envoy gift")
    if not bool(spend.get("ok", false)): state_adapter.message(str(spend.get("message", "Insufficient cash for gifts."))); return
    var gain := 12 if amount >= 5000 else 5
    rivals.rivals[selected]["relationship"] = min(100, int(rivals.rivals[selected].get("relationship", 0)) + gain)
    state_adapter.set_value("competitors", "relationship", int(rivals.rivals[selected].get("relationship", 0)))
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if diplomacy != null and diplomacy.has_method("get_trust") and diplomacy.has_method("set_trust"):
        var trust_gain := 15.0 if amount >= 5000 else 8.0
        diplomacy.set_trust("player", rival_id, min(100.0, float(diplomacy.get_trust("player", rival_id)) + trust_gain))
    state_adapter.log_message("DIPLOMACY: envoy gift to %s (-$%s, +%d relations)." % [rival_name, state_adapter.money(amount), gain])
    state_adapter.message("Envoy received at %s. Relations improve." % rival_name)
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
func _holdings() -> Array:
    var lots = state_adapter.game_state().get_value("ownership", "holdings", []) if state_adapter.game_state() != null else []
    return lots if lots is Array else []
func acquire_rival_asset() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival asset is currently available."); return
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000)); var reputation: int = int(state_adapter.get_value("player", "reputation", 0)); var result = rivals.negotiate_acquisition(selected, cash, reputation, _holdings())
    if not bool(result.get("ok", false)): state_adapter.message(result.get("message", "The acquisition could not be completed.")); return
    var cost:=int(result.get("cost",0)); var spend: Dictionary = state_adapter.spend(cost,"rival asset acquisition")
    if not bool(spend.get("ok",false)): state_adapter.message(str(spend.get("message","Insufficient cash."))); return
    state_adapter.set_value("ownership", "acquisition_count", int(state_adapter.get_value("ownership", "acquisition_count", 0)) + 1); state_adapter.set_value("player", "reputation", reputation + 8); state_adapter.message(result.get("message", "Acquisition completed.")); state_adapter.log_message("ACQUISITION: strategic foothold purchased for $%s." % state_adapter.money(cost))
    var retaliation := rivals.retaliation_after_acquisition(selected); state_adapter.log_message("RIVALRY: " + str(retaliation.get("message", "The rival is regrouping.")))
func negotiate_selected_acquisition() -> void: acquire_rival_asset()
func buy_rival_shares() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for a share purchase."); return
    var price := int(rivals.share_price(selected))
    if price <= 0: state_adapter.message("Those shares are not trading right now."); return
    var lot := 10
    var cost := price * lot
    var spend: Dictionary = state_adapter.spend(cost, "rival share purchase")
    if not bool(spend.get("ok", false)): state_adapter.message(str(spend.get("message", "Insufficient cash for shares."))); return
    var lots := _holdings()
    var merged := false
    for holding in lots:
        if holding is Dictionary and str(holding.get("rival_id", "")) == str(rivals.rivals[selected].get("id", "")):
            var total_shares := int(holding.get("shares", 0)) + lot
            var total_paid := float(holding.get("total_paid", 0.0)) + float(cost)
            holding["shares"] = total_shares
            holding["total_paid"] = total_paid
            holding["avg_price"] = total_paid / float(max(1, total_shares))
            merged = true
    if not merged:
        lots.append({"rival_id": str(rivals.rivals[selected].get("id", "")), "rival_name": str(rivals.rivals[selected].get("name", "rival")), "shares": lot, "avg_price": float(price), "total_paid": float(cost)})
    state_adapter.game_state().set_value("ownership", "holdings", lots)
    state_adapter.log_message("SHARES: bought %d %s shares at $%d (-$%s)." % [lot, rivals.rivals[selected].get("name", "rival"), price, state_adapter.money(cost)])
    state_adapter.message("Bought %d shares. Toehold discounts future takeover bids." % lot)
func sell_rival_shares() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival position is selected."); return
    var rival_id := str(rivals.rivals[selected].get("id", ""))
    var lots := _holdings()
    var index := -1
    for i in range(lots.size()):
        if lots[i] is Dictionary and str(lots[i].get("rival_id", "")) == rival_id:
            index = i
            break
    if index < 0: state_adapter.message("You hold no shares in %s." % rivals.rivals[selected].get("name", "rival")); return
    var price := int(rivals.share_price(selected))
    var shares := int(lots[index].get("shares", 0))
    var proceeds := shares * price
    var gain := proceeds - int(round(float(lots[index].get("total_paid", 0.0))))
    lots.remove_at(index)
    state_adapter.game_state().set_value("ownership", "holdings", lots)
    var receipt: Dictionary = state_adapter.receive(proceeds, "rival share sale")
    if not bool(receipt.get("ok", false)): state_adapter.message("Share sale could not be recorded."); return
    state_adapter.log_message("SHARES: sold %d %s shares for $%s (%s$%s)." % [shares, rivals.rivals[selected].get("name", "rival"), state_adapter.money(proceeds), "+" if gain >= 0 else "-", state_adapter.money(absi(gain))])
    state_adapter.message("Position closed for $%s." % state_adapter.money(proceeds))
func start_acquisition_battle() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival is available for an acquisition battle."); return
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000)); var reputation: int = int(state_adapter.get_value("player", "reputation", 0)); var result = rivals.start_acquisition_battle(selected, cash, reputation)
    state_adapter.message(str(result.get("message", "The bidding could not be opened.")))
    if bool(result.get("ok", false)): state_adapter.log_message("BIDDING WAR: %s (you $%s vs rival $%s, %d rounds)." % [rivals.rivals[selected].get("name", "rival"), state_adapter.money(int(result.get("player_bid", 0))), state_adapter.money(int(result.get("rival_bid", 0))), int(result.get("rounds", 0))])
func raise_acquisition_bid() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No bidding battle is available to raise."); return
    var cash: int = int(state_adapter.get_value("economy", "cash", 25000)); var result = rivals.raise_acquisition_bid(selected, cash)
    if not bool(result.get("ok", false)) and not bool(result.get("won", false)):
        state_adapter.message(str(result.get("message", "The bid could not be raised."))); return
    if bool(result.get("won", false)):
        _complete_battle_win(selected, result)
    else:
        state_adapter.message(str(result.get("message", "Bid raised."))); state_adapter.log_message("BIDDING WAR: " + str(result.get("message", "Bid raised.")))
func walk_away_acquisition() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No bidding battle is available to leave."); return
    var result = rivals.walk_away_acquisition(selected); state_adapter.message(str(result.get("message", "You stepped back.")))
    if bool(result.get("ok", false)): state_adapter.log_message("BIDDING WAR: walked away from %s." % rivals.rivals[selected].get("name", "rival"))
func _complete_battle_win(index: int, result: Dictionary) -> void:
    var cost := int(result.get("cost", 0))
    var spend: Dictionary = state_adapter.spend(cost, "acquisition battle victory")
    if not bool(spend.get("ok", false)): state_adapter.message(str(spend.get("message", "Insufficient cash to close the battle victory."))); return
    var reputation: int = int(state_adapter.get_value("player", "reputation", 0))
    state_adapter.set_value("ownership", "acquisition_count", int(state_adapter.get_value("ownership", "acquisition_count", 0)) + 1); state_adapter.set_value("player", "reputation", reputation + 8); state_adapter.message(str(result.get("message", "Acquisition battle won."))); state_adapter.log_message("ACQUISITION: bidding war won for $%s." % state_adapter.money(cost))
    var retaliation := rivals.retaliation_after_acquisition(index); state_adapter.log_message("RIVALRY: " + str(retaliation.get("message", "The rival is regrouping.")))
func reject_selected_acquisition() -> void:
    var selected := _selected_index()
    if selected < 0: state_adapter.message("No rival acquisition is available to reject."); return
    var result = rivals.reject_acquisition(selected); state_adapter.message(result.get("message", "Acquisition declined.")); state_adapter.log_message("BOARDROOM: " + result.get("message", "Acquisition declined."))