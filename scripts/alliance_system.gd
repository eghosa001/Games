extends Node

## RENEW AllianceSystem.
## Persistent player-created organizations with members, treasury, shared assets,
## infrastructure, technology/research, reputation/trust, governance, treaties,
## contributions, sanctions, projects and voting.

const STATUS_ACTIVE := "active"
const STATUS_DISSOLVED := "dissolved"
const ROLE_CHAIRMAN := "chairman"
const ROLE_DIRECTOR := "director"
const ROLE_MEMBER := "member"

var alliances: Dictionary = {}
var member_alliance: Dictionary = {}
var next_alliance_id: Variant = 1
var events: Array = []

func create_alliance(founder_id: String, name: String, treasury: int = 0) -> Dictionary:
    if founder_id.is_empty() or name.strip_edges().is_empty(): return {"ok": false, "message": "Founder and alliance name are required."}
    if member_alliance.has(founder_id): return {"ok": false, "message": "Founder is already in an alliance."}
    if treasury < 0: return {"ok": false, "message": "Treasury cannot be negative."}
    var id: Variant = "alliance_%d" % next_alliance_id
    next_alliance_id += 1
    alliances[id] = {
        "id": id, "name": name.strip_edges(), "status": STATUS_ACTIVE,
        "founder_id": founder_id, "members": {founder_id: {"role": ROLE_CHAIRMAN, "shares": 100.0, "contributed": treasury, "joined_day": _day()}},
        "treasury": treasury, "assets": [], "infrastructure": [], "technology": [], "research": [],
        "reputation": 25.0, "trust": 50.0,
        "governance": {"voting_threshold": 50.0, "director_threshold": 25.0, "chairman_veto": true, "sanctions_threshold": 66.7},
        "treaties": [], "contributions": [], "projects": [], "sanctions": [], "votes": {},
        "created_day": _day()
    }
    member_alliance[founder_id] = id
    _event("alliance_created", "Alliance %s created" % name, {"alliance_id": id, "founder": founder_id})
    return {"ok": true, "alliance": get_alliance(id), "message": "Alliance %s created. You are Chairman." % name}

func join_alliance(alliance_id: String, member_id: String, role: String = ROLE_MEMBER) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != STATUS_ACTIVE: return {"ok": false, "message": "Alliance is unavailable."}
    if member_id.is_empty() or member_alliance.has(member_id): return {"ok": false, "message": "Member is already in an alliance or invalid."}
    if not [ROLE_MEMBER, ROLE_DIRECTOR].has(role): role = ROLE_MEMBER
    alliance["members"][member_id] = {"role": role, "shares": 0.0, "contributed": 0, "joined_day": _day()}
    alliances[alliance_id] = alliance
    member_alliance[member_id] = alliance_id
    alliance["reputation"] = min(100.0, float(alliance["reputation"]) + 1.0)
    _event("member_joined", "%s joined %s" % [member_id, alliance["name"]], {"alliance_id": alliance_id, "member": member_id})
    return {"ok": true, "alliance": get_alliance(alliance_id), "message": "%s joined the alliance." % member_id}

func leave_alliance(member_id: String) -> Dictionary:
    var alliance_id: Variant = str(member_alliance.get(member_id, ""))
    if alliance_id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty(): member_alliance.erase(member_id); return {"ok": false, "message": "Alliance not found."}
    if str(alliance.get("founder_id", "")) == member_id: return {"ok": false, "message": "Chairman must transfer leadership or dissolve the alliance."}
    alliance["members"].erase(member_id); alliances[alliance_id] = alliance; member_alliance.erase(member_id)
    return {"ok": true, "message": "%s left %s." % [member_id, alliance["name"]]}

func contribute(member_id: String, amount: int) -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Contribution must be positive."}
    var alliance: Variant = _member_org(member_id)
    if alliance.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    alliance["treasury"] = int(alliance["treasury"]) + amount
    alliance["members"][member_id]["contributed"] = int(alliance["members"][member_id].get("contributed", 0)) + amount
    alliance["contributions"].append({"member": member_id, "amount": amount, "day": _day()})
    alliance["trust"] = min(100.0, float(alliance["trust"]) + min(3.0, amount / 10000.0))
    _write_org(alliance)
    return {"ok": true, "treasury": alliance["treasury"], "message": "Alliance treasury increased by $%d." % amount}

func withdraw(member_id: String, amount: int, purpose: String = "alliance spending") -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Withdrawal must be positive."}
    var alliance: Variant = _member_org(member_id)
    if alliance.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    if not _can_govern(alliance, member_id): return {"ok": false, "message": "Only the Chairman or Directors can authorize treasury spending."}
    if int(alliance["treasury"]) < amount: return {"ok": false, "message": "Alliance treasury cannot cover this expense."}
    alliance["treasury"] = int(alliance["treasury"]) - amount
    alliance["events"] = alliance.get("events", [])
    _event("treasury_withdrawal", purpose, {"alliance_id": alliance["id"], "member": member_id, "amount": amount})
    _write_org(alliance)
    return {"ok": true, "treasury": alliance["treasury"], "message": "Alliance spent $%d on %s." % [amount, purpose]}

