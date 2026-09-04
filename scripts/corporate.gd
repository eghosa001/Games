extends Node2D

# RENEW Corporate Layer.
# OwnershipSystem is the sole source of truth for shares, holders, voting,
# board seats, dividends, investor confidence and takeover defense.

const OwnershipSystem = preload("res://scripts/ownership_system.gd")
const COMPANY_ID := "renew_co"
const FOUNDER_ID := "founder"
const INVESTOR_ID := "fund_a"

var parent
var ownership: Node
var investor_cash_raised: Variant = 0
var dividends_paid: Variant = 0
var valuation: Variant = 25000
var share_price: Variant = 25
var last_capital_raise: Variant = 0
var takeover_cooldown: Variant = 0
var last_processed_day: Variant = 1
var investor_name: Variant = "Independent Growth Fund"
var board_influence: Variant = 0
var takeover_wins: Variant = 0
var hostile_attempts: Variant = 0
var milestone_level: Variant = 0

# Compatibility accessors: these are derived from OwnershipSystem, never stored here.
var founder_stake: float:
    get: return _ownership_percent(FOUNDER_ID)
var investor_stake: float:
    get: return _ownership_percent(INVESTOR_ID)
var treasury_shares: float:
    get: return float(_company().get("treasury_shares", 0))
var control_score: float:
    get: return _control_score()
var takeover_risk: float:
    get: return _takeover_risk()
var defense_level: int:
    get: return int(_company().get("defense_level", 0))
var board_trust: int:
    get: return int(round(float(_company().get("investor_confidence", 50.0))))

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    ownership = get_tree().root.get_node_or_null("Renew/Systems/OwnershipSystem")
    if ownership == null:
        ownership = OwnershipSystem.new()
        ownership.name = "OwnershipSystem"
        get_tree().root.get_node("Renew/Systems").add_child.call_deferred(ownership)
    if parent != null: last_processed_day = parent.day
    _ensure_company()
    _load_persistent_state()
    _ensure_company()
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null: return
    if parent.day != last_processed_day:
        last_processed_day = parent.day
        process_day()
    _recalculate()
    queue_redraw()

func _company() -> Dictionary:
    if ownership == null: return {}
    return ownership.get_entity(COMPANY_ID)

func _ensure_company() -> void:
    if ownership == null or ownership.has_entity(COMPANY_ID): return
    var created: Variant = ownership.register_entity(COMPANY_ID, OwnershipSystem.ENTITY_COMPANY, 1000000)
    if bool(created.get("ok", false)):
        ownership.issue_shares(COMPANY_ID, FOUNDER_ID, 1000000, OwnershipSystem.VOTE_ORDINARY, "corporate_initialization")

func _ownership_percent(holder_id: String) -> float:
    if ownership == null or not ownership.has_entity(COMPANY_ID): return 0.0
    return ownership.get_ownership_percent(COMPANY_ID, holder_id)

func _voting_percent(holder_id: String) -> float:
    if ownership == null or not ownership.has_entity(COMPANY_ID): return 0.0
    return ownership.get_voting_percent(COMPANY_ID, holder_id)

func _control_score() -> float:
    if ownership == null or not ownership.has_entity(COMPANY_ID): return 0.0
    var founder_vote: Variant = _voting_percent(FOUNDER_ID)
    var board_percent: Variant = ownership.board_control_percent(COMPANY_ID, FOUNDER_ID)
    var defense: Variant = float(_company().get("defense_level", 0))
    var confidence: Variant = float(_company().get("investor_confidence", 50.0))
    return clamp(founder_vote + board_percent * 0.15 + defense * 3.0 + confidence * 0.10, 0.0, 100.0)

