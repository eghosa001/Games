extends Node2D

# RENEW Corporate Layer - ownership, capital, control and takeover defense.

var parent
var founder_stake := 100.0
var investor_stake := 0.0
var treasury_shares := 0.0
var investor_cash_raised := 0
var dividends_paid := 0
var control_score := 100.0
var takeover_risk := 0.0
var defense_level := 0
var board_trust := 50
var valuation := 25000
var share_price := 25
var last_capital_raise := 0
var takeover_cooldown := 0
var last_processed_day := 1
var investor_name := "Independent Growth Fund"
var board_influence := 0
var takeover_wins := 0
var hostile_attempts := 0

func _ready() -> void:
    parent = get_parent()
    if parent != null: last_processed_day = parent.day
    _load_persistent_state()
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null: return
    if parent.day != last_processed_day:
        last_processed_day = parent.day
        process_day()
    _recalculate()
    queue_redraw()

func _recalculate() -> void:
    var business_value := max(0, int(parent.cash))
    business_value += max(0, int(parent.total_profit)) * 3
    business_value += int(parent.reputation) * 1200
    business_value += int(parent.acquisition_count) * 18000
    if parent.business_open: business_value += 25000
    if parent.stage == "Operational": business_value += 18000
    for p in parent.expansion.properties:
        if p["owned"]: business_value += int(p["cost"]) + int(p["level"]) * 9000
    for r in parent.expansion.resource_sites:
        if r["owned"]: business_value += int(r["cost"]) + int(r["level"]) * 7000
    valuation = max(25000, business_value - int(parent.debt))
    share_price = max(10, int(round(float(valuation) / 1000.0)))
    control_score = clamp(founder_stake + treasury_shares * 0.5 + float(defense_level) * 3.0 + float(board_trust) * 0.1 + float(board_influence) * 0.4, 0.0, 100.0)
    var fragmentation := max(0.0, 100.0 - founder_stake)
    var weakness := 0.0
    if parent.cash < valuation * 0.15: weakness += 18.0
    if parent.debt > valuation * 0.45: weakness += 20.0
    if parent.reputation < 30: weakness += 8.0
    takeover_risk = clamp(fragmentation * 0.65 + weakness - defense_level * 12.0 - board_trust * 0.12, 0.0, 100.0)

func raise_capital() -> void:
    _recalculate()
    if investor_stake >= 35.0:
        parent.message = "Investors already own a large minority stake. Grow the company before issuing more equity."
        return
    var offer := max(10000, int(round(float(valuation) * 0.20)))
    var new_stake := 12.0 if investor_stake < 1.0 else 8.0
    if founder_stake - new_stake < 51.0:
        parent.message = "That raise would put founder control below 51%. Raise less or grow first."
        return
    founder_stake -= new_stake
    investor_stake += new_stake
    investor_cash_raised += offer
    parent.cash += offer
    last_capital_raise = offer
    board_trust = min(100, board_trust + 3)
    parent.reputation += 3
    _persist()
    parent.message = "Capital raised: $%s for %.0f%% equity. Founder control remains %.0f%%." % [parent._money(offer), new_stake, founder_stake]
    parent._log("INVESTMENT: %s invested $%s for %.0f%% equity." % [investor_name, parent._money(offer), new_stake])

func buyback_shares() -> void:
    _recalculate()
    if investor_stake <= 0.0:
        parent.message = "There are no investor shares to buy back."
        return
    var amount := min(5.0, investor_stake)
    var cost := max(5000, int(round(float(valuation) * amount / 100.0 * 1.08)))
    if parent.cash < cost:
        parent.message = "Share buyback requires $%s." % parent._money(cost)
        return
    parent.cash -= cost
    investor_stake -= amount
    founder_stake += amount
    board_trust = min(100, board_trust + 2)
    _persist()
    parent.message = "Bought back %.0f%% of company for $%s. Founder stake: %.0f%%." % [amount, parent._money(cost), founder_stake]
    parent._log("BUYBACK: %.0f%% equity repurchased for $%s." % [amount, parent._money(cost)])

func pay_dividend() -> void:
    _recalculate()
    if investor_stake <= 0.0:
        parent.message = "No outside investors currently hold equity. Retain earnings for growth."
        return
    var payout := max(3000, int(round(float(valuation) * 0.025)))
    if parent.cash < payout:
        parent.message = "Dividend requires $%s in available cash." % parent._money(payout)
        return
    parent.cash -= payout
    dividends_paid += payout
    board_trust = min(100, board_trust + 5)
    _persist()
    parent.message = "Paid $%s dividend. Investors are happier, but growth capital is lower." % parent._money(payout)
    parent._log("DIVIDEND: $%s paid to shareholders." % parent._money(payout))

