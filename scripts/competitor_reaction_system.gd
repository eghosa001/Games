extends Node

# Phase 15: competitors react to meaningful player actions instead of behaving as
# static NPCs. Phase 16 adds real daily market-share accounting on top of that roster.
const SYSTEM_VERSION := 3
const MARKET_SHARE_HISTORY_DAYS := [1, 10, 30, 60]

var rivals = null
var last_player_price: Variant = -1
var last_contract_id: Variant = ""
var reaction_history: Array = []
var market_share_history: Dictionary = {}
var current_market_share: Variant = 0.0
var current_player_sales: Variant = 0
var current_competitor_sales: Variant = 0

func set_rivals(value) -> void:
    rivals = value

func prime_player_state(player_state: Dictionary) -> void:
    last_player_price = int(player_state.get("player_price", 110))

func observe_and_react(player_state: Dictionary, _supply_chain = null, contract_result: Dictionary = {}) -> Array[String]:
    if rivals == null:
        return []
    var day: Variant = int(player_state.get("day", 1))
    var news: Array[String] = []
    var player_price: Variant = int(player_state.get("player_price", 110))
    if last_player_price >= 0 and player_price < last_player_price - 1:
        news.append_array(react_to_price_cut(player_price, last_player_price, day))
    last_player_price = player_price
    if not contract_result.is_empty() and bool(contract_result.get("finished", false)):
        var contract: Dictionary = contract_result.get("contract", {})
        if str(contract.get("id", "")) != last_contract_id:
            if str(contract.get("execution_status", "")) == "fulfilled": news.append_array(react_to_contract_win(contract, day))
            last_contract_id = str(contract.get("id", ""))
    news.append_array(record_market_share(player_state, day))
    return news
func react_to_price_cut(player_price: int, previous_price: int, day: int) -> Array[String]:
    var news: Array[String] = []; var cut := previous_price - player_price
    if cut < 2: return news
    for rival in rivals.rivals:
        var strategy: Variant = str(rival.get("strategy", "")); var old_price := int(rival.get("price", 110))
        if strategy == "low_price_aggressive":
            var target: Variant = max(78, player_price - 1); rival["price"] = min(old_price, target); rival["market_share"] = min(0.60, float(rival.get("market_share", 0.0)) + 0.006); rival["retaliation"] = max(int(rival.get("retaliation", 0)), 2); news.append("%s matched your price cut and intensified its low-price campaign." % rival.get("name", "A rival"))
        elif strategy == "logistics_advantage" and player_price <= old_price - 8:
            rival["price"] = max(82, old_price - 3); news.append("%s responded to your lower price with a targeted price reduction." % rival.get("name", "A rival"))
        elif strategy == "premium_high_reputation":
            rival["reputation"] = min(100, int(rival.get("reputation", 50)) + 1); news.append("%s defended its premium position rather than joining the price war." % rival.get("name", "A rival"))
    _remember(day, "price_cut", {"from": previous_price, "to": player_price}); return news
func notify_resource_capture(resource: String, amount: int, day: int) -> Array[String]: return react_to_resource_capture(resource, amount, day)
func react_to_resource_capture(resource: String, amount: int, day: int) -> Array[String]:
    var news: Array[String] = []
    if resource != "timber" or amount <= 0: return news
    for rival in rivals.rivals:
        var strategy: Variant = str(rival.get("strategy", ""))
        if strategy == "logistics_advantage":
            if "Alternative Timber Suppliers" not in rival["suppliers"]: rival["suppliers"].append("Alternative Timber Suppliers")
            rival["supplier_pressure"] = max(0, int(rival.get("supplier_pressure", 0)) - 1); rival["inventory"] = min(300, int(rival.get("inventory", 0)) + 10); news.append("%s found alternative timber suppliers after you captured timber supply." % rival.get("name", "A rival"))
        elif strategy == "low_price_aggressive":
            rival["supplier_pressure"] = min(3, int(rival.get("supplier_pressure", 0)) + 1); rival["cash"] = max(0, int(rival.get("cash", 0)) - 1200); news.append("%s is paying more to replace timber supply you captured." % rival.get("name", "A rival"))
        else:
            rival["inventory"] = max(0, int(rival.get("inventory", 0)) - 5); news.append("%s lost some timber access and is adjusting its inventory." % rival.get("name", "A rival"))
    _remember(day, "timber_capture", {"amount": amount}); return news
func react_to_contract_win(contract: Dictionary, day: int) -> Array[String]:
    var news: Array[String] = []; var product := str(contract.get("resource_product", "consumer_goods")); var customer := str(contract.get("customer_id", "customer"))
    for rival in rivals.rivals:
        var strategy: Variant = str(rival.get("strategy", "")); var bonus := 0
        if strategy == "low_price_aggressive": bonus = 4; rival["price"] = max(78, int(rival.get("price", 110)) - 2)
        elif strategy == "logistics_advantage": bonus = 6; rival["inventory"] = min(300, int(rival.get("inventory", 0)) + 8)
        elif strategy == "premium_high_reputation": bonus = 9; rival["reputation"] = min(100, int(rival.get("reputation", 50)) + 1)
        rival["future_bid_bonus"] = int(rival.get("future_bid_bonus", 0)) + bonus; rival["last_contract_target"] = customer; rival["last_contract_product"] = product
        if bonus > 0: news.append("%s raised its future bid pressure after you won the %s contract." % [rival.get("name", "A rival"), product])
    _remember(day, "contract_win", {"customer": customer, "product": product}); return news
