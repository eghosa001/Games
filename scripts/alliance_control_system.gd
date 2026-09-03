extends Node

## Alliance leadership and control-transfer layer.
## Handles peaceful succession and successful NPC coups without bypassing the
## persistent AllianceSystem state.

const ROLE_CHAIRMAN := "chairman"
const ROLE_DIRECTOR := "director"

func transfer_chairman(alliance_id: String, current_id: String, successor_id: String, reason: String = "leadership succession") -> Dictionary:
    var system: Variant = get_node_or_null("/root/RenewAllianceSystem")
    if system == null: return {"ok": false, "message": "AllianceSystem unavailable."}
    var alliance: Dictionary = system.alliances.get(alliance_id, {})
    if alliance.is_empty() or str(alliance.get("status", "")) != "active": return {"ok": false, "message": "Alliance is unavailable."}
    var members: Dictionary = alliance.get("members", {})
    if not members.has(current_id) or not members.has(successor_id): return {"ok": false, "message": "Both leaders must be alliance members."}
    if str(alliance.get("founder_id", "")) != current_id: return {"ok": false, "message": "Current member is not the Chairman."}
    if current_id == successor_id: return {"ok": false, "message": "Successor must be different from the current Chairman."}
    members[current_id]["role"] = ROLE_DIRECTOR
    members[successor_id]["role"] = ROLE_CHAIRMAN
    alliance["founder_id"] = successor_id
    alliance["governance"]["last_control_change"] = system._day()
    alliance["governance"]["previous_chairman"] = current_id
    system.alliances[alliance_id] = alliance
    system._event("chairman_changed", "%s became Chairman of %s (%s)." % [successor_id, alliance.get("name", alliance_id), reason], {"alliance_id": alliance_id, "from": current_id, "to": successor_id, "reason": reason})
    return {"ok": true, "alliance": system.get_alliance(alliance_id), "message": "%s is now Chairman." % successor_id}

func execute_coup(alliance_id: String, challenger_id: String, support_ratio: float, reason: String = "governance coup") -> Dictionary:
    var system: Variant = get_node_or_null("/root/RenewAllianceSystem")
    if system == null: return {"ok": false, "message": "AllianceSystem unavailable."}
    var alliance: Dictionary = system.alliances.get(alliance_id, {})
    if alliance.is_empty(): return {"ok": false, "message": "Alliance not found."}
    var members: Dictionary = alliance.get("members", {})
    if not members.has(challenger_id): return {"ok": false, "message": "Challenger is not a member."}
    var chairman_id: Variant = str(alliance.get("founder_id", ""))
    if challenger_id == chairman_id: return {"ok": false, "message": "Chairman cannot coup themselves."}
    if support_ratio < 0.67: return {"ok": false, "message": "A control challenge requires at least 67% member support."}
    var challenger_role: Variant = str(members[challenger_id].get("role", ""))
    if challenger_role != ROLE_DIRECTOR: return {"ok": false, "message": "Only a Director can lead a control challenge."}
    return transfer_chairman(alliance_id, chairman_id, challenger_id, reason)
