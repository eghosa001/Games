extends Node

## Autonomous diplomatic behavior for rival corporations.
## NPCs can propose, accept, cancel and occasionally breach treaties based on
## relationships, strategic needs and risk tolerance.

var last_day := -1

func _process(_delta: float) -> void:
    var tree := Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null: return
    var day := int(scene.get("day"))
    if day == last_day: return
    last_day = day
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if diplomacy == null: return
    diplomacy.process_day(day)
    var rivals = scene.get("rivals")
    if rivals == null: return
    _simulate(day, diplomacy, rivals)

func _simulate(day: int, diplomacy, rivals) -> void:
    for r in rivals.rivals:
        var id := str(r.get("id", ""))
        if id.is_empty(): continue
        var active := diplomacy.get_party_treaties(id, true)
        for treaty in active:
            if treaty.get("party_b") == id and int(r.get("relationship", 0)) < -45 and day % 9 == 0:
                diplomacy.cancel_treaty(str(treaty["id"]), id, "relations deteriorated")
        var proposals := diplomacy.get_party_treaties(id, false)
        for treaty in proposals:
            if treaty.get("status") != diplomacy.STATUS_PROPOSED: continue
            if treaty.get("party_b") != id: continue
            if _will_accept(r, treaty, day):
                diplomacy.accept_treaty(str(treaty["id"]), id)
        if day % 7 != 0: continue
        if active.size() >= 4: continue
        var relationship := int(r.get("relationship", 0))
        if relationship >= 25 or "alliances" in r.get("strategic_priorities", []):
            var type := _best_type(r)
            var terms := _terms_for(r, type)
            diplomacy.propose_treaty(id, "player", type, terms, 21 + int(r.get("risk_tolerance", 0.5) * 30.0))

func _will_accept(r: Dictionary, treaty: Dictionary, day: int) -> bool:
    var rel := int(r.get("relationship", 0))
    var risk := float(r.get("risk_tolerance", 0.5))
    var type := str(treaty.get("type", ""))
    if rel >= 35: return true
    if type == "non_aggression" or type == "defense": return rel >= 5
    if type == "supply": return rel >= 10 or int(r.get("supplier_pressure", 0)) >= 2
    if type == "research": return rel >= 20 and int(r.get("technology", 0)) >= 2
    return rel >= 20 and risk >= 0.45 and day % 2 == 0

func _best_type(r: Dictionary) -> String:
    var priorities: Array = r.get("strategic_priorities", [])
    if "supply_control" in priorities: return "supply"
    if "technology" in priorities: return "research"
    if "logistics" in priorities: return "infrastructure"
    if "alliances" in priorities: return "defense"
    if "market_share" in priorities: return "trade"
    return "non_aggression"

func _terms_for(r: Dictionary, type: String) -> Dictionary:
    var base := {"obligations": {}, "benefits": {"trust_per_day": 0.05}, "penalties": {"trust_damage": 8.0, "cancellation_fee": 0.0}, "trust_effect": 2.0}
    match type:
        "trade": base["obligations"] = {"minimum_trade": 1000}; base["benefits"] = {"trade_margin": 0.04, "trust_per_day": 0.08}
        "supply": base["obligations"] = {"minimum_supply": 5, "priority_access": true}; base["benefits"] = {"supply_security": 0.15, "trust_per_day": 0.10}
        "research": base["obligations"] = {"research_contribution": 1500}; base["benefits"] = {"technology_share": 0.10, "trust_per_day": 0.12}
        "defense": base["obligations"] = {"mutual_response": true}; base["benefits"] = {"defense_strength": 0.15, "trust_per_day": 0.15}
        "non_aggression": base["obligations"] = {"no_hostile_action": true}; base["benefits"] = {"stability": 0.15, "trust_per_day": 0.12}
        "investment": base["obligations"] = {"capital_commitment": 5000}; base["benefits"] = {"investment_return": 0.08, "trust_per_day": 0.10}
        "territory": base["obligations"] = {"respect_districts": true}; base["benefits"] = {"territory_stability": 0.20, "trust_per_day": 0.10}
        "infrastructure": base["obligations"] = {"shared_infrastructure": true}; base["benefits"] = {"logistics_bonus": 0.10, "trust_per_day": 0.10}
        "joint_venture": base["obligations"] = {"joint_capital": 3000}; base["benefits"] = {"joint_profit_share": 0.10, "trust_per_day": 0.12}
    return base