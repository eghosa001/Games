extends Node

## RENEW DiplomacySystem.
## Persistent bilateral diplomacy with typed treaties, terms, duration, obligations,
## benefits, penalties, cancellation, breach handling and trust effects.

const STATUS_PROPOSED := "proposed"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_CANCELLED := "cancelled"
const STATUS_BREACHED := "breached"
const STATUS_EXPIRED := "expired"

const TRADE := "trade"
const SUPPLY := "supply"
const RESEARCH := "research"
const DEFENSE := "defense"
const NON_AGGRESSION := "non_aggression"
const INVESTMENT := "investment"
const TERRITORY := "territory"
const INFRASTRUCTURE := "infrastructure"
const JOINT_VENTURE := "joint_venture"

const TREATY_TYPES := [TRADE, SUPPLY, RESEARCH, DEFENSE, NON_AGGRESSION, INVESTMENT, TERRITORY, INFRASTRUCTURE, JOINT_VENTURE]

var treaties: Dictionary = {}
var next_treaty_id: Variant = 1
var events: Array = []
var party_trust: Dictionary = {}

func propose_treaty(party_a: String, party_b: String, treaty_type: String, terms: Dictionary = {}, duration_days: int = 30) -> Dictionary:
    if party_a.is_empty() or party_b.is_empty() or party_a == party_b:
        return {"ok": false, "message": "Two different parties are required."}
    if not TREATY_TYPES.has(treaty_type):
        return {"ok": false, "message": "Unsupported treaty type."}
    if duration_days <= 0:
        return {"ok": false, "message": "Treaty duration must be positive."}
    var id: Variant = "treaty_%d" % next_treaty_id
    next_treaty_id += 1
    var normalized: Variant = _normalize_terms(terms)
    var treaty: Variant = {
        "id": id, "type": treaty_type, "party_a": party_a, "party_b": party_b,
        "terms": normalized.get("terms", {}), "obligations": normalized.get("obligations", {}),
        "benefits": normalized.get("benefits", {}), "penalties": normalized.get("penalties", {}),
        "duration_days": duration_days, "start_day": -1, "end_day": -1,
        "status": STATUS_PROPOSED, "proposer": party_a, "created_day": _day(),
        "trust_effect": float(normalized.get("trust_effect", 2.0)),
        "breach_count": 0, "last_breach_day": -1, "history": []
    }
    treaties[id] = treaty
    _event("treaty_proposed", "Treaty proposed: %s between %s and %s" % [treaty_type, party_a, party_b], {"treaty_id": id})
    return {"ok": true, "treaty": get_treaty(id), "message": "Treaty %s proposed." % id}

func accept_treaty(treaty_id: String, accepting_party: String) -> Dictionary:
    var treaty: Dictionary = treaties.get(treaty_id, {})
    if treaty.is_empty(): return {"ok": false, "message": "Treaty not found."}
    if treaty.get("status") != STATUS_PROPOSED: return {"ok": false, "message": "Treaty is no longer open for acceptance."}
    if accepting_party != treaty.get("party_b"):
        return {"ok": false, "message": "Only the receiving party can accept this proposal."}
    var start: Variant = _day()
    treaty["status"] = STATUS_ACTIVE; treaty["start_day"] = start; treaty["end_day"] = start + int(treaty["duration_days"])
    treaty["history"].append({"day": start, "event": "accepted", "party": accepting_party})
    treaties[treaty_id] = treaty
    _adjust_trust(str(treaty["party_a"]), str(treaty["party_b"]), float(treaty["trust_effect"]))
    _adjust_trust(str(treaty["party_b"]), str(treaty["party_a"]), float(treaty["trust_effect"]))
    _event("treaty_activated", "Treaty %s activated." % treaty_id, {"treaty_id": treaty_id})
    return {"ok": true, "treaty": get_treaty(treaty_id), "message": "Treaty is now active."}

func cancel_treaty(treaty_id: String, party_id: String, reason: String = "cancelled") -> Dictionary:
    var treaty: Dictionary = treaties.get(treaty_id, {})
    if treaty.is_empty(): return {"ok": false, "message": "Treaty not found."}
    if party_id != treaty.get("party_a") and party_id != treaty.get("party_b"):
        return {"ok": false, "message": "Party is not bound by this treaty."}
    if treaty.get("status") not in [STATUS_PROPOSED, STATUS_ACTIVE]:
        return {"ok": false, "message": "Treaty cannot be cancelled in its current state."}
    treaty["status"] = STATUS_CANCELLED
    treaty["history"].append({"day": _day(), "event": "cancelled", "party": party_id, "reason": reason})
    treaties[treaty_id] = treaty
    var other: Variant = _other_party(treaty, party_id)
    _adjust_trust(party_id, other, -3.0)
    if treaty.get("start_day", -1) >= 0 and _day() < int(treaty["end_day"]):
        _apply_penalty(treaty, party_id, "early_cancellation")
    _event("treaty_cancelled", "Treaty %s cancelled by %s." % [treaty_id, party_id], {"treaty_id": treaty_id, "reason": reason})
    return {"ok": true, "treaty": get_treaty(treaty_id), "message": "Treaty cancelled."}

