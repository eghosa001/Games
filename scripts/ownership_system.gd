extends Node

## RENEW generalized ownership/control ledger.
## Ownership is modeled independently from the player's corporate layer so the
## same system can own companies, joint ventures and individual assets.

const ENTITY_COMPANY := "company"
const ENTITY_JV := "joint_venture"
const ENTITY_ASSET := "asset"

const VOTE_ORDINARY := "ordinary"
const VOTE_NON_VOTING := "non_voting"

var entities: Dictionary = {}
var transaction_log: Array[Dictionary] = []
var next_transaction_id: Variant = 1

func register_entity(entity_id: String, entity_type: String = ENTITY_COMPANY, total_shares: int = 1000000, par_value: float = 1.0) -> Dictionary:
    if entity_id.is_empty():
        return {"ok": false, "error": "entity_id_required"}
    if entities.has(entity_id):
        return {"ok": false, "error": "entity_exists", "entity": entities[entity_id]}
    if total_shares <= 0:
        return {"ok": false, "error": "invalid_share_count"}
    entities[entity_id] = {
        "id": entity_id,
        "type": entity_type,
        "authorized_shares": total_shares,
        "issued_shares": 0,
        "treasury_shares": 0,
        "par_value": par_value,
        "share_classes": {"ordinary": {"votes_per_share": 1.0, "dividend_multiplier": 1.0}},
        "holders": {},
        "board": {"seat_count": 3, "seats": {}, "reserved_seats": {}},
        "control_thresholds": {"ordinary": 0.50, "supermajority": 0.667, "special": 0.75},
        "dividend_pool": 0.0,
        "investor_confidence": 50.0,
        "defense_level": 0,
        "poison_pill": false,
        "tag": ""
    }
    return {"ok": true, "entity": entities[entity_id].duplicate(true)}

func register_entity_from_ownership(entity_id: String, holder_percentages: Dictionary, entity_type: String = ENTITY_COMPANY) -> Dictionary:
    var result: Variant = register_entity(entity_id, entity_type)
    if not result.ok:
        return result
    var holder_count: Variant = holder_percentages.size()
    if holder_count == 0:
        return result
    var remaining: Variant = 100.0
    var first: Variant = true
    for holder_id in holder_percentages:
        var pct: Variant = max(0.0, float(holder_percentages[holder_id]))
        if first:
            pct = min(pct, remaining)
            first = false
        else:
            pct = min(pct, remaining)
        var issue: Variant = issue_shares(entity_id, holder_id, int(round(pct * 10000.0)), VOTE_ORDINARY, "initialization")
        if not issue.ok:
            return issue
        remaining -= pct
    return {"ok": true, "entity": get_entity(entity_id)}

func get_entity(entity_id: String) -> Dictionary:
    if not entities.has(entity_id):
        return {}
    return entities[entity_id].duplicate(true)

func has_entity(entity_id: String) -> bool:
    return entities.has(entity_id)

func _entity(entity_id: String) -> Dictionary:
    return entities.get(entity_id, {})

func _holder(entity: Dictionary, holder_id: String) -> Dictionary:
    if not entity.has("holders"):
        entity["holders"] = {}
    if not entity["holders"].has(holder_id):
        entity["holders"][holder_id] = {}
    return entity["holders"][holder_id]

func _shares(holder: Dictionary, share_class: String = VOTE_ORDINARY) -> int:
    return int(holder.get("classes", {}).get(share_class, 0))

func _ensure_class(holder: Dictionary, share_class: String) -> void:
    if not holder.has("classes"):
        holder["classes"] = {}
    if not holder["classes"].has(share_class):
        holder["classes"][share_class] = 0

func _record(entity_id: String, action: String, data: Dictionary = {}) -> void:
    transaction_log.append({"id": next_transaction_id, "entity_id": entity_id, "action": action, "data": data.duplicate(true)})
    next_transaction_id += 1
    if transaction_log.size() > 1000:
        transaction_log.pop_front()

func issue_shares(entity_id: String, holder_id: String, quantity: int, share_class: String = VOTE_ORDINARY, reason: String = "issuance") -> Dictionary:
    if not entities.has(entity_id) or holder_id.is_empty() or quantity <= 0:
        return {"ok": false, "error": "invalid_issue"}
    var entity: Variant = entities[entity_id]
    if int(entity["issued_shares"]) + quantity > int(entity["authorized_shares"]):
        return {"ok": false, "error": "authorized_shares_exceeded"}
    var holder: Variant = _holder(entity, holder_id)
    _ensure_class(holder, share_class)
    holder["classes"][share_class] += quantity
    entity["issued_shares"] += quantity
    entities[entity_id] = entity
    _record(entity_id, "issue", {"holder_id": holder_id, "quantity": quantity, "class": share_class, "reason": reason})
    return {"ok": true, "issued": quantity, "entity": get_entity(entity_id)}

