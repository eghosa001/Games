extends Node

## Connects formal diplomacy to ownership/control, assets and joint ventures.
## Treaty terms remain authoritative; this bridge materializes those terms in the
## OwnershipSystem and exposes defense commitments to acquisition gameplay.

var applied: Dictionary = {}
var defense_pacts: Dictionary = {}
var last_day: Variant = -1

func _service(service_name: String):
    var registry := get_node_or_null("/root/RenewServices")
    if registry != null and registry.has_method("get_service"):
        var node = registry.get_service(service_name)
        if node != null:
            return node
    return get_node_or_null("/root/" + service_name)

func _process(_delta: float) -> void:
    var tree: Variant = Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null: return
    var day: Variant = int(scene.get("day"))
    if day == last_day: return
    last_day = day
    var diplomacy = _service("RenewDiplomacySystem")
    if diplomacy == null: return
    _sync(diplomacy, day)

func _ownership():
    var root = get_node_or_null("/root/RenewOwnershipSystem")
    if root != null: return root
    var tree: Variant = Engine.get_main_loop()
    var scene = tree.get_current_scene() if tree != null else null
    if scene == null: return null
    var ownership = scene.get_node_or_null("Systems/OwnershipSystem")
    if ownership == null: ownership = scene.get_node_or_null("OwnershipSystem")
    return ownership

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _sync(diplomacy, day: int) -> void:
    var active_ids: Dictionary = {}
    for treaty in diplomacy.list_treaties("active"):
        var id: Variant = str(treaty.get("id", ""))
        active_ids[id] = true
        _apply_treaty(treaty, day)
    var statuses: Dictionary = {}
    for treaty in diplomacy.list_treaties(""):
        statuses[str(treaty.get("id", ""))] = str(treaty.get("status", ""))
    for id in applied.keys():
        if not active_ids.has(id) and str(statuses.get(id, "expired")) == "expired":
            applied.erase(id)
    defense_pacts.clear()
    for treaty in diplomacy.list_treaties("active"):
        if str(treaty.get("type", "")) != "defense": continue
        var a: Variant = str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
        defense_pacts[_defense_key(a, b)] = {"treaty_id": str(treaty.get("id", "")), "expires": int(treaty.get("end_day", -1))}

func _apply_treaty(treaty: Dictionary, day: int) -> void:
    var id: Variant = str(treaty.get("id", ""))
    if id.is_empty(): return
    if not applied.has(id): applied[id] = {}
    var state: Dictionary = applied[id]
    match str(treaty.get("type", "")):
        "territory": _apply_territory(treaty, state)
        "joint_venture": _apply_joint_venture(treaty, state)
        "defense": state["defense_active"] = true
    state["last_day"] = day
    applied[id] = state

func _apply_territory(treaty: Dictionary, state: Dictionary) -> void:
    if bool(state.get("materialized", false)): return
    var ownership = _ownership()
    if ownership == null: return
    var terms: Dictionary = treaty.get("terms", {})
    var territory_id: Variant = str(terms.get("territory_id", ""))
    if territory_id.is_empty(): return
    var entity_id: Variant = "territory:%s" % territory_id
    if not ownership.has_entity(entity_id):
        ownership.register_entity(entity_id, ownership.ENTITY_ASSET, 1000000, 1.0)
        var initial_owner: Variant = str(terms.get("current_owner", treaty.get("party_b", "")))
        if not initial_owner.is_empty(): ownership.issue_shares(entity_id, initial_owner, 1000000, ownership.VOTE_ORDINARY, "territory treaty initialization")
    var recipient: Variant = str(terms.get("recipient", treaty.get("party_a", "")))
    var donor: Variant = str(terms.get("transferor", terms.get("current_owner", treaty.get("party_b", ""))))
    var transfer_percent: Variant = clampf(float(terms.get("transfer_percent", 0.0)), 0.0, 100.0)
    if transfer_percent > 0.0 and not recipient.is_empty() and not donor.is_empty() and recipient != donor:
        var donor_pct: Variant = ownership.get_ownership_percent(entity_id, donor)
        var quantity: Variant = int(floor(1000000.0 * min(transfer_percent, donor_pct) / 100.0))
        if quantity > 0: ownership.transfer_shares(entity_id, donor, recipient, quantity, ownership.VOTE_ORDINARY, "territory treaty:%s" % treaty.get("id", ""))
    var control_threshold: Variant = float(terms.get("control_threshold", 50.1))
    var asset_value: Variant = max(0.0, float(terms.get("asset_value", terms.get("territory_value", 0.0))))
    state["territory_id"] = territory_id
    state["entity_id"] = entity_id
    state["recipient"] = recipient
    state["control_percent"] = ownership.get_ownership_percent(entity_id, recipient)
    state["controls_territory"] = state["control_percent"] >= control_threshold
    state["asset_value"] = asset_value
    state["materialized"] = true