func breach_treaty(treaty_id: String, breaching_party: String, reason: String = "obligation not fulfilled") -> Dictionary:
    var treaty: Dictionary = treaties.get(treaty_id, {})
    if treaty.is_empty() or treaty.get("status") != STATUS_ACTIVE:
        return {"ok": false, "message": "Only active treaties can be breached."}
    if breaching_party != treaty.get("party_a") and breaching_party != treaty.get("party_b"):
        return {"ok": false, "message": "Party is not bound by this treaty."}
    treaty["breach_count"] = int(treaty.get("breach_count", 0)) + 1
    treaty["last_breach_day"] = _day()
    treaty["history"].append({"day": _day(), "event": "breach", "party": breaching_party, "reason": reason})
    treaty["status"] = STATUS_BREACHED
    treaties[treaty_id] = treaty
    var other: Variant = _other_party(treaty, breaching_party)
    _adjust_trust(breaching_party, other, -max(5.0, float(treaty["penalties"].get("trust_damage", 8.0))))
    _adjust_trust(other, breaching_party, -max(5.0, float(treaty["penalties"].get("trust_damage", 8.0))))
    _apply_penalty(treaty, breaching_party, "breach")
    _event("treaty_breached", "Treaty %s breached by %s: %s" % [treaty_id, breaching_party, reason], {"treaty_id": treaty_id})
    return {"ok": true, "treaty": get_treaty(treaty_id), "message": "Treaty breached; penalties applied."}

func process_day(day: int = -1) -> void:
    var current: Variant = _day() if day < 0 else day
    for id in treaties.keys():
        var treaty: Dictionary = treaties[id]
        if treaty.get("status") != STATUS_ACTIVE: continue
        if current >= int(treaty.get("end_day", current + 1)):
            treaty["status"] = STATUS_EXPIRED
            treaty["history"].append({"day": current, "event": "expired"})
            treaties[id] = treaty
            _event("treaty_expired", "Treaty %s expired." % id, {"treaty_id": id})
            continue
        _apply_daily_benefits(treaty)

func get_treaty(treaty_id: String) -> Dictionary:
    return treaties.get(treaty_id, {}).duplicate(true)

func list_treaties(status: String = "") -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for treaty in treaties.values():
        if status.is_empty() or str(treaty.get("status", "")) == status:
            result.append(treaty.duplicate(true))
    return result

func get_party_treaties(party_id: String, active_only: bool = false) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for treaty in treaties.values():
        if treaty.get("party_a") != party_id and treaty.get("party_b") != party_id: continue
        if active_only and treaty.get("status") != STATUS_ACTIVE: continue
        result.append(treaty.duplicate(true))
    return result

func get_trust(party_a: String, party_b: String) -> float:
    return float(party_trust.get(_trust_key(party_a, party_b), 50.0))

func set_trust(party_a: String, party_b: String, value: float) -> void:
    party_trust[_trust_key(party_a, party_b)] = clampf(value, 0.0, 100.0)

func capture_state() -> Dictionary:
    return {"system_version": 1, "next_treaty_id": next_treaty_id, "treaties": treaties.duplicate(true), "events": events.duplicate(true), "party_trust": party_trust.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    treaties = state.get("treaties", {}).duplicate(true)
    events.clear()
    for event in state.get("events", []):
        if event is Dictionary: events.append(event.duplicate(true))
    party_trust = state.get("party_trust", {}).duplicate(true)
    next_treaty_id = int(state.get("next_treaty_id", 1))

func _normalize_terms(raw: Dictionary) -> Dictionary:
    var terms: Variant = raw.duplicate(true)
    var obligations: Dictionary = terms.get("obligations", {}).duplicate(true)
    var benefits: Dictionary = terms.get("benefits", {}).duplicate(true)
    var penalties: Dictionary = terms.get("penalties", {}).duplicate(true)
    terms.erase("obligations"); terms.erase("benefits"); terms.erase("penalties")
    var trust_effect: Variant = float(raw.get("trust_effect", 2.0))
    return {"terms": terms, "obligations": obligations, "benefits": benefits, "penalties": penalties, "trust_effect": trust_effect}

func _apply_daily_benefits(treaty: Dictionary) -> void:
    var benefits: Dictionary = treaty.get("benefits", {})
    var benefit_trust: Variant = float(benefits.get("trust_per_day", 0.0))
    if absf(benefit_trust) > 0.001:
        _adjust_trust(str(treaty["party_a"]), str(treaty["party_b"]), benefit_trust)

func _apply_penalty(treaty: Dictionary, breaching_party: String, context: String) -> void:
    var penalties: Dictionary = treaty.get("penalties", {})
    var trust_damage: Variant = float(penalties.get("trust_damage", 8.0))
    var other: Variant = _other_party(treaty, breaching_party)
    _adjust_trust(breaching_party, other, -trust_damage)
    if context == "early_cancellation" and float(penalties.get("cancellation_fee", 0.0)) > 0.0:
        _event("treaty_penalty", "Cancellation penalty assessed to %s." % breaching_party, {"amount": penalties["cancellation_fee"], "treaty_id": treaty["id"]})

func _mirror_key(a: String, b: String) -> String: return "%s|%s" % [a, b]
func _trust_key(a: String, b: String) -> String: return _mirror_key(a, b)
func _other_party(treaty: Dictionary, party: String) -> String:
    return str(treaty["party_b"]) if party == treaty["party_a"] else str(treaty["party_a"])
func _adjust_trust(a: String, b: String, delta: float) -> void:
    set_trust(a, b, get_trust(a, b) + delta)
    set_trust(b, a, get_trust(b, a) + delta)
func _event(kind: String, message: String, data: Dictionary = {}) -> void:
    events.append({"day": _day(), "type": kind, "message": message, "data": data})
    if events.size() > 200: events.pop_front()
func _day() -> int:
    var tree: Variant = Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    return int(scene.get("day")) if scene != null else 1