func issue_for_percent(entity_id: String, holder_id: String, percent_of_post_issue: float, share_class: String = VOTE_ORDINARY, reason: String = "issuance") -> Dictionary:
    if percent_of_post_issue <= 0.0 or percent_of_post_issue >= 100.0:
        return {"ok": false, "error": "invalid_percentage"}
    var entity: Variant = _entity(entity_id)
    if entity.is_empty():
        return {"ok": false, "error": "entity_not_found"}
    var issued: Variant = int(entity["issued_shares"])
    var quantity: Variant = int(ceil(float(issued) * percent_of_post_issue / (100.0 - percent_of_post_issue)))
    if quantity <= 0:
        quantity = 1
    return issue_shares(entity_id, holder_id, quantity, share_class, reason)

func transfer_shares(entity_id: String, from_holder: String, to_holder: String, quantity: int, share_class: String = VOTE_ORDINARY, reason: String = "transfer") -> Dictionary:
    if not entities.has(entity_id) or from_holder.is_empty() or to_holder.is_empty() or from_holder == to_holder or quantity <= 0:
        return {"ok": false, "error": "invalid_transfer"}
    var entity: Variant = entities[entity_id]
    var source: Variant = _holder(entity, from_holder)
    if _shares(source, share_class) < quantity:
        return {"ok": false, "error": "insufficient_shares"}
    var destination: Variant = _holder(entity, to_holder)
    _ensure_class(source, share_class)
    _ensure_class(destination, share_class)
    source["classes"][share_class] -= quantity
    destination["classes"][share_class] += quantity
    entities[entity_id] = entity
    _record(entity_id, "transfer", {"from": from_holder, "to": to_holder, "quantity": quantity, "class": share_class, "reason": reason})
    return {"ok": true, "transferred": quantity, "entity": get_entity(entity_id)}

func buyback(entity_id: String, holder_id: String, quantity: int, price_per_share: float = 0.0, reason: String = "buyback") -> Dictionary:
    if not entities.has(entity_id) or quantity <= 0:
        return {"ok": false, "error": "invalid_buyback"}
    var entity: Variant = entities[entity_id]
    var holder: Variant = _holder(entity, holder_id)
    if _shares(holder) < quantity:
        return {"ok": false, "error": "insufficient_shares"}
    holder["classes"][VOTE_ORDINARY] -= quantity
    entity["treasury_shares"] += quantity
    entities[entity_id] = entity
    var cost: Variant = float(quantity) * max(0.0, price_per_share)
    _record(entity_id, "buyback", {"holder_id": holder_id, "quantity": quantity, "price_per_share": price_per_share, "cost": cost, "reason": reason})
    return {"ok": true, "repurchased": quantity, "cost": cost, "entity": get_entity(entity_id)}

func retire_treasury_shares(entity_id: String, quantity: int, reason: String = "retirement") -> Dictionary:
    if not entities.has(entity_id) or quantity <= 0:
        return {"ok": false, "error": "invalid_retirement"}
    var entity: Variant = entities[entity_id]
    if int(entity["treasury_shares"]) < quantity:
        return {"ok": false, "error": "insufficient_treasury"}
    entity["treasury_shares"] -= quantity
    entity["authorized_shares"] = max(0, int(entity["authorized_shares"]) - quantity)
    entity["issued_shares"] = max(0, int(entity["issued_shares"]) - quantity)
    entities[entity_id] = entity
    _record(entity_id, "retire_treasury", {"quantity": quantity, "reason": reason})
    return {"ok": true, "retired": quantity, "entity": get_entity(entity_id)}

func get_total_votes(entity_id: String) -> float:
    var entity: Variant = _entity(entity_id)
    if entity.is_empty(): return 0.0
    var total: Variant = 0.0
    for holder_id in entity["holders"]:
        total += get_voting_power(entity_id, str(holder_id))
    return total

func get_voting_power(entity_id: String, holder_id: String) -> float:
    var entity: Variant = _entity(entity_id)
    if entity.is_empty(): return 0.0
    var holder: Variant = entity["holders"].get(holder_id, {})
    var votes: Variant = 0.0
    for share_class_name in holder.get("classes", {}):
        var class_info: Dictionary = entity["share_classes"].get(share_class_name, {})
        votes += float(holder["classes"][share_class_name]) * float(class_info.get("votes_per_share", 1.0))
    return votes

