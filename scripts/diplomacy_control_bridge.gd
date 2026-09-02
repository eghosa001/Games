extends Node

## Connects formal diplomacy to ownership/control, assets and joint ventures.
## Treaty terms remain authoritative; this bridge materializes those terms in the
## OwnershipSystem and exposes defense commitments to acquisition gameplay.

var applied: Dictionary = {}
var defense_pacts: Dictionary = {}
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
    _sync(diplomacy, day)

func _sync(diplomacy, day: int) -> void:
    var active_ids: Dictionary = {}
    for treaty in diplomacy.list_treaties("active"):
        var id := str(treaty.get("id", ""))
        active_ids[id] = true
        _apply_treaty(treaty, day)
    for id in applied.keys():
        if not active_ids.has(id): applied.erase(id)
    defense_pacts.clear()
    for treaty in diplomacy.list_treaties("active"):
        if str(treaty.get("type", "")) != "defense": continue
        var a := str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
        defense_pacts[_defense_key(a, b)] = {"treaty_id": str(treaty.get("id", "")), "expires": int(treaty.get("end_day", -1))}

func _apply_treaty(treaty: Dictionary, day: int) -> void:
    var id := str(treaty.get("id", ""))
    if id.is_empty(): return
    if not applied.has(id): applied[id] = {}
    var state: Dictionary = applied[id]
    match str(treaty.get("type", "")):
        "territory":
            _apply_territory(treaty, state)
        "joint_venture":
            _apply_joint_venture(treaty, state)
        "defense":
            state["defense_active"] = true
    state["last_day"] = day
    applied[id] = state

func _apply_territory(treaty: Dictionary, state: Dictionary) -> void:
    if bool(state.get("materialized", false)): return
    var ownership = get_node_or_null("/root/RenewOwnershipSystem")
    if ownership == null: return
    var terms: Dictionary = treaty.get("terms", {})
    var territory_id := str(terms.get("territory_id", ""))
    if territory_id.is_empty(): return
    var entity_id := "territory:%s" % territory_id
    if not ownership.has_entity(entity_id):
        ownership.register_entity(entity_id, ownership.ENTITY_ASSET, 1000000, 1.0)
        var initial_owner := str(terms.get("current_owner", treaty.get("party_b", "")))
        if not initial_owner.is_empty(): ownership.issue_shares(entity_id, initial_owner, 1000000, ownership.VOTE_ORDINARY, "territory treaty initialization")
    var recipient := str(terms.get("recipient", treaty.get("party_a", "")))
    var donor := str(terms.get("transferor", terms.get("current_owner", treaty.get("party_b", ""))))
    var transfer_percent := clampf(float(terms.get("transfer_percent", 0.0)), 0.0, 100.0)
    if transfer_percent > 0.0 and not recipient.is_empty() and not donor.is_empty() and recipient != donor:
        var donor_pct := ownership.get_ownership_percent(entity_id, donor)
        var quantity := int(floor(1000000.0 * min(transfer_percent, donor_pct) / 100.0))
        if quantity > 0: ownership.transfer_shares(entity_id, donor, recipient, quantity, ownership.VOTE_ORDINARY, "territory treaty:%s" % treaty.get("id", ""))
    var control_threshold := float(terms.get("control_threshold", 50.1))
    state["territory_id"] = territory_id
    state["entity_id"] = entity_id
    state["recipient"] = recipient
    state["control_percent"] = ownership.get_ownership_percent(entity_id, recipient)
    state["controls_territory"] = state["control_percent"] >= control_threshold
    state["materialized"] = true

func _apply_joint_venture(treaty: Dictionary, state: Dictionary) -> void:
    if bool(state.get("materialized", false)): return
    var ownership = get_node_or_null("/root/RenewOwnershipSystem")
    if ownership == null: return
    var terms: Dictionary = treaty.get("terms", {})
    var venture_name := str(terms.get("venture_name", "JV %s" % treaty.get("id", "")))
    var venture_id := "jv:%s" % treaty.get("id", "")
    if not ownership.has_entity(venture_id):
        var created := ownership.register_entity(venture_id, ownership.ENTITY_JV, 1000000, 1.0)
        if bool(created.get("ok", false)):
            var a := str(treaty.get("party_a", "")); var b := str(treaty.get("party_b", ""))
            var a_pct := clampf(float(terms.get("party_a_percent", 50.0)), 0.0, 100.0)
            var b_pct := clampf(float(terms.get("party_b_percent", 100.0 - a_pct)), 0.0, 100.0)
            if not a.is_empty() and a_pct > 0.0: ownership.issue_shares(venture_id, a, int(round(a_pct * 10000.0)), ownership.VOTE_ORDINARY, "joint venture formation")
            if not b.is_empty() and b_pct > 0.0: ownership.issue_shares(venture_id, b, int(round(b_pct * 10000.0)), ownership.VOTE_ORDINARY, "joint venture formation")
    state["venture_id"] = venture_id
    state["venture_name"] = venture_name
    state["party_a_ownership"] = ownership.get_ownership_percent(venture_id, str(treaty.get("party_a", "")))
    state["party_b_ownership"] = ownership.get_ownership_percent(venture_id, str(treaty.get("party_b", "")))
    state["control_party"] = str(treaty.get("party_a", "")) if state["party_a_ownership"] >= state["party_b_ownership"] else str(treaty.get("party_b", ""))
    state["materialized"] = true

func has_defense_treaty(party_a: String, party_b: String) -> bool:
    return defense_pacts.has(_defense_key(party_a, party_b))

func get_defense_treaty(party_a: String, party_b: String) -> Dictionary:
    return defense_pacts.get(_defense_key(party_a, party_b), {}).duplicate(true)

func get_materialized_state(treaty_id: String) -> Dictionary:
    return applied.get(treaty_id, {}).duplicate(true)

func capture_state() -> Dictionary:
    return {"system_version": 1, "last_day": last_day, "applied": applied.duplicate(true), "defense_pacts": defense_pacts.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    last_day = int(state.get("last_day", -1))
    applied = state.get("applied", {}).duplicate(true)
    defense_pacts = state.get("defense_pacts", {}).duplicate(true)

func _defense_key(a: String, b: String) -> String:
    return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