func add_asset(alliance_id: String, asset_name: String, value: int, contributor_id: String) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or value <= 0 or asset_name.is_empty(): return {"ok": false, "message": "Invalid alliance asset."}
    if not alliance["members"].has(contributor_id): return {"ok": false, "message": "Contributor is not a member."}
    alliance["assets"].append({"name": asset_name, "value": value, "owner": alliance_id, "day": _day()})
    alliance["reputation"] = min(100.0, float(alliance["reputation"]) + 1.0)
    _write_org(alliance)
    return {"ok": true, "asset": alliance["assets"].back(), "message": "Alliance acquired %s." % asset_name}

func add_infrastructure(alliance_id: String, name: String, level: int = 1, cost: int = 0) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or name.is_empty() or level <= 0: return {"ok": false, "message": "Invalid infrastructure."}
    if cost > int(alliance["treasury"]): return {"ok": false, "message": "Alliance treasury cannot fund this infrastructure."}
    alliance["treasury"] = int(alliance["treasury"]) - max(0, cost)
    alliance["infrastructure"].append({"name": name, "level": level, "cost": cost, "day": _day()})
    _write_org(alliance)
    return {"ok": true, "message": "Alliance infrastructure %s established at level %d." % [name, level]}

func add_technology(alliance_id: String, technology: String, cost: int = 0) -> Dictionary:
    return _add_research_asset(alliance_id, "technology", technology, cost)

func fund_research(alliance_id: String, project: String, cost: int = 0) -> Dictionary:
    var result: Variant = _add_research_asset(alliance_id, "research", project, cost)
    if bool(result.get("ok", false)):
        var alliance: Variant = alliances[alliance_id]
        alliance["projects"].append({"name": project, "type": "research", "status": "active", "funded": cost, "day": _day()})
        _write_org(alliance)
    return result

func propose_treaty(alliance_id: String, other_alliance_id: String, treaty_type: String, terms: Dictionary = {}) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    var other: Variant = alliances.get(other_alliance_id, {})
    if alliance.is_empty() or other.is_empty() or alliance_id == other_alliance_id: return {"ok": false, "message": "Both alliances must exist and be different."}
    var treaty: Variant = {"id": "treaty_%d_%d" % [_day(), alliance["treaties"].size() + 1], "with": other_alliance_id, "type": treaty_type, "terms": terms.duplicate(true), "status": "proposed", "day": _day()}
    alliance["treaties"].append(treaty); _write_org(alliance)
    return {"ok": true, "treaty": treaty, "message": "Treaty proposed to %s." % other["name"]}

func accept_treaty(alliance_id: String, treaty_index: int) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or treaty_index < 0 or treaty_index >= alliance["treaties"].size(): return {"ok": false, "message": "Treaty not found."}
    var treaty: Dictionary = alliance["treaties"][treaty_index]
    var other: Variant = alliances.get(str(treaty.get("with", "")), {})
    if other.is_empty(): return {"ok": false, "message": "Other alliance no longer exists."}
    treaty["status"] = "active"; alliance["treaties"][treaty_index] = treaty
    alliances[alliance_id] = alliance
    _mirror_treaty(other, alliance_id, treaty)
    alliance["trust"] = min(100.0, float(alliance["trust"]) + 5.0); _write_org(alliance)
    return {"ok": true, "message": "Treaty with %s is now active." % other["name"]}

func vote(alliance_id: String, voter_id: String, motion_id: String, choice: bool) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or not alliance["members"].has(voter_id): return {"ok": false, "message": "Voter is not a member."}
    var motion: Variant = alliance["votes"].get(motion_id, {"yes": [], "no": [], "status": "open"})
    if motion.status == "passed" or motion.status == "rejected": return {"ok": false, "message": "Vote is already closed."}
    motion["yes"].erase(voter_id); motion["no"].erase(voter_id)
    motion["yes"].append(voter_id) if choice else motion["no"].append(voter_id)
    alliance["votes"][motion_id] = motion; _write_org(alliance)
    return resolve_vote(alliance_id, motion_id)

func open_vote(alliance_id: String, proposer_id: String, motion_id: String, motion: String) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or not alliance["members"].has(proposer_id): return {"ok": false, "message": "Only members can open votes."}
    alliance["votes"][motion_id] = {"motion": motion, "proposer": proposer_id, "yes": [], "no": [], "status": "open", "day": _day()}
    _write_org(alliance)
    return {"ok": true, "message": "Vote opened: %s" % motion}

