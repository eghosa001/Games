extends Node

# Phase B/C market layer: recurring market shocks and strategic responses.
# Events now change input economics for a short period, so decisions have lasting consequences.
var game: Node
var market_cycle: Variant = 0
var market_heat: Variant = 0
var active_event: Variant = ""
var event_text: Variant = ""
var event_expiry: Variant = 0
var last_day: Variant = 1
var event_count: Variant = 0
var effect_expiry: Variant = 0
var effect_name: Variant = ""
var events: Variant = [
    {"name":"INPUT SHORTAGE","text":"A supplier disruption is squeezing input availability.","type":"shortage"},
    {"name":"DEMAND BOOM","text":"Demand is surging in your current district.","type":"boom"},
    {"name":"PRICE WAR","text":"A major rival has cut prices to pressure your business.","type":"war"},
    {"name":"REGIONAL CONTRACT","text":"A regional buyer is looking for a reliable growing company.","type":"contract"},
    {"name":"DISTRESSED ASSET","text":"A nearby operator is struggling and may sell an asset cheaply.","type":"asset"}
]

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    _load_state()
    last_day = int(game.day) if game != null else 1

func _process(_delta: float) -> void:
    if game == null:
        return
    var current_day: Variant = int(game.day)
    if current_day != last_day:
        last_day = current_day
        _on_new_day(current_day)

func _on_new_day(current_day: int) -> void:
    market_cycle += 1
    market_heat = clamp(market_heat + (1 if current_day % 2 == 0 else -1), 0, 5)
    if effect_expiry > 0 and current_day >= effect_expiry:
        _clear_effect()
    if active_event != "" and current_day >= event_expiry:
        active_event = ""
        event_text = ""
    if current_day >= 3 and current_day % 3 == 0 and active_event == "":
        _spawn_event()
    _save_state()

func _spawn_event() -> void:
    var event: Dictionary = events[randi() % events.size()]
    active_event = String(event["name"])
    event_text = String(event["text"])
    event_expiry = int(game.day) + 2
    event_count += 1
    _apply_event_pressure(String(event["type"]), int(game.day) + 2)
    game._log("MARKET EVENT: %s — %s" % [active_event, event_text])
    game.message = "%s: %s Choose a response in the WORLD tab." % [active_event, event_text]

func _economy():
    if game == null:
        return null
    return game.get("economy")

func _finance():
    if game == null:
        return null
    var finance = game.get_node_or_null("FinanceSystem")
    if finance == null:
        finance = get_node_or_null("/root/RenewFinanceSystem")
    return finance

func _spend(amount: int, reason: String) -> Dictionary:
    var finance = _finance()
    if finance != null and finance.has_method("spend"):
        return finance.spend(amount, reason)
    return {"ok": false, "message": "Financial system is unavailable."}

func _receive(amount: int, reason: String) -> Dictionary:
    var finance = _finance()
    if finance != null and finance.has_method("receive"):
        return finance.receive(amount, reason)
    return {"ok": false, "message": "Financial system is unavailable."}

func _sync_legacy_cash() -> void:
    var finance = _finance()
    if finance == null or game == null:
        return
    game.cash = int(finance.cash)

func _apply_event_pressure(event_type: String, expiry: int) -> void:
    var economy = _economy()
    if economy == null:
        return
    effect_expiry = expiry
    effect_name = event_type
    economy.clear_market_modifiers()
    match event_type:
        "shortage":
            economy.set_market_modifier("timber", 1.25)
            economy.set_market_modifier("iron", 1.20)
            economy.set_market_modifier("energy", 1.30)
        "boom":
            economy.set_market_modifier("timber", 0.92)
            economy.set_market_modifier("iron", 0.94)
            economy.set_market_modifier("energy", 0.96)
        "war":
            economy.set_market_modifier("iron", 1.12)
        "contract":
            economy.set_market_modifier("timber", 1.05)
        "asset":
            pass

func _clear_effect() -> void:
    var economy = _economy()
    if economy != null:
        economy.clear_market_modifiers()
    effect_expiry = 0
    effect_name = ""

func market_status() -> String:
    if active_event == "":
        if effect_name != "":
            return "Market pressure: %s (temporary input effect)." % effect_name.to_upper()
        return "Market stable — next strategic shock can emerge as the economy grows."
    return "%s: %s" % [active_event, event_text]

func respond_aggressively() -> void:
    _respond("aggressive")

func respond_balanced() -> void:
    _respond("balanced")

func respond_defensively() -> void:
    _respond("defensive")