func strengthen_defense() -> void:
    _recalculate()
    if defense_level >= 3:
        parent.message = "Corporate defense is already at maximum strength."
        return
    var cost := 7000 * (defense_level + 1)
    if parent.cash < cost:
        parent.message = "Corporate defense requires $%s." % parent._money(cost)
        return
    parent.cash -= cost
    defense_level += 1
    board_trust = min(100, board_trust + 6)
    parent.reputation += 2
    _persist()
    parent.message = "Defense upgraded to level %d. Takeover risk reduced." % defense_level
    parent._log("BOARD: corporate defense upgraded to level %d (-$%s)." % [defense_level, parent._money(cost)])

func strategic_ally_defense() -> void:
    _recalculate()
    if parent.reputation < 35:
        parent.message = "You need 35 reputation to call on a strategic ally."
        return
    var ally: Dictionary = parent.rivals.alliance_bonus(parent.selected_rival)
    if float(ally["sales"]) <= 0.0:
        parent.message = "Build a real alliance first; an ordinary relationship is not enough."
        return
    if parent.cash < 5000:
        parent.message = "Defensive partnership requires $5,000."
        return
    parent.cash -= 5000
    board_trust = min(100, board_trust + 12)
    defense_level = min(3, defense_level + 1)
    takeover_cooldown = 10
    _persist()
    parent.message = "Strategic ally committed support. Takeover risk temporarily suppressed."
    parent._log("ALLIANCE DEFENSE: strategic partner backed the company against takeover pressure.")

func influence_board() -> void:
    _recalculate()
    if not parent.business_open:
        parent.message = "Open the business before building a corporate board."
        return
    if parent.reputation < 25:
        parent.message = "Board influence requires 25 reputation."
        return
    if board_influence >= 10:
        parent.message = "Board influence is already at maximum."
        return
    var cost := 3500 + board_influence * 1500
    if parent.cash < cost:
        parent.message = "Board campaign requires $%s." % parent._money(cost)
        return
    parent.cash -= cost
    board_influence += 1
    board_trust = min(100, board_trust + 4)
    parent.reputation += 1
    _persist()
    parent.message = "Board influence increased to %d/10." % board_influence
    parent._log("BOARD CAMPAIGN: secured one additional voting influence for $%s." % parent._money(cost))

func hostile_takeover() -> void:
    _recalculate()
    if parent.reputation < 60:
        parent.message = "Hostile takeovers require 60 reputation. Build your empire first."
        return
    if parent.total_profit < 30000 or parent.acquisition_count < 2:
        parent.message = "You need $30,000 lifetime profit and two acquired assets to challenge a major company."
        return
    if takeover_cooldown > 0:
        parent.message = "The board is cooling down after the last control battle. Wait %d days." % takeover_cooldown
        return
    if parent.rivals.rivals.size() <= 0:
        parent.message = "No major rival is available for a takeover."
        return
    var target = parent.rivals.rivals[0]
    var target_cash := max(25000, int(target["cash"]))
    var offer := max(25000, int(round(float(target_cash) * 0.38)))
    if parent.cash < offer:
        parent.message = "A hostile bid needs $%s in acquisition financing." % parent._money(offer)
        return
    hostile_attempts += 1
    var strength := float(control_score) + float(board_influence * 3) + float(parent.reputation) * 0.25 - float(target_cash) / 50000.0
    var chance := clamp(0.25 + strength / 260.0 - float(defense_level) * 0.04, 0.18, 0.88)
    parent.cash -= offer
    if randf() <= chance:
        target["cash"] = max(0, int(target["cash"]) - offer)
        takeover_wins += 1
        parent.acquisition_count += 1
        parent.reputation += 12
        board_trust = min(100, board_trust + 15)
        board_influence = min(10, board_influence + 2)
        takeover_cooldown = 12
        _persist()
        parent.message = "HOSTILE TAKEOVER SUCCESS: You seized strategic control of %s." % target["name"]
        parent._log("CORPORATE WAR: hostile bid succeeded against %s for $%s. Your empire now controls a rival asset." % [target["name"], parent._money(offer)])
    else:
        parent.reputation = max(0, parent.reputation - 6)
        board_trust = max(0, board_trust - 10)
        takeover_cooldown = 8
        _persist()
        parent.message = "HOSTILE TAKEOVER FAILED: shareholders rejected the bid."
        parent._log("CORPORATE WAR: hostile bid failed after shareholders backed the target.")

