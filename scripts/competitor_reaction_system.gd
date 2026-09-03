extends Node
class_name RenewCompetitorReactionSystem

# Phase 15: competitors react to meaningful player actions instead of behaving as
# static NPCs. The system mutates the shared Phase 14 competitor roster.
const SYSTEM_VERSION := 2

var rivals = null
var last_player_price := -1
var last_contract_id := ""
var reaction_history: Array = []

func set_rivals(value) -> void:
    rivals = value

func prime_player_state(player_state: Dictionary) -> void:
    last_player_price = int(player_state.get("player_price", 110))

func observe_and_react(player_state: Dictionary, _supply_chain = null, contract_result: Dictionary = {}) -> Array[String]:
    if rivals == null:
        return []
    var day := int(player_state.get("day", 1))
    var news: Array[String] = []
    var player_price := int(player_state.get("player_price", 110))
    if last_player_price >= 0 and player_price < last_player_price - 1:
        news.append_array(react_to_price_cut(player_price, last_player_price, day))
    last_player_price = player_price

    if not contract_result.is_empty() and bool(contract_result.get("finished", false)):
        var contract: Dictionary = contract_result.get("contract", {})
        if str(contract.get("id", "")) != last_contract_id:
            if str(contract.get("execution_status", "")) == "fulfilled":
                news.append_array(react_to_contract_win(contract, day))
            last_contract_id = str(contract.get("id", ""))
    return news

func react_to_price_cut(player_price: int, previous_price: int, day: int) -> Array[String]:
    var news: Array[String] = []
    var cut := previous_price - player_price
    if cut < 2:
        return news
    for rival in rivals.rivals:
        var strategy := str(rival.get("strategy", ""))
        var old_price := int(rival.get("price", 110))
        if strategy == "low_price_aggressive":
            var target := max(78, player_price - 1)
            rival["price"] = min(old_price, target)
            rival["market_share"] = min(0.60, float(rival.get("market_share", 0.0)) + 0.006)
            rival["retaliation"] = max(int(rival.get("retaliation", 0)), 2)
            news.append("%s matched your price cut and intensified its low-price campaign." % rival.get("name", "A rival"))
        elif strategy == "logistics_advantage" and player_price <= old_price - 8:
            rival["price"] = max(82, old_price - 3)
            news.append("%s responded to your lower price with a targeted price reduction." % rival.get("name", "A rival"))
        elif strategy == "premium_high_reputation":
            rival["reputation"] = min(100, int(rival.get("reputation", 50)) + 1)
            news.append("%s defended its premium position rather than joining the price war." % rival.get("name", "A rival"))
    _remember(day, "price_cut", {"from": previous_price, "to": player_price})
    return news

# Called by the supply/ownership command when the player actually secures timber supply.
func notify_resource_capture(resource: String, amount: int, day: int) -> Array[String]:
    return react_to_resource_capture(resource, amount, day)

func react_to_resource_capture(resource: String, amount: int, day: int) -> Array[String]:
    var news: Array[String] = []
    if resource != "timber" or amount <= 0:
        return news
    for rival in rivals.rivals:
        var strategy := str(rival.get("strategy", ""))
        if strategy == "logistics_advantage":
            if "Alternative Timber Suppliers" not in rival["suppliers"]:
                rival["suppliers"].append("Alternative Timber Suppliers")
            rival["supplier_pressure"] = max(0, int(rival.get("supplier_pressure", 0)) - 1)
            rival["inventory"] = min(300, int(rival.get("inventory", 0)) + 10)
            news.append("%s found alternative timber suppliers after you captured timber supply." % rival.get("name", "A rival"))
        elif strategy == "low_price_aggressive":
            rival["supplier_pressure"] = min(3, int(rival.get("supplier_pressure", 0)) + 1)
            rival["cash"] = max(0, int(rival.get("cash", 0)) - 1200)
            news.append("%s is paying more to replace timber supply you captured." % rival.get("name", "A rival"))
        else:
            rival["inventory"] = max(0, int(rival.get("inventory", 0)) - 5)
            news.append("%s lost some timber access and is adjusting its inventory." % rival.get("name", "A rival"))
    _remember(day, "timber_capture", {"amount": amount})
    return news

func react_to_contract_win(contract: Dictionary, day: int) -> Array[String]:
    var news: Array[String] = []
    var product := str(contract.get("resource_product", "consumer_goods"))
    var customer := str(contract.get("customer_id", "customer"))
    for rival in rivals.rivals:
        var strategy := str(rival.get("strategy", ""))
        var bonus := 0
        if strategy == "low_price_aggressive":
            bonus = 4
            rival["price"] = max(78, int(rival.get("price", 110)) - 2)
        elif strategy == "logistics_advantage":
            bonus = 6
            rival["inventory"] = min(300, int(rival.get("inventory", 0)) + 8)
        elif strategy == "premium_high_reputation":
            bonus = 9
            rival["reputation"] = min(100, int(rival.get("reputation", 50)) + 1)
        rival["future_bid_bonus"] = int(rival.get("future_bid_bonus", 0)) + bonus
        rival["last_contract_target"] = customer
        rival["last_contract_product"] = product
        if bonus > 0:
            news.append("%s raised its future bid pressure after you won the %s contract." % [rival.get("name", "A rival"), product])
    _remember(day, "contract_win", {"customer": customer, "product": product})
    return news

func get_future_bid_modifier(index: int) -> float:
    if rivals == null or index < 0 or index >= rivals.rivals.size():
        return 0.0
    var rival = rivals.rivals[index]
    var bonus := int(rival.get("future_bid_bonus", 0))
    return min(0.25, float(bonus) / 100.0)

func daily_decay() -> void:
    if rivals == null:
        return
    for rival in rivals.rivals:
        rival["future_bid_bonus"] = max(0, int(rival.get("future_bid_bonus", 0)) - 1)

func _remember(day: int, event_type: String, details: Dictionary) -> void:
    reaction_history.append({"day": day, "event": event_type, "details": details})
    if reaction_history.size() > 50:
        reaction_history.pop_front()

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "last_player_price": last_player_price, "last_contract_id": last_contract_id, "reaction_history": reaction_history.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        return
    last_player_price = int(snapshot.get("last_player_price", -1))
    last_contract_id = str(snapshot.get("last_contract_id", ""))
    reaction_history = snapshot.get("reaction_history", []).duplicate(true)