func _apply_joint_venture(treaty: Dictionary, state: Dictionary) -> void:
    if bool(state.get("materialized", false)):
        _settle_joint_venture(treaty, state)
        return
    var ownership = _ownership()
    if ownership == null: return
    var terms: Dictionary = treaty.get("terms", {})
    var venture_name: Variant = str(terms.get("venture_name", "JV %s" % treaty.get("id", "")))
    var venture_id: Variant = "jv:%s" % treaty.get("id", "")
    if not ownership.has_entity(venture_id):
        var created: Variant = ownership.register_entity(venture_id, ownership.ENTITY_JV, 1000000, 1.0)
        if bool(created.get("ok", false)):
            var a: Variant = str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
            var a_pct: Variant = clampf(float(terms.get("party_a_percent", 50.0)), 0.0, 100.0)
            var b_pct: Variant = clampf(float(terms.get("party_b_percent", 100.0 - a_pct)), 0.0, 100.0)
            if not a.is_empty() and a_pct > 0.0: ownership.issue_shares(venture_id, a, int(round(a_pct * 10000.0)), ownership.VOTE_ORDINARY, "joint venture formation")
            if not b.is_empty() and b_pct > 0.0: ownership.issue_shares(venture_id, b, int(round(b_pct * 10000.0)), ownership.VOTE_ORDINARY, "joint venture formation")
    var asset_value: Variant = max(0.0, float(terms.get("asset_value", terms.get("initial_capital", terms.get("joint_capital", 0.0)))))
    var asset_id: Variant = "jv_asset:%s" % treaty.get("id", "")
    if asset_value > 0.0 and not ownership.has_entity(asset_id):
        var asset_created: Variant = ownership.register_entity(asset_id, ownership.ENTITY_ASSET, 1000000, 1.0)
        if bool(asset_created.get("ok", false)):
            ownership.issue_shares(asset_id, venture_id, 1000000, ownership.VOTE_ORDINARY, "joint venture asset capitalization")
    state["funded"] = bool(state.get("funded", false))
    if not state["funded"]:
        _fund_joint_venture(treaty, state)
    else:
        _settle_joint_venture(treaty, state)
    state["venture_id"] = venture_id
    state["venture_name"] = venture_name
    state["asset_id"] = asset_id
    state["asset_value"] = asset_value
    state["party_a_ownership"] = ownership.get_ownership_percent(venture_id, str(treaty.get("party_a", "")))
    state["party_b_ownership"] = ownership.get_ownership_percent(venture_id, str(treaty.get("party_b", "")))
    state["control_party"] = str(treaty.get("party_a", "")) if state["party_a_ownership"] >= state["party_b_ownership"] else str(treaty.get("party_b", ""))
    state["materialized"] = true

func _fund_joint_venture(treaty: Dictionary, state: Dictionary) -> void:
    var finance = _finance()
    if finance == null: return
    var terms: Dictionary = treaty.get("terms", {})
    var total := max(0, int(round(float(terms.get("joint_capital", 3000.0)))))
    if total <= 0: return
    var player_pct := _party_percent(treaty, "player")
    var player_amount := int(round(float(total) * player_pct / 100.0))
    var paid: Dictionary = finance.spend(player_amount, "joint venture capital:%s" % treaty.get("id", ""))
    if not bool(paid.get("ok", false)):
        state["funding_blocked"] = true
        return
    state["funding_blocked"] = false
    var scene = _scene()
    if scene != null and scene.get("rivals") != null:
        for rival in scene.get("rivals").rivals:
            if rival is Dictionary and str(rival.get("id", "")) != "player" and (str(rival.get("id", "")) == str(treaty.get("party_a", "")) or str(rival.get("id", "")) == str(treaty.get("party_b", ""))):
                rival["cash"] = max(0, int(rival.get("cash", 0)) - max(0, total - player_amount))
    state["funded"] = true
    state["funded_capital"] = total
    state["last_payout_day"] = -1

func _settle_joint_venture(treaty: Dictionary, state: Dictionary) -> void:
    if not bool(state.get("funded", false)): return
    var scene = _scene()
    var day := -1
    if scene != null: day = int(scene.get("day"))
    if day >= 0 and int(state.get("last_payout_day", -1)) == day: return
    var finance = _finance()
    if finance == null: return
    var profit := int(round(float(state.get("funded_capital", 0)) * 0.015))
    if profit <= 0: return
    var player_pct := _party_percent(treaty, "player")
    var player_share := int(round(float(profit) * player_pct / 100.0))
    if player_share > 0: finance.receive(player_share, "joint venture profit:%s" % treaty.get("id", ""))
    if scene != null and scene.get("rivals") != null:
        for rival in scene.get("rivals").rivals:
            if rival is Dictionary and (str(rival.get("id", "")) == str(treaty.get("party_a", "")) or str(rival.get("id", "")) == str(treaty.get("party_b", ""))) and str(rival.get("id", "")) != "player":
                rival["cash"] = max(0, int(rival.get("cash", 0)) + max(0, profit - player_share))
    state["last_payout_day"] = day
    state["total_paid_out"] = int(state.get("total_paid_out", 0)) + profit

func _party_percent(treaty: Dictionary, party_id: String) -> float:
    var terms: Dictionary = treaty.get("terms", {})
    if str(treaty.get("party_a", "")) == party_id:
        return clampf(float(terms.get("party_a_percent", 50.0)), 0.0, 100.0)
    return clampf(float(terms.get("party_b_percent", 50.0)), 0.0, 100.0)

func _scene():
    var tree: Variant = Engine.get_main_loop()
    return tree.get_current_scene() if tree != null else null

func has_defense_treaty(party_a: String, party_b: String) -> bool:
    return defense_pacts.has(_defense_key(party_a, party_b))

func get_defense_treaty(party_a: String, party_b: String) -> Dictionary:
    return defense_pacts.get(_defense_key(party_a, party_b), {}).duplicate(true)

func get_materialized_state(treaty_id: String) -> Dictionary:
    return applied.get(treaty_id, {}).duplicate(true)

func capture_state() -> Dictionary:
    return {"system_version": 2, "last_day": last_day, "applied": applied.duplicate(true), "defense_pacts": defense_pacts.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    last_day = int(state.get("last_day", -1))
    applied = state.get("applied", {}).duplicate(true)
    defense_pacts = state.get("defense_pacts", {}).duplicate(true)

func _defense_key(a: String, b: String) -> String:
    return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