func _takeover_risk() -> float:
    if ownership == null or not ownership.has_entity(COMPANY_ID): return 0.0
    var fragmentation: Variant = max(0.0, 100.0 - _voting_percent(FOUNDER_ID))
    var weakness: Variant = 0.0
    if parent != null:
        if parent.cash < valuation * 0.15: weakness += 18.0
        if parent.debt > valuation * 0.45: weakness += 20.0
        if parent.reputation < 30: weakness += 8.0
    var defense: Variant = float(_company().get("defense_level", 0))
    var confidence: Variant = float(_company().get("investor_confidence", 50.0))
    return clamp(fragmentation * 0.65 + weakness - defense * 12.0 - confidence * 0.12, 0.0, 100.0)

func _recalculate() -> void:
    var business_value: Variant = max(0, int(parent.cash))
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

func _milestone_target(level: int) -> String:
    match level:
        1: return "Regional Powerhouse"
        2: return "Corporate Challenger"
        3: return "Industry Player"
        4: return "Giant Killer"
        5: return "RENEW Empire"
    return "Starting Company"

func _check_milestones() -> void:
    var reached: Variant = milestone_level
    if valuation >= 100000: reached = max(reached, 1)
    if parent.reputation >= 50 and parent.acquisition_count >= 2: reached = max(reached, 2)
    if valuation >= 250000 and parent.acquisition_count >= 4: reached = max(reached, 3)
    if takeover_wins >= 1: reached = max(reached, 4)
    if valuation >= 500000 and parent.reputation >= 100 and takeover_wins >= 2: reached = max(reached, 5)
    if reached > milestone_level:
        milestone_level = reached
        parent.message = "MILESTONE UNLOCKED: %s. Your company has entered a new tier of economic power." % _milestone_target(milestone_level)
        parent._log("MILESTONE: %s reached." % _milestone_target(milestone_level))
        _persist()

func show_status() -> void:
    _recalculate()
    var next: Variant = milestone_level + 1
    var next_name: Variant = _milestone_target(next)
    if next > 5:
        parent.message = "ENDGAME: You have reached the RENEW Empire tier. Keep expanding, defending control and challenging the giants."
    else:
        parent.message = "CORPORATE STATUS: %s | Valuation $%s | Founder %.1f%% | Investors %.1f%% | Voting %.1f%% | Risk %.0f%% | Next: %s." % [_milestone_target(milestone_level), parent._money(valuation), founder_stake, investor_stake, _voting_percent(FOUNDER_ID), takeover_risk, next_name]

func raise_capital() -> void:
    _recalculate()
    if investor_stake >= 35.0:
        parent.message = "Investors already own a large minority stake. Grow the company before issuing more equity."
        return
    var offer: Variant = max(10000, int(round(float(valuation) * 0.20)))
    var new_stake: Variant = 12.0 if investor_stake < 1.0 else 8.0
    if founder_stake - new_stake < 51.0:
        parent.message = "That raise would put founder control below 51%. Raise less or grow first."
        return
    var issued: Variant = int(_company().get("issued_shares", 0))
    var quantity: Variant = int(ceil(float(issued) * new_stake / (100.0 - new_stake)))
    var result: Variant = ownership.issue_shares(COMPANY_ID, INVESTOR_ID, quantity, OwnershipSystem.VOTE_ORDINARY, "capital_raise")
    if not bool(result.get("ok", false)):
        parent.message = "Capital raise failed: %s." % str(result.get("error", "unknown"))
        return
    investor_cash_raised += offer
    parent.cash += offer
    last_capital_raise = offer
    ownership.adjust_investor_confidence(COMPANY_ID, 3.0, "capital_raise")
    parent.reputation += 3
    _persist()
    parent.message = "Capital raised: $%s for new equity. Founder voting control remains %.1f%%." % [parent._money(offer), _voting_percent(FOUNDER_ID)]
    parent._log("INVESTMENT: %s invested $%s through OwnershipSystem." % [investor_name, parent._money(offer)])