func get_ownership_percent(entity_id: String, holder_id: String) -> float:
    var entity: Variant = _entity(entity_id)
    var denominator: float = float(entity.get("issued_shares", 0))
    if str(entity.get("type", ENTITY_COMPANY)) == ENTITY_JV:
        denominator = float(entity.get("authorized_shares", denominator))
    if denominator <= 0.0: return 0.0
    var holder: Variant = entity.get("holders", {}).get(holder_id, {})
    var shares: Variant = 0
    for share_class_name in holder.get("classes", {}):
        shares += int(holder["classes"][share_class_name])
    return float(shares) * 100.0 / denominator

func get_voting_percent(entity_id: String, holder_id: String) -> float:
    var total: Variant = get_total_votes(entity_id)
    if total <= 0.0: return 0.0
    return get_voting_power(entity_id, holder_id) * 100.0 / total

func holders(entity_id: String) -> Array[Dictionary]:
    var entity: Variant = _entity(entity_id)
    var result: Array[Dictionary] = []
    for holder_id in entity.get("holders", {}):
        result.append({"holder_id": str(holder_id), "ownership": get_ownership_percent(entity_id, str(holder_id)), "voting": get_voting_percent(entity_id, str(holder_id))})
    result.sort_custom(func(a, b): return float(a["ownership"]) > float(b["ownership"]))
    return result

func has_control(entity_id: String, holder_id: String, threshold_name: String = "ordinary") -> bool:
    var entity: Variant = _entity(entity_id)
    var threshold: Variant = float(entity.get("control_thresholds", {}).get(threshold_name, 0.50)) * 100.0
    return get_voting_percent(entity_id, holder_id) >= threshold

func set_control_threshold(entity_id: String, name: String, fraction: float) -> Dictionary:
    if not entities.has(entity_id) or fraction <= 0.0 or fraction > 1.0:
        return {"ok": false, "error": "invalid_threshold"}
    entities[entity_id]["control_thresholds"][name] = fraction
    _record(entity_id, "control_threshold", {"name": name, "fraction": fraction})
    return {"ok": true, "threshold": fraction}

func set_board_size(entity_id: String, seat_count: int) -> Dictionary:
    if not entities.has(entity_id) or seat_count <= 0:
        return {"ok": false, "error": "invalid_board_size"}
    entities[entity_id]["board"]["seat_count"] = seat_count
    return {"ok": true, "seat_count": seat_count}

func appoint_board_seat(entity_id: String, holder_id: String, seat_id: String = "") -> Dictionary:
    if not entities.has(entity_id) or holder_id.is_empty():
        return {"ok": false, "error": "invalid_appointment"}
    var board: Dictionary = entities[entity_id]["board"]
    var seat_count: Variant = int(board["seat_count"])
    if board["seats"].size() >= seat_count and not board["seats"].has(seat_id):
        return {"ok": false, "error": "board_full"}
    if seat_id.is_empty():
        seat_id = "seat_%d" % (board["seats"].size() + 1)
    board["seats"][seat_id] = holder_id
    _record(entity_id, "board_appointment", {"seat_id": seat_id, "holder_id": holder_id})
    return {"ok": true, "seat_id": seat_id, "holder_id": holder_id}

func remove_board_seat(entity_id: String, seat_id: String) -> Dictionary:
    if not entities.has(entity_id): return {"ok": false, "error": "entity_not_found"}
    var board: Dictionary = entities[entity_id]["board"]
    if not board["seats"].has(seat_id): return {"ok": false, "error": "seat_not_found"}
    board["seats"].erase(seat_id)
    return {"ok": true}

func get_board_seats(entity_id: String, holder_id: String = "") -> int:
    var entity: Variant = _entity(entity_id)
    var count: Variant = 0
    for seat_id in entity.get("board", {}).get("seats", {}):
        if holder_id.is_empty() or str(entity["board"]["seats"][seat_id]) == holder_id:
            count += 1
    return count

func board_control_percent(entity_id: String, holder_id: String) -> float:
    var entity: Variant = _entity(entity_id)
    var seats: Variant = int(entity.get("board", {}).get("seat_count", 0))
    if seats <= 0: return 0.0
    return float(get_board_seats(entity_id, holder_id)) * 100.0 / seats

