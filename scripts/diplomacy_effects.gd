extends Node

## Applies active treaty benefits to the real game systems once per game day.
const RuntimeResolver = preload("res://scripts/runtime_dependency_resolver.gd")
const CHECK_INTERVAL_SECONDS := 0.25
var last_day: int = -1
var applied: Dictionary = {}
var _day_check_timer: Timer

func _ready() -> void:
    _day_check_timer = Timer.new()
    _day_check_timer.wait_time = CHECK_INTERVAL_SECONDS
    _day_check_timer.one_shot = false
    _day_check_timer.timeout.connect(_check_day)
    add_child(_day_check_timer)
    _day_check_timer.start()
    call_deferred("_check_day")

func _exit_tree() -> void:
    if _day_check_timer != null:
        if _day_check_timer.timeout.is_connected(_check_day):
            _day_check_timer.timeout.disconnect(_check_day)
        _day_check_timer.stop()
        _day_check_timer.queue_free()
        _day_check_timer = null

func _check_day() -> void:
    var tree: Variant = Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null: return
    var day: int = int(scene.get("day"))
    if day == last_day: return
    last_day = day
    var diplomacy = RuntimeResolver.resolve("RenewDiplomacySystem", "Systems/RenewDiplomacySystem")
    if diplomacy == null: return
    for treaty in diplomacy.list_treaties("active"):
        _apply(treaty, day)

func _apply(treaty: Dictionary, day: int) -> void:
    var id: String = str(treaty.get("id", ""))
    var a: String = str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
    if a != "player" and b != "player": return
    var benefits: Dictionary = treaty.get("benefits", {})
    var obligations: Dictionary = treaty.get("obligations", {})
    var finance = RuntimeResolver.resolve("RenewFinanceSystem")
    var production = RuntimeResolver.resolve("RenewProductionSystem")
    var main = Engine.get_main_loop().get_current_scene()
    match str(treaty.get("type", "")):
        "trade":
            if finance != null: finance.receive(max(1, int(round(250.0 * float(benefits.get("trade_margin", 0.04))))), "treaty trade:%s" % id)
        "supply":
            if production != null:
                var qty: int = max(1, int(obligations.get("minimum_supply", 5)))
                production.add_inventory("iron", qty)
                production.add_inventory("energy", max(1, int(round(qty * 0.2))))
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
                var capital: int = max(0, int(round(float(obligations.get("capital_commitment", 5000.0)))))
                var investment_state: Dictionary = applied.get(id, {})
                if not bool(investment_state.get("funded", false)):
                    var payment: Dictionary = finance.spend(capital, "treaty investment capital:%s" % id)
                    if not bool(payment.get("ok", false)):
                        _mark(id, "funding_blocked", true)
                        return
                    _mark(id, "funded", true)
                    _mark(id, "funding_blocked", false)
                    _mark(id, "funded_capital", capital)
                    _mark(id, "funding_day", day)
                    investment_state = applied.get(id, {})
                if int(investment_state.get("return_day", -1)) == day:
                    return
                var rate: float = float(benefits.get("investment_return", 0.08))
                finance.receive(max(1, int(round(float(capital) * rate / 30.0))), "treaty investment:%s" % id)
                _mark(id, "return_day", day)
        "infrastructure":
            if production != null and not bool(applied.get(id, {}).get("infrastructure", false)):
                for machine_id in ["processor", "factory", "fleet"]:
                    if production.machines.has(machine_id): production.machines[machine_id]["capacity"] = int(production.machines[machine_id].get("capacity", 1)) + 1
                _mark(id, "infrastructure", true)
        "joint_venture":
            # Joint ventures are materialized and settled by RenewDiplomacyControl.
            pass

func _mark(id: String, key: String, value) -> void:
    if not applied.has(id): applied[id] = {}
    applied[id][key] = value

func capture_state() -> Dictionary:
    return {"system_version": 1, "last_day": last_day, "applied": applied.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    last_day = int(state.get("last_day", -1))
    applied = state.get("applied", {}).duplicate(true)