func buyback_shares() -> void:
    _recalculate()
    if investor_stake <= 0.0:
        parent.message = "There are no investor shares to buy back."
        return
    var amount_pct: Variant = min(5.0, investor_stake)
    var investor_shares: Variant = int(_company().get("holders", {}).get(INVESTOR_ID, {}).get("classes", {}).get(OwnershipSystem.VOTE_ORDINARY, 0))
    var amount: Variant = min(investor_shares, max(1, int(round(float(_company().get("issued_shares", 0)) * amount_pct / 100.0))))
    var cost: Variant = max(5000, int(round(float(valuation) * amount_pct / 100.0 * 1.08)))
    if parent.cash < cost:
        parent.message = "Share buyback requires $%s." % parent._money(cost)
        return
    var result: Variant = ownership.buyback(COMPANY_ID, INVESTOR_ID, amount, float(cost) / max(1, amount), "corporate_buyback")
    if not bool(result.get("ok", false)):
        parent.message = "Buyback failed: %s." % str(result.get("error", "unknown"))
        return
    parent.cash -= cost
    ownership.adjust_investor_confidence(COMPANY_ID, 2.0, "share_buyback")
    _persist()
    parent.message = "Bought back %.1f%% of company for $%s. Founder stake: %.1f%%." % [amount_pct, parent._money(cost), founder_stake]
    parent._log("BUYBACK: OwnershipSystem repurchased %d shares for $%s." % [amount, parent._money(cost)])

func pay_dividend() -> void:
    _recalculate()
    if investor_stake <= 0.0:
        parent.message = "No outside investors currently hold equity. Retain earnings for growth."
        return
    var payout: Variant = max(3000, int(round(float(valuation) * 0.025)))
    if parent.cash < payout:
        parent.message = "Dividend requires $%s in available cash." % parent._money(payout)
        return
    var result: Variant = ownership.distribute_dividend(COMPANY_ID, float(payout))
    if not bool(result.get("ok", false)):
        parent.message = "Dividend failed: %s." % str(result.get("error", "unknown"))
        return
    parent.cash -= payout
    dividends_paid += payout
    ownership.adjust_investor_confidence(COMPANY_ID, 5.0, "dividend_paid")
    _persist()
    parent.message = "Paid $%s dividend through OwnershipSystem. Investors are happier, but growth capital is lower." % parent._money(payout)
    parent._log("DIVIDEND: $%s distributed according to ownership." % parent._money(payout))

func strengthen_defense() -> void:
    _recalculate()
    var current: Variant = defense_level
    if current >= 3:
        parent.message = "Corporate defense is already at maximum strength."
        return
    var cost: Variant = 7000 * (current + 1)
    if parent.cash < cost:
        parent.message = "Corporate defense requires $%s." % parent._money(cost)
        return
    parent.cash -= cost
    ownership.set_defense(COMPANY_ID, current + 1, bool(_company().get("poison_pill", false)))
    ownership.adjust_investor_confidence(COMPANY_ID, 6.0, "defense_upgrade")
    parent.reputation += 2
    _persist()
    parent.message = "Defense upgraded to level %d through OwnershipSystem. Takeover risk reduced." % defense_level
    parent._log("BOARD: ownership defense upgraded to level %d (-$%s)." % [defense_level, parent._money(cost)])

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
    ownership.adjust_investor_confidence(COMPANY_ID, 12.0, "strategic_ally_defense")
    ownership.set_defense(COMPANY_ID, min(3, defense_level + 1), true)
    takeover_cooldown = 10
    _persist()
    parent.message = "Strategic ally committed support. OwnershipSystem takeover risk is temporarily suppressed."
    parent._log("ALLIANCE DEFENSE: strategic partner backed the company against takeover pressure.")

