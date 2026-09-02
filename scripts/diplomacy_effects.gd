extends Node

## Applies active treaty benefits to the real game systems once per game day.
var last_day := -1
var applied: Dictionary = {}

func _process(_delta: float) -> void:
    var tree := Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null: return
    var day := int(scene.get("day"))
    if day == last_day: return
    last_day = day
    var diplomacy = get_node_or_null("/root/RenewDiplomacySystem")
    if diplomacy == null: return
    for treaty in diplomacy.list_treaties("active"):
        _apply(treaty, day)

func _apply(treaty: Dictionary, day: int) -> void:
    var id := str(treaty.get("id", ""))
    var a := str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
    if a != "player" and b != "player": return
    var benefits: Dictionary = treaty.get("benefits", {})
    var obligations: Dictionary = treaty.get("obligations", {})
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var production = get_node_or_null("/root/RenewProductionSystem")
    var main = Engine.get_main_loop().get_current_scene()
    match str(treaty.get("type", "")):
        "trade":
            if finance != null: finance.receive(max(1, int(round(250.0 * float(benefits.get("trade_margin", 0.04))))), "treaty trade:%s" % id)
        "supply":
            if production != null:
                var qty := max(1, int(obligations.get("minimum_supply", 5)))
                production.add_inventory("materials", qty)
                production.add_inventory("fuel", max(1, int(round(qty * 0.2))))
        "research":
            if production != null and int(applied.get(id, {}).get("research_day", -1)) != day:
                production.unlock_technology("logistics", max(1, int(production.technologies.get("logistics", 0)) + 1))
                _mark(id, "research_day", day)
        "defense", "non_aggression", "territory":
            if main != null and int(applied.get(id, {}).get("reputation_day", -1)) != day:
                main.reputation = int(main.reputation) + 1
                _mark(id, "reputation_day", day)
        "investment":
            if finance != null:
                var capital := float(obligations.get("capital_commitment", 5000.0))
                var rate := float(benefits.get("investment_return", 0.08))
                finance.receive(max(1, int(round(capital * rate / 30.0))), "treaty investment:%s" % id)
        "infrastructure":
            if production != null and not bool(applied.get(id, {}).get("infrastructure", false)):
                for machine_id in ["processor", "factory", "fleet"]:
                    if production.machines.has(machine_id): production.machines[machine_id]["capacity"] = int(production.machines[machine_id].get("capacity", 1)) + 1
                _mark(id, "infrastructure", true)
        "joint_venture":
            if finance != null:
                var capital := float(obligations.get("joint_capital", 3000.0))
                var share := float(benefits.get("joint_profit_share", 0.10))
                finance.receive(max(1, int(round(capital * (0.10 + share) / 30.0))), "joint venture profit:%s" % id)

func _mark(id: String, key: String, value) -> void:
    if not applied.has(id): applied[id] = {}
    applied[id][key] = value

func capture_state() -> Dictionary:
    return {"system_version": 1, "last_day": last_day, "applied": applied.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    last_day = int(state.get("last_day", -1))
    applied = state.get("applied", {}).duplicate(true)