func process_day() -> void:
    if parent == null: return
    if takeover_cooldown > 0: takeover_cooldown -= 1
    _recalculate()
    if investor_stake > 0 and parent.day % 7 == 0:
        board_trust = min(100, board_trust + 1)
    if takeover_risk >= 65.0 and takeover_cooldown <= 0 and parent.day % 5 == 0 and parent.rivals.rivals.size() > 0:
        var giant = parent.rivals.rivals[0]
        var pressure := max(0, int(float(takeover_risk) * 700))
        if int(giant["cash"]) > pressure:
            giant["cash"] = max(0, int(giant["cash"]) - pressure / 4)
            takeover_cooldown = 5
            board_trust = max(0, board_trust - 8)
            parent.reputation = max(0, parent.reputation - 2)
            parent._log("TAKEOVER ATTEMPT: The Giant offered shareholders a premium bid. Control is under pressure.")
            parent.message = "TAKEOVER ALERT: The Giant is targeting your company. Defend your control."
    _persist()

func get_summary() -> Dictionary:
    _recalculate()
    return {"valuation":valuation,"share_price":share_price,"founder":founder_stake,"investors":investor_stake,"treasury":treasury_shares,"control":control_score,"risk":takeover_risk,"defense":defense_level,"trust":board_trust,"influence":board_influence,"takeover_wins":takeover_wins,"trust":board_trust,"dividends":dividends_paid}

func save_state() -> Dictionary:
    return {"founder_stake":founder_stake,"investor_stake":investor_stake,"treasury_shares":treasury_shares,"investor_cash_raised":investor_cash_raised,"dividends_paid":dividends_paid,"control_score":control_score,"takeover_risk":takeover_risk,"defense_level":defense_level,"board_trust":board_trust,"valuation":valuation,"share_price":share_price,"last_capital_raise":last_capital_raise,"takeover_cooldown":takeover_cooldown,"last_processed_day":last_processed_day,"board_influence":board_influence,"takeover_wins":takeover_wins,"hostile_attempts":hostile_attempts}

func load_state(state: Dictionary) -> void:
    founder_stake = float(state.get("founder_stake",100.0))
    investor_stake = float(state.get("investor_stake",0.0))
    treasury_shares = float(state.get("treasury_shares",0.0))
    investor_cash_raised = int(state.get("investor_cash_raised",0))
    dividends_paid = int(state.get("dividends_paid",0))
    control_score = float(state.get("control_score",100.0))
    takeover_risk = float(state.get("takeover_risk",0.0))
    defense_level = int(state.get("defense_level",0))
    board_trust = int(state.get("board_trust",50))
    valuation = int(state.get("valuation",25000))
    share_price = int(state.get("share_price",25))
    last_capital_raise = int(state.get("last_capital_raise",0))
    takeover_cooldown = int(state.get("takeover_cooldown",0))
    last_processed_day = int(state.get("last_processed_day",parent.day if parent != null else 1))
    board_influence = int(state.get("board_influence",0))
    takeover_wins = int(state.get("takeover_wins",0))
    hostile_attempts = int(state.get("hostile_attempts",0))

func _persist() -> void:
    var file := FileAccess.open("user://renew_corporate.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(save_state()))
        file.close()

func _load_persistent_state() -> void:
    if not FileAccess.file_exists("user://renew_corporate.json"): return
    var file := FileAccess.open("user://renew_corporate.json", FileAccess.READ)
    if file == null: return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        load_state(parsed)
        if parent != null: last_processed_day = parent.day

func _draw() -> void:
    if parent == null: return
    var panel := Rect2(855, 350, 385, 360)
    draw_rect(panel, Color("101923"), true)
    draw_rect(panel, Color("516b7d"), false, 2.0)
    var s := get_summary()
    draw_string(ThemeDB.fallback_font, Vector2(870, 375), "CORPORATE CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f0f4f7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 399), "Valuation: $%s   Share: $%s" % [parent._money(int(s["valuation"])), parent._money(int(s["share_price"]))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 421), "Founder: %.0f%%   Investors: %.0f%%" % [s["founder"],s["investors"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 443), "Control: %.0f/100   Takeover risk: %.0f/100" % [s["control"],s["risk"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 465), "Defense: %d/3   Board trust: %d" % [s["defense"],s["trust"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 487), "Board influence: %d/10   Takeovers: %d" % [s["influence"],s["takeover_wins"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 512), "ENTER Raise   - Buyback   = Dividend", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fd3ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 533), "; Defense   ' Ally defense", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fd3ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 554), "Board influence   |   Hostile bid", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fd3ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 575), "Ownership is now a strategic resource.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c7d0d7"))

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_ENTER, KEY_KP_ENTER: raise_capital()
        KEY_MINUS: buyback_shares()
        KEY_EQUAL: pay_dividend()
        KEY_SEMICOLON: strengthen_defense()
        KEY_APOSTROPHE: strategic_ally_defense()
        KEY_I: influence_board()
        KEY_H: hostile_takeover()
