extends Node

# Phase B/C market layer: recurring market shocks and strategic responses.
# It observes the existing simulation instead of replacing the core economy.
var game: Node
var market_cycle := 0
var market_heat := 0
var active_event := ""
var event_text := ""
var event_expiry := 0
var last_day := 1
var event_count := 0
var events := [
    {"name":"INPUT SHORTAGE","text":"A supplier disruption is squeezing input availability.","type":"shortage"},
    {"name":"DEMAND BOOM","text":"Demand is surging in your current district.","type":"boom"},
    {"name":"PRICE WAR","text":"A major rival has cut prices to pressure your business.","type":"war"},
    {"name":"REGIONAL CONTRACT","text":"A regional buyer is looking for a reliable growing company.","type":"contract"},
    {"name":"DISTRESSED ASSET","text":"A nearby operator is struggling and may sell an asset cheaply.","type":"asset"}
]

func _ready() -> void:
    game = get_parent()
    _load_state()
    last_day = int(game.day) if game != null else 1

func _process(_delta: float) -> void:
    if game == null:
        return
    var current_day := int(game.day)
    if current_day != last_day:
        last_day = current_day
        _on_new_day(current_day)

func _on_new_day(current_day: int) -> void:
    market_cycle += 1
    market_heat = clamp(market_heat + (1 if current_day % 2 == 0 else -1), 0, 5)
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
    game._log("MARKET EVENT: %s — %s" % [active_event, event_text])
    game.message = "%s: %s Choose a response in the WORLD tab." % [active_event, event_text]

func market_status() -> String:
    if active_event == "":
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
    var event_type := ""
    for event in events:
        if String(event["name"]) == active_event:
            event_type = String(event["type"])
            break
    var reward := 0
    var rep := 0
    var outcome := ""
    match event_type:
        "shortage":
            if style == "aggressive":
                var spend := min(int(game.cash), 3500)
                game.cash -= spend
                reward = spend / 2
                rep = 2
                outcome = "You secured scarce inventory early."
            elif style == "balanced":
                reward = 1200
                rep = 1
                outcome = "You rationed supplies and protected cash flow."
            else:
                game.cash += 500
                game.reputation = max(0, int(game.reputation) - 1)
                outcome = "You conserved cash but surrendered some market share."
        "boom":
            if style == "aggressive":
                game.cash -= min(int(game.cash), 2500)
                reward = 6500
                rep = 2
                outcome = "You spent to capture the demand spike."
            elif style == "balanced":
                reward = 3800
                rep = 2
                outcome = "You captured the most profitable part of the boom."
            else:
                reward = 1400
                outcome = "You played safely and kept your cash reserves."
        "war":
            if style == "aggressive":
                game.cash -= min(int(game.cash), 3000)
                reward = 4200
                rep = 1
                outcome = "You answered the price war with a targeted campaign."
            elif style == "balanced":
                reward = 1800
                rep = 1
                outcome = "You protected margins while keeping customers."
            else:
                game.reputation = max(0, int(game.reputation) - 1)
                outcome = "You refused to chase the rival downward."
        "contract":
            if style == "aggressive":
                reward = 5000
                rep = 3
                outcome = "You committed capacity and won the regional buyer."
            elif style == "balanced":
                reward = 3000
                rep = 2
                outcome = "You accepted a manageable regional order."
            else:
                reward = 800
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
    game.cash += reward
    game.reputation += rep
    game._log("MARKET RESPONSE: %s — +$%s, +%d rep. %s" % [style, game._money(reward), rep, outcome])
    game.message = "%s %s" % [active_event, outcome]
    active_event = ""
    event_text = ""
    event_expiry = 0
    _save_state()

func snapshot() -> Dictionary:
    return {"market_cycle":market_cycle,"market_heat":market_heat,"active_event":active_event,"event_text":event_text,"event_expiry":event_expiry,"event_count":event_count}

func _save_state() -> void:
    var file := FileAccess.open("user://renew_market.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(snapshot()))

func _load_state() -> void:
    if not FileAccess.file_exists("user://renew_market.json"):
        return
    var file := FileAccess.open("user://renew_market.json", FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        market_cycle = int(parsed.get("market_cycle", 0))
        market_heat = int(parsed.get("market_heat", 0))
        active_event = String(parsed.get("active_event", ""))
        event_text = String(parsed.get("event_text", ""))
        event_expiry = int(parsed.get("event_expiry", 0))
        event_count = int(parsed.get("event_count", 0))