func resolve_vote(alliance_id: String, motion_id: String) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or not alliance["votes"].has(motion_id): return {"ok": false, "message": "Vote not found."}
    var motion: Dictionary = alliance["votes"][motion_id]
    var total: Variant = max(1, alliance["members"].size())
    var yes_ratio: Variant = float(motion["yes"].size()) / float(total) * 100.0
    if yes_ratio >= float(alliance["governance"].get("voting_threshold", 50.0)): motion["status"] = "passed"
    alliance["votes"][motion_id] = motion; _write_org(alliance)
    return {"ok": true, "status": motion["status"], "yes_percent": yes_ratio, "message": "Vote %s (%0.1f%% yes)." % [motion["status"], yes_ratio]}

func sanction(alliance_id: String, target_member_id: String, reason: String) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or not alliance["members"].has(target_member_id): return {"ok": false, "message": "Member is not in this alliance."}
    var entry: Variant = {"member": target_member_id, "reason": reason, "active": true, "day": _day()}
    alliance["sanctions"].append(entry); alliance["trust"] = max(0.0, float(alliance["trust"]) - 2.0); _write_org(alliance)
    return {"ok": true, "message": "Sanction applied to %s." % target_member_id}

func promote_to_director(alliance_id: String, member_id: String, actor_id: String) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or not alliance["members"].has(member_id) or not alliance["members"].has(actor_id): return {"ok": false, "message": "Member not found."}
    if not _can_chair(alliance, actor_id): return {"ok": false, "message": "Only the Chairman can appoint Directors."}
    alliance["members"][member_id]["role"] = ROLE_DIRECTOR; _write_org(alliance)
    return {"ok": true, "message": "%s is now a Director." % member_id}

func add_project(alliance_id: String, project_name: String, project_type: String, cost: int = 0) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or project_name.is_empty() or cost < 0: return {"ok": false, "message": "Invalid project."}
    if cost > int(alliance["treasury"]): return {"ok": false, "message": "Insufficient alliance treasury."}
    alliance["treasury"] = int(alliance["treasury"]) - cost
    alliance["projects"].append({"name": project_name, "type": project_type, "cost": cost, "status": "active", "progress": 0.0, "started_day": _day()})
    _write_org(alliance)
    return {"ok": true, "message": "Alliance project %s started." % project_name}

func get_alliance(alliance_id: String) -> Dictionary: return alliances.get(alliance_id, {}).duplicate(true)
func get_member_alliance(member_id: String) -> Dictionary:
    return get_alliance(str(member_alliance.get(member_id, "")))
func list_alliances() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for alliance in alliances.values(): result.append(alliance.duplicate(true))
    return result

func capture_state() -> Dictionary:
    return {"system_version": 1, "next_alliance_id": next_alliance_id, "alliances": alliances.duplicate(true), "member_alliance": member_alliance.duplicate(true), "events": events.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty(): return
    next_alliance_id = int(snapshot.get("next_alliance_id", 1)); alliances = snapshot.get("alliances", {}).duplicate(true); member_alliance = snapshot.get("member_alliance", {}).duplicate(true); events = snapshot.get("events", []).duplicate(true)

func _add_research_asset(alliance_id: String, kind: String, name: String, cost: int) -> Dictionary:
    var alliance: Variant = alliances.get(alliance_id, {})
    if alliance.is_empty() or name.is_empty() or cost < 0: return {"ok": false, "message": "Invalid %s." % kind}
    if cost > int(alliance["treasury"]): return {"ok": false, "message": "Insufficient alliance treasury."}
    alliance["treasury"] = int(alliance["treasury"]) - cost
    alliance[kind].append({"name": name, "cost": cost, "level": 1, "day": _day()}); _write_org(alliance)
    return {"ok": true, "message": "Alliance %s added: %s." % [kind, name]}

func _mirror_treaty(other: Dictionary, alliance_id: String, treaty: Dictionary) -> void:
    var copy: Variant = treaty.duplicate(true); copy["with"] = alliance_id; copy["status"] = "active"; other["treaties"].append(copy); _write_org(other)

func _member_org(member_id: String) -> Dictionary: return alliances.get(str(member_alliance.get(member_id, "")), {}).duplicate(true)
func _can_chair(alliance: Dictionary, member_id: String) -> bool: return str(alliance.get("members", {}).get(member_id, {}).get("role", "")) == ROLE_CHAIRMAN
func _can_govern(alliance: Dictionary, member_id: String) -> bool: return _can_chair(alliance, member_id) or str(alliance.get("members", {}).get(member_id, {}).get("role", "")) == ROLE_DIRECTOR
func _write_org(alliance: Dictionary) -> void: alliances[alliance["id"]] = alliance
func _day() -> int:
    var game: Variant = get_tree().current_scene
    return int(game.day) if game != null and "day" in game else 1
func _event(kind: String, description: String, data: Dictionary) -> void:
    events.append({"type": kind, "description": description, "data": data.duplicate(true), "day": _day()})
    if events.size() > 1000: events.pop_front()