func influence_board() -> void:
    _recalculate()
    if not parent.business_open:
        parent.message = "Open the business before building a corporate board."
        return
    if parent.reputation < 25:
        parent.message = "Board influence requires 25 reputation."
        return
    var board_size: Variant = int(_company().get("board", {}).get("seat_count", 3))
    var occupied: Variant = ownership.get_board_seats(COMPANY_ID)
    if occupied >= board_size:
        parent.message = "The OwnershipSystem board is full."
        return
    var cost: Variant = 3500 + board_influence * 1500
    if parent.cash < cost:
        parent.message = "Board campaign requires $%s." % parent._money(cost)
        return
    parent.cash -= cost
    var seat_id: Variant = "founder_campaign_%d" % (board_influence + 1)
    var result: Variant = ownership.appoint_board_seat(COMPANY_ID, FOUNDER_ID, seat_id)
    if not bool(result.get("ok", false)):
        parent.cash += cost
        parent.message = "Board campaign failed: %s." % str(result.get("error", "unknown"))
        return
    board_influence = ownership.get_board_seats(COMPANY_ID, FOUNDER_ID)
    ownership.adjust_investor_confidence(COMPANY_ID, 4.0, "board_campaign")
    parent.reputation += 1
    _persist()
    parent.message = "Founder board control increased to %d seat(s)." % board_influence
    parent._log("BOARD CAMPAIGN: OwnershipSystem assigned founder seat for $%s." % parent._money(cost))

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
    var target_cash: Variant = max(25000, int(target["cash"]))
    var offer: Variant = max(25000, int(round(float(target_cash) * 0.38)))
    if parent.cash < offer:
        parent.message = "A hostile bid needs $%s in acquisition financing." % parent._money(offer)
        return
    hostile_attempts += 1
    var control_check: Variant = ownership.takeover_control(COMPANY_ID, FOUNDER_ID, 50.0)
    if not bool(control_check.get("ok", false)):
        parent.message = "Hostile bid blocked: founder lacks majority voting control."
        return
    var strength: Variant = control_score + float(ownership.get_board_seats(COMPANY_ID, FOUNDER_ID) * 3) + float(parent.reputation) * 0.25 - float(target_cash) / 50000.0
    var chance: Variant = clamp(0.25 + strength / 260.0 - float(defense_level) * 0.04, 0.18, 0.88)
    parent.cash -= offer
    if randf() <= chance:
        target["cash"] = max(0, int(target["cash"]) - offer)
        takeover_wins += 1
        parent.acquisition_count += 1
        parent.reputation += 12
        ownership.adjust_investor_confidence(COMPANY_ID, 15.0, "successful_takeover")
        ownership.set_defense(COMPANY_ID, min(3, defense_level + 1), bool(_company().get("poison_pill", false)))
        takeover_cooldown = 12
        _persist()
        parent.message = "HOSTILE TAKEOVER SUCCESS: You seized strategic control of %s." % target["name"]
        parent._log("CORPORATE WAR: hostile bid succeeded against %s for $%s." % [target["name"], parent._money(offer)])
        _check_milestones()
    else:
        parent.reputation = max(0, parent.reputation - 6)
        ownership.adjust_investor_confidence(COMPANY_ID, -10.0, "failed_takeover")
        takeover_cooldown = 8
        _persist()
        parent.message = "HOSTILE TAKEOVER FAILED: shareholders rejected the bid."
        parent._log("CORPORATE WAR: hostile bid failed after shareholders backed the target.")

func process_day() -> void:
    if parent == null: return
    if takeover_cooldown > 0: takeover_cooldown -= 1
    _recalculate()
    if parent.day % 7 == 0 and investor_stake > 0:
        ownership.adjust_investor_confidence(COMPANY_ID, 1.0, "weekly_board_cycle")
    if takeover_risk >= 65.0 and takeover_cooldown <= 0 and parent.day % 5 == 0 and parent.rivals.rivals.size() > 0:
        var giant = parent.rivals.rivals[0]
        var pressure: Variant = max(0, int(float(takeover_risk) * 700))
        if int(giant["cash"]) > pressure:
            giant["cash"] = max(0, int(giant["cash"]) - pressure / 4)
            takeover_cooldown = 5
            ownership.adjust_investor_confidence(COMPANY_ID, -8.0, "hostile_pressure")
            parent.reputation = max(0, parent.reputation - 2)
            parent._log("TAKEOVER ATTEMPT: The Giant offered shareholders a premium bid. Control is under pressure.")
            parent.message = "TAKEOVER ALERT: The Giant is targeting your company. Defend your control."
    _check_milestones()
    _persist()