func distribute_dividend(entity_id: String, amount: float, holder_filter: String = "") -> Dictionary:
    if not entities.has(entity_id) or amount <= 0.0:
        return {"ok": false, "error": "invalid_dividend"}
    var entity: Variant = entities[entity_id]
    var issued: Variant = float(entity["issued_shares"])
    if issued <= 0.0:
        return {"ok": false, "error": "no_shares"}
    var payouts: Dictionary = {}
    var total_paid: Variant = 0.0
    for holder_id in entity["holders"]:
        if not holder_filter.is_empty() and str(holder_id) != holder_filter:
            continue
        var holder: Variant = entity["holders"][holder_id]
        var shares: Variant = 0
        for share_class_name in holder.get("classes", {}):
            var multiplier: Variant = float(entity["share_classes"].get(share_class_name, {}).get("dividend_multiplier", 1.0))
            shares += int(round(float(holder["classes"][share_class_name]) * multiplier))
        var payout: Variant = amount * float(shares) / issued
        payouts[holder_id] = payout
        total_paid += payout
    entity["dividend_pool"] += total_paid
    entities[entity_id] = entity
    _record(entity_id, "dividend", {"amount": amount, "paid": total_paid, "payouts": payouts})
    return {"ok": true, "amount": amount, "paid": total_paid, "payouts": payouts}

func set_investor_confidence(entity_id: String, confidence: float) -> Dictionary:
    if not entities.has(entity_id): return {"ok": false, "error": "entity_not_found"}
    entities[entity_id]["investor_confidence"] = clamp(confidence, 0.0, 100.0)
    return {"ok": true, "confidence": entities[entity_id]["investor_confidence"]}

func adjust_investor_confidence(entity_id: String, delta: float, reason: String = "") -> Dictionary:
    if not entities.has(entity_id): return {"ok": false, "error": "entity_not_found"}
    var confidence: Variant = clamp(float(entities[entity_id]["investor_confidence"]) + delta, 0.0, 100.0)
    entities[entity_id]["investor_confidence"] = confidence
    _record(entity_id, "confidence", {"delta": delta, "value": confidence, "reason": reason})
    return {"ok": true, "confidence": confidence}

func set_defense(entity_id: String, level: int, poison_pill_enabled: bool = false) -> Dictionary:
    if not entities.has(entity_id): return {"ok": false, "error": "entity_not_found"}
    entities[entity_id]["defense_level"] = max(0, level)
    entities[entity_id]["poison_pill"] = poison_pill_enabled
    _record(entity_id, "defense", {"level": level, "poison_pill": poison_pill_enabled})
    return {"ok": true, "defense_level": entities[entity_id]["defense_level"], "poison_pill": poison_pill_enabled}

func takeover_control(entity_id: String, bidder_id: String, required_percent: float = 50.0) -> Dictionary:
    if not entities.has(entity_id): return {"ok": false, "error": "entity_not_found"}
    if required_percent <= 0.0 or required_percent > 100.0: return {"ok": false, "error": "invalid_control_target"}
    var current: Variant = get_voting_percent(entity_id, bidder_id)
    if current < required_percent:
        return {"ok": false, "error": "insufficient_voting_control", "current_percent": current, "required_percent": required_percent}
    var entity: Variant = entities[entity_id]
    var board_percent: Variant = board_control_percent(entity_id, bidder_id)
    var board_majority: Variant = board_percent > 50.0
    _record(entity_id, "takeover_control", {"bidder": bidder_id, "voting_percent": current, "board_percent": board_percent})
    return {"ok": true, "controlled": true, "voting_percent": current, "board_percent": board_percent, "board_majority": board_majority, "entity": entity.duplicate(true)}

func get_control_snapshot(entity_id: String) -> Dictionary:
    var entity: Variant = _entity(entity_id)
    if entity.is_empty(): return {}
    var top_holder: Variant = ""
    var top_ownership: Variant = 0.0
    for item in holders(entity_id):
        if float(item["ownership"]) > top_ownership:
            top_holder = str(item["holder_id"])
            top_ownership = float(item["ownership"])
    return {
        "entity_id": entity_id,
        "type": entity["type"],
        "issued_shares": entity["issued_shares"],
        "authorized_shares": entity["authorized_shares"],
        "treasury_shares": entity["treasury_shares"],
        "top_holder": top_holder,
        "top_ownership": top_ownership,
        "top_voting_percent": get_voting_percent(entity_id, top_holder),
        "board_seats": entity["board"]["seat_count"],
        "board_filled": entity["board"]["seats"].size(),
        "investor_confidence": entity["investor_confidence"],
        "defense_level": entity["defense_level"],
        "poison_pill": entity["poison_pill"]
    }

func save_state() -> Dictionary:
    return {"entities": entities.duplicate(true), "transaction_log": transaction_log.duplicate(true), "next_transaction_id": next_transaction_id}

func load_state(state: Dictionary) -> void:
    entities = state.get("entities", {}).duplicate(true)
    transaction_log = state.get("transaction_log", []).duplicate(true)
    next_transaction_id = int(state.get("next_transaction_id", transaction_log.size() + 1))