func record_market_share(player_state: Dictionary, day: int) -> Array[String]:
    if rivals == null: return []
    var trading_day: Variant = max(1, day - 1); var player_sales := max(0, int(player_state.get("last_units_sold", 0))); var player_price := max(1, int(player_state.get("player_price", 110))); var competitor_sales_total: int = 0; var competitor_rows: Array = []
    for rival in rivals.rivals:
        var price: Variant = max(1, int(rival.get("price", 110))); var production_capacity := max(0, int(rival.get("production", 0))); var reputation := clamp(float(rival.get("reputation", 50)) / 100.0, 0.0, 1.0); var price_factor := clamp(1.0 + (float(player_price - price) / float(player_price)) * 0.55, 0.55, 1.45); var strategy_factor := 1.0
        match str(rival.get("strategy", "")):
            "low_price_aggressive": strategy_factor = 1.12
            "logistics_advantage": strategy_factor = 1.04
            "premium_high_reputation": strategy_factor = 0.88 + reputation * 0.24
        var daily_sales: Variant = int(round(float(production_capacity) * price_factor * strategy_factor)); var inventory_cap := max(production_capacity, int(rival.get("inventory", production_capacity))); daily_sales = min(daily_sales, max(0, inventory_cap)); rival["last_sales"] = daily_sales; rival["total_sales"] = int(rival.get("total_sales", 0)) + daily_sales; competitor_sales_total += daily_sales; competitor_rows.append({"id": str(rival.get("id", "")), "name": str(rival.get("name", "Rival")), "sales": daily_sales})
    var total_market_sales: int = player_sales + competitor_sales_total
    current_player_sales = player_sales; current_competitor_sales = competitor_sales_total; current_market_share = float(player_sales) / float(max(1, total_market_sales))
    if total_market_sales > 0:
        for rival in rivals.rivals: rival["market_share"] = float(int(rival.get("last_sales", 0))) / float(total_market_sales)
    var snapshot: Variant = {"day": trading_day,"player_sales": player_sales,"competitor_sales": competitor_sales_total,"total_market_sales": total_market_sales,"player_market_share": current_market_share,"competitors": competitor_rows.duplicate(true)}
    market_share_history[str(trading_day)] = snapshot
    for milestone in MARKET_SHARE_HISTORY_DAYS:
        if trading_day == milestone: market_share_history[str(milestone)] = snapshot.duplicate(true)
    var news: Array[String] = []
    if MARKET_SHARE_HISTORY_DAYS.has(trading_day):
        news.append("MARKET SHARE: Day %d — you sold %d of %d market units (%.1f%% share)." % [trading_day, player_sales, total_market_sales, current_market_share * 100.0]); _remember(trading_day, "market_share_milestone", snapshot); _award_progression(trading_day, current_market_share)
    return news
func get_market_share() -> float: return current_market_share
func get_market_share_history() -> Dictionary: return market_share_history.duplicate(true)
func get_rankings() -> Array[Dictionary]:
    var ranking: Array[Dictionary] = [{"id": "player", "name": "Your Company", "market_share": current_market_share, "sales": current_player_sales}]
    if rivals != null:
        for rival in rivals.rivals: ranking.append({"id": str(rival.get("id", "")), "name": str(rival.get("name", "Rival")), "market_share": float(rival.get("market_share", 0.0)), "sales": int(rival.get("last_sales", 0))})
    ranking.sort_custom(func(a, b): return float(a["market_share"]) > float(b["market_share"])); return ranking
func _award_progression(day: int, share: float) -> void:
    var game_state = get_node_or_null("/root/RenewGameState"); if game_state == null: return
    var xp: Variant = int(game_state.get_value("progression", "xp", 0)); var reward := 5
    if day == 10: reward = 10
    elif day == 30: reward = 20
    elif day == 60: reward = 30
    if share >= 0.25: reward += 5
    game_state.set_value("progression", "xp", xp + reward)
func get_future_bid_modifier(index: int) -> float:
    if rivals == null or index < 0 or index >= rivals.rivals.size(): return 0.0
    var rival = rivals.rivals[index]; var bonus := int(rival.get("future_bid_bonus", 0)); return min(0.25, float(bonus) / 100.0)
func daily_decay() -> void:
    if rivals == null: return
    for rival in rivals.rivals: rival["future_bid_bonus"] = max(0, int(rival.get("future_bid_bonus", 0)) - 1)
func _remember(day: int, event_type: String, details: Dictionary) -> void:
    reaction_history.append({"day": day, "event": event_type, "details": details}); if reaction_history.size() > 50: reaction_history.pop_front()
func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION,"last_player_price": last_player_price,"last_contract_id": last_contract_id,"reaction_history": reaction_history.duplicate(true),"market_share_history": market_share_history.duplicate(true),"current_market_share": current_market_share,"current_player_sales": current_player_sales,"current_competitor_sales": current_competitor_sales}
func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    last_player_price = int(snapshot.get("last_player_price", -1)); last_contract_id = str(snapshot.get("last_contract_id", "")); reaction_history = snapshot.get("reaction_history", []).duplicate(true); market_share_history = snapshot.get("market_share_history", {}).duplicate(true); current_market_share = float(snapshot.get("current_market_share", 0.0)); current_player_sales = int(snapshot.get("current_player_sales", 0)); current_competitor_sales = int(snapshot.get("current_competitor_sales", 0))