func _respond(style: String) -> void:
    if game == null or active_event == "":
        if game != null:
            game.message = "No active market event needs a response."
        return
    var event_type: Variant = ""
    for event in events:
        if String(event["name"]) == active_event:
            event_type = String(event["type"])
            break
    var reward: Variant = 0
    var rep: Variant = 0
    var outcome: Variant = ""
    var spend_amount := 0
    var spend_reason := ""
    match event_type:
        "shortage":
            if style == "aggressive":
                spend_amount = 3500
                spend_reason = "market shortage inventory response"
                reward = 1750
                rep = 2
                _set_response_modifier(0.92, 0.92, 0.95)
                outcome = "You secured scarce inventory early."
            elif style == "balanced":
                reward = 1200
                rep = 1
                _set_response_modifier(1.08, 1.06, 1.10)
                outcome = "You rationed supplies and protected cash flow."
            else:
                reward = 500
                rep = -1
                _set_response_modifier(1.18, 1.15, 1.20)
                outcome = "You conserved cash but surrendered some market share."
        "boom":
            if style == "aggressive":
                spend_amount = 2500
                spend_reason = "market boom capacity campaign"
                reward = 6500
                rep = 2
                _set_response_modifier(0.88, 0.90, 0.92)
                outcome = "You spent to capture the demand spike."
            elif style == "balanced":
                reward = 3800
                rep = 2
                _set_response_modifier(0.94, 0.95, 0.96)
                outcome = "You captured the most profitable part of the boom."
            else:
                reward = 1400
                _set_response_modifier(0.98, 0.99, 1.00)
                outcome = "You played safely and kept your cash reserves."
        "war":
            if style == "aggressive":
                spend_amount = 3000
                spend_reason = "price war defensive campaign"
                reward = 4200
                rep = 1
                _set_response_modifier(1.05, 1.04, 1.00)
                outcome = "You answered the price war with a targeted campaign."
            elif style == "balanced":
                reward = 1800
                rep = 1
                _set_response_modifier(1.03, 1.02, 1.00)
                outcome = "You protected margins while keeping customers."
            else:
                rep = -1
                _set_response_modifier(1.08, 1.05, 1.00)
                outcome = "You refused to chase the rival downward."
        "contract":
            if style == "aggressive":
                reward = 5000
                rep = 3
                _set_response_modifier(1.04, 1.03, 1.02)
                outcome = "You committed capacity and won the regional buyer."
            elif style == "balanced":
                reward = 3000
                rep = 2
                _set_response_modifier(1.02, 1.02, 1.01)
                outcome = "You accepted a manageable regional order."
            else:
                reward = 800
                _set_response_modifier(1.00, 1.00, 1.00)
                outcome = "You declined the risk and preserved flexibility."
        "asset":
            if style == "aggressive":
                reward = 4500
                rep = 2
                outcome = "You moved quickly and gained a distressed-asset discount."
            elif style == "balanced":
                reward = 2200
                rep = 1
                outcome = "You negotiated without overextending the company."
            else:
                reward = 500
                outcome = "You kept liquidity instead of buying another asset."
    if spend_amount > 0:
        var spend_result := _spend(spend_amount, spend_reason)
        if not bool(spend_result.get("ok", false)):
            game.message = String(spend_result.get("message", "Market response could not be funded."))
            return
    if int(reward) > 0:
        var receive_result := _receive(int(reward), "market response: %s" % style)
        if not bool(receive_result.get("ok", false)):
            game.message = String(receive_result.get("message", "Market reward could not be posted."))
            return
    _sync_legacy_cash()
    game.reputation = max(0, int(game.reputation) + int(rep))
    game._log("MARKET RESPONSE: %s — +$%s, +%d rep. %s" % [style, game._money(reward), rep, outcome])
    game.message = "%s %s" % [active_event, outcome]
    active_event = ""
    event_text = ""
    event_expiry = 0
    _save_state()

func _set_response_modifier(timber: float, iron: float, energy: float) -> void:
    var economy = _economy()
    if economy == null:
        return
    effect_expiry = int(game.day) + 1
    effect_name = "response"
    economy.set_market_modifier("timber", timber)
    economy.set_market_modifier("iron", iron)
    economy.set_market_modifier("energy", energy)

func snapshot() -> Dictionary:
    return {"market_cycle":market_cycle,"market_heat":market_heat,"active_event":active_event,"event_text":event_text,"event_expiry":event_expiry,"event_count":event_count,"effect_expiry":effect_expiry,"effect_name":effect_name}

func _save_state() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null:
        state.set_value("events", "market_director", snapshot())

func _load_state() -> void:
    var state = get_node_or_null("/root/RenewGameState")
    if state != null:
        var parsed = state.get_value("events", "market_director", {})
        if parsed is Dictionary and not parsed.is_empty():
            market_cycle = int(parsed.get("market_cycle", 0))
            market_heat = int(parsed.get("market_heat", 0))
            active_event = String(parsed.get("active_event", ""))
            event_text = String(parsed.get("event_text", ""))
            event_expiry = int(parsed.get("event_expiry", 0))
            event_count = int(parsed.get("event_count", 0))
            effect_expiry = int(parsed.get("effect_expiry", 0))
            effect_name = String(parsed.get("effect_name", ""))