func get_summary() -> Dictionary:
    _recalculate()
    var snapshot: Variant = ownership.get_control_snapshot(COMPANY_ID)
    return {"valuation":valuation,"share_price":share_price,"founder":founder_stake,"investors":investor_stake,"treasury":treasury_shares,"control":control_score,"risk":takeover_risk,"defense":defense_level,"trust":board_trust,"influence":ownership.get_board_seats(COMPANY_ID, FOUNDER_ID),"takeover_wins":takeover_wins,"hostile_attempts":hostile_attempts,"dividends":dividends_paid,"milestone":milestone_level,"milestone_name":_milestone_target(milestone_level),"ownership_snapshot":snapshot}

func save_state() -> Dictionary:
    return {"ownership_state": ownership.save_state() if ownership != null else {}, "investor_cash_raised":investor_cash_raised,"dividends_paid":dividends_paid,"valuation":valuation,"share_price":share_price,"last_capital_raise":last_capital_raise,"takeover_cooldown":takeover_cooldown,"last_processed_day":last_processed_day,"board_influence":board_influence,"takeover_wins":takeover_wins,"hostile_attempts":hostile_attempts,"milestone_level":milestone_level}

func load_state(state: Dictionary) -> void:
    if ownership != null and state.has("ownership_state") and state["ownership_state"] is Dictionary:
        ownership.load_state(state["ownership_state"])
    investor_cash_raised = int(state.get("investor_cash_raised",0))
    dividends_paid = int(state.get("dividends_paid",0))
    valuation = int(state.get("valuation",25000))
    share_price = int(state.get("share_price",25))
    last_capital_raise = int(state.get("last_capital_raise",0))
    takeover_cooldown = int(state.get("takeover_cooldown",0))
    last_processed_day = int(state.get("last_processed_day",parent.day if parent != null else 1))
    board_influence = int(state.get("board_influence",0))
    takeover_wins = int(state.get("takeover_wins",0))
    hostile_attempts = int(state.get("hostile_attempts",0))
    milestone_level = int(state.get("milestone_level",0))

func _persist() -> void:
    var file: Variant = FileAccess.open("user://renew_corporate.json", FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(save_state()))
        file.close()

func _load_persistent_state() -> void:
    if not FileAccess.file_exists("user://renew_corporate.json"): return
    var file: Variant = FileAccess.open("user://renew_corporate.json", FileAccess.READ)
    if file == null: return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        load_state(parsed)
        if parent != null: last_processed_day = parent.day

func _draw() -> void:
    if parent == null: return
    var s: Variant = get_summary()
    var panel: Variant = Rect2(855, 350, 385, 360)
    draw_rect(panel, Color("101923"), true)
    draw_rect(panel, Color("516b7d"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(870, 375), "CORPORATE CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f0f4f7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 399), "Valuation: $%s   Share: $%s" % [parent._money(int(s["valuation"])), parent._money(int(s["share_price"]))], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 421), "Founder: %.1f%%   Investors: %.1f%%" % [s["founder"], s["investors"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 443), "Voting control %.1f | Risk %.0f | Defense L%d" % [_voting_percent(FOUNDER_ID), s["risk"], s["defense"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 465), "Investor confidence %d | Founder board %d" % [s["trust"], s["influence"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 487), "Takeover wins %d | Attempts %d" % [s["takeover_wins"], s["hostile_attempts"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffad8f"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 509), "Tier %d: %s" % [s["milestone"], s["milestone_name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd27f"))
