extends Node

## RENEW Alliance V1.
## Basic player alliances only: membership, invitations, chat, contributions,
## cooperative projects and rewards. Persistent facts live in GameState.alliances.

const DomainSystem = preload("res://scripts/domain_system.gd")
const PLAYER_ID := "player"
const MAX_MEMBERS := 6
const RAILWAY_PROJECT_ID := "regional_railway"
const RAILWAY_REQUIREMENTS := {"money": 1000000, "steel": 500, "timber": 100, "project_points": 100}
const RAILWAY_EFFECTS := {"transport_cost_multiplier": 0.90, "resource_delivery_multiplier": 1.10, "regional_reputation": 5}
var state_adapter: Variant = DomainSystem.new()

func _ready() -> void:
    add_child(state_adapter)

func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")
func _alliances() -> Dictionary:
    var state: Variant = _state()
    return state.get_value("alliances", "alliances", {}) if state != null else {}
func _save(alliances: Dictionary) -> void:
    var state: Variant = _state()
    if state != null: state.set_value("alliances", "alliances", alliances)
func _cash() -> int:
    var state: Variant = _state()
    return int(state.get_value("economy", "cash", 0)) if state != null else 0
func _set_cash(value: int) -> void:
    var state: Variant = _state()
    if state != null: state.set_value("economy", "cash", value)
func _resources() -> Dictionary:
    var state: Variant = _state()
    return state.get_value("resources", "resources", {}) if state != null else {}
func _set_resources(value: Dictionary) -> void:
    var state: Variant = _state()
    if state != null: state.set_value("resources", "resources", value)
func _day() -> int:
    var state: Variant = _state()
    return int(state.get_value("player", "day", 1)) if state != null else 1
func _message(text: String) -> void:
    var state: Variant = _state()
    if state == null: return
    state.set_value("company", "message", text)
    var logs: Array = state.get_value("company", "log_lines", [])
    logs.append(text)
    if logs.size() > 20: logs = logs.slice(logs.size() - 20, logs.size())
    state.set_value("company", "log_lines", logs)
func _next_id(alliances: Dictionary) -> String:
    var n: Variant = 1
    while alliances.has("alliance_%d" % n): n += 1
    return "alliance_%d" % n
func _member_alliance(member_id: String, alliances: Dictionary) -> String:
    for id in alliances.keys():
        var alliance: Dictionary = alliances[id]
        if str(alliance.get("status", "active")) == "active" and alliance.get("members", {}).has(member_id): return str(id)
    return ""

func _normalize_alliance(alliance: Dictionary) -> Dictionary:
    if alliance.is_empty():
        return alliance
    if not alliance.has("trust"):
        alliance["trust"] = 50.0
    if not alliance.has("reputation"):
        alliance["reputation"] = 0.0
    if not alliance.has("level"):
        alliance["level"] = 1
    if not alliance.has("total_money_contributed"):
        alliance["total_money_contributed"] = 0
    if not alliance.has("member_trust") or not alliance["member_trust"] is Dictionary:
        alliance["member_trust"] = {}
    if not alliance.has("infrastructure") or not alliance["infrastructure"] is Array:
        alliance["infrastructure"] = []
    if not alliance.has("research") or not alliance["research"] is Array:
        alliance["research"] = []
    if not alliance.has("motions") or not alliance["motions"] is Array:
        alliance["motions"] = []
    var members: Dictionary = alliance.get("members", {})
    for member_id in members.keys():
        if not members[member_id] is Dictionary:
            members[member_id] = {"role": "member", "joined_day": _day()}
        if not str(members[member_id].get("role", "")) in ["founder", "director", "member"]:
            members[member_id]["role"] = "founder" if str(member_id) == str(alliance.get("founder_id", "")) else "member"
        if not alliance["member_trust"].has(member_id):
            alliance["member_trust"][member_id] = 75 if str(member_id) == str(alliance.get("founder_id", "")) else 50
    alliance["members"] = members
    return alliance

func _role(alliance: Dictionary, member_id: String) -> String:
    return str(alliance.get("members", {}).get(member_id, {}).get("role", ""))

func _can_govern(alliance: Dictionary, member_id: String) -> bool:
    return _role(alliance, member_id) in ["founder", "director"]

func _add_trust(alliance: Dictionary, member_id: String, amount: int) -> void:
    var trust: Dictionary = alliance.get("member_trust", {})
    trust[member_id] = clampi(int(trust.get(member_id, 50)) + amount, 0, 100)
    alliance["member_trust"] = trust
    alliance["trust"] = clampf(float(alliance.get("trust", 50.0)) + float(amount) * 0.2, 0.0, 100.0)

func _refresh_level(alliance: Dictionary) -> bool:
    var completed := 0
    for project in alliance.get("projects", []):
        if project is Dictionary and str(project.get("status", "")) == "complete":
            completed += 1
    var level := 1 + completed + int(int(alliance.get("total_money_contributed", 0)) / 50000)
    if level > int(alliance.get("level", 1)):
        alliance["level"] = level
        alliance["reputation"] = float(alliance.get("reputation", 0.0)) + 2.0
        var state := _state()
        if state != null:
            state.set_value("regions", "regional_reputation", int(state.get_value("regions", "regional_reputation", 0)) + 2)
        _message("Alliance '%s' reached level %d. Regional reputation grows." % [alliance.get("name", "alliance"), level])
        return true
    alliance["level"] = level
    return false

func create_alliance(name: String, founder_id: String = PLAYER_ID) -> Dictionary:
    name = name.strip_edges()
    if name.is_empty(): return {"ok": false, "message": "Alliance name is required."}
    var alliances: Variant = _alliances()
    if not _member_alliance(founder_id, alliances).is_empty(): return {"ok": false, "message": "%s is already in an alliance." % founder_id}
    var id: Variant = _next_id(alliances)
    alliances[id] = {"id": id, "name": name, "status": "active", "founder_id": founder_id, "members": {founder_id: {"role": "founder", "joined_day": _day()}}, "member_trust": {founder_id: 75}, "trust": 55.0, "reputation": 0.0, "level": 1, "total_money_contributed": 0, "invites": [], "chat": [], "treasury": 0, "resources": {}, "projects": [], "infrastructure": [], "research": [], "created_day": _day()}
    _save(alliances); _message("Alliance '%s' created." % name)
    return {"ok": true, "alliance": alliances[id].duplicate(true), "message": "Alliance '%s' created." % name}
func create_alliance_with_finance(finance: Node, founder_id: String, name: String, amount: int) -> Dictionary:
    if finance == null or not finance.has_method("spend"):
        return {"ok": false, "message": "Alliance funding transaction is unavailable."}
    if amount <= 0:
        return {"ok": false, "message": "Founding contribution must be positive."}
    var payment: Dictionary = finance.spend(amount, "alliance founding")
    if not bool(payment.get("ok", false)):
        return {"ok": false, "message": str(payment.get("message", "Alliance funding could not be posted."))}
    var created: Dictionary = create_alliance(name, founder_id)
    if not bool(created.get("ok", false)):
        finance.receive(amount, "refund after failed alliance founding")
        return created
    var alliances: Variant = _alliances()
    var id := str(created["alliance"]["id"])
    var alliance: Dictionary = _normalize_alliance(alliances.get(id, {}))
    alliance["treasury"] = int(alliance.get("treasury", 0)) + amount
    alliance["total_money_contributed"] = int(alliance.get("total_money_contributed", 0)) + amount
    alliance["contributions"] = alliance.get("contributions", [])
    alliance["contributions"].append({"member": founder_id, "type": "founding", "amount": amount, "day": _day()})
    _add_trust(alliance, founder_id, 5)
    _refresh_level(alliance)
    alliances[id] = alliance
    _save(alliances)
    _message("Alliance '%s' founded with $%d in treasury." % [name, amount])
    return {"ok": true, "alliance": alliance.duplicate(true), "message": "Alliance '%s' founded with $%d in treasury." % [name, amount]}
func invite_member(alliance_id: String, inviter_id: String, member_id: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if not alliance["members"].has(inviter_id): return {"ok": false, "message": "Only alliance members can invite."}
    if not _can_govern(alliance, inviter_id): return {"ok": false, "message": "Only the founder or directors can invite new members."}
    if alliance["members"].size() >= MAX_MEMBERS: return {"ok": false, "message": "V1 alliance member limit reached."}
    if member_id.is_empty() or alliance["members"].has(member_id) or _member_alliance(member_id, alliances) != "": return {"ok": false, "message": "Member cannot be invited."}
    if not alliance["invites"].has(member_id): alliance["invites"].append(member_id)
    alliances[alliance_id] = alliance; _save(alliances); _message("Invitation sent to %s." % member_id)
    return {"ok": true, "message": "Invitation sent to %s." % member_id}
func promote_to_director(alliance_id: String, actor_id: String, member_id: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if str(alliance.get("founder_id", "")) != actor_id: return {"ok": false, "message": "Only the founder can appoint directors."}
    if not alliance["members"].has(member_id): return {"ok": false, "message": "Member is not in this alliance."}
    alliance["members"][member_id]["role"] = "director"
    _add_trust(alliance, member_id, 5)
    alliances[alliance_id] = alliance; _save(alliances); _message("%s promoted %s to director." % [actor_id, member_id])
    return {"ok": true, "message": "%s is now a director." % member_id}
func demote_to_member(alliance_id: String, actor_id: String, member_id: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if str(alliance.get("founder_id", "")) != actor_id: return {"ok": false, "message": "Only the founder can demote directors."}
    if not alliance["members"].has(member_id) or str(alliance["members"][member_id].get("role", "")) != "director": return {"ok": false, "message": "Member is not a director."}
    alliance["members"][member_id]["role"] = "member"
    alliances[alliance_id] = alliance; _save(alliances); _message("%s demoted to member." % member_id)
    return {"ok": true, "message": "%s is now a member." % member_id}
func sanction_member(alliance_id: String, actor_id: String, member_id: String, reason: String = "broke alliance trust") -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if not _can_govern(alliance, actor_id): return {"ok": false, "message": "Only the founder or directors can sanction members."}
    if not alliance["members"].has(member_id): return {"ok": false, "message": "Member is not in this alliance."}
    if str(alliance.get("founder_id", "")) == member_id: return {"ok": false, "message": "The founder cannot be sanctioned."}
    _add_trust(alliance, member_id, -15)
    alliances[alliance_id] = alliance; _save(alliances); _message("%s sanctioned %s: %s." % [actor_id, member_id, reason])
    return {"ok": true, "message": "%s was sanctioned and lost trust." % member_id, "trust": int(alliance["member_trust"].get(member_id, 0))}
func join_alliance(alliance_id: String, member_id: String = PLAYER_ID) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if alliance["members"].has(member_id): return {"ok": false, "message": "Already a member."}
    if not alliance["invites"].has(member_id): return {"ok": false, "message": "No invitation found for %s." % member_id}
    alliance["invites"].erase(member_id); alliance["members"][member_id] = {"role": "member", "joined_day": _day()}
    alliance = _normalize_alliance(alliance)
    alliances[alliance_id] = alliance; _save(alliances); _message("%s joined '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s joined the alliance." % member_id}
func leave_alliance(member_id: String = PLAYER_ID) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    if str(alliance.get("founder_id", "")) == member_id: return {"ok": false, "message": "Founder must transfer leadership before leaving in V1."}
    alliance["members"].erase(member_id)
    if alliance.has("member_trust") and alliance["member_trust"] is Dictionary:
        alliance["member_trust"].erase(member_id)
    alliances[id] = alliance; _save(alliances); _message("%s left '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s left the alliance." % member_id}
func post_message(alliance_id: String, member_id: String, text: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = alliances.get(alliance_id, {}); text = text.strip_edges()
    if alliance.is_empty() or not alliance.get("members", {}).has(member_id): return {"ok": false, "message": "Member is not in this alliance."}
    if text.is_empty(): return {"ok": false, "message": "Message cannot be empty."}
    alliance["chat"].append({"member": member_id, "text": text, "day": _day()}); if alliance["chat"].size() > 50: alliance["chat"] = alliance["chat"].slice(alliance["chat"].size() - 50, alliance["chat"].size())
    alliances[alliance_id] = alliance; _save(alliances); return {"ok": true, "message": "Alliance message posted."}
func _credit_donation(alliance: Dictionary, member_id: String, amount: int) -> void:
    alliance["treasury"] = int(alliance.get("treasury", 0)) + amount
    alliance["total_money_contributed"] = int(alliance.get("total_money_contributed", 0)) + amount
    alliance["contributions"] = alliance.get("contributions", [])
    alliance["contributions"].append({"member": member_id, "type": "money", "amount": amount, "day": _day()})
    _add_trust(alliance, member_id, 5)
    _refresh_level(alliance)
func donate_money(member_id: String, amount: int) -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Donation amount must be positive."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var spend: Dictionary = state_adapter.spend(amount, "alliance donation")
    if not bool(spend.get("ok", false)): return {"ok": false, "message": "Insufficient cash for donation."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    _credit_donation(alliance, member_id, amount)
    alliances[id] = alliance; _save(alliances); _message("Donated $%d to '%s'." % [amount, alliance["name"]]); return {"ok": true, "message": "Alliance received $%d." % amount}
func contribute_from_finance(finance: Node, member_id: String, amount: int) -> Dictionary:
    if finance == null or not finance.has_method("spend"):
        return {"ok": false, "message": "Alliance contribution transaction is unavailable."}
    if amount <= 0:
        return {"ok": false, "message": "Contribution amount must be positive."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var payment: Dictionary = finance.spend(amount, "alliance contribution")
    if not bool(payment.get("ok", false)):
        return {"ok": false, "message": str(payment.get("message", "Contribution could not be completed."))}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    _credit_donation(alliance, member_id, amount)
    alliances[id] = alliance; _save(alliances); _message("Contributed $%d to '%s'." % [amount, alliance["name"]])
    return {"ok": true, "message": "Alliance received $%d." % amount, "treasury": int(alliance.get("treasury", 0))}
func donate_resource(member_id: String, resource_id: String, amount: int) -> Dictionary:
    if resource_id.is_empty() or amount <= 0: return {"ok": false, "message": "Invalid resource donation."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var resources: Variant = _resources(); if int(resources.get(resource_id, 0)) < amount: return {"ok": false, "message": "Not enough %s to donate." % resource_id}
    var alliance: Dictionary = _normalize_alliance(alliances[id]); resources[resource_id] = int(resources.get(resource_id, 0)) - amount; alliance["resources"][resource_id] = int(alliance["resources"].get(resource_id, 0)) + amount
    alliance["contributions"] = alliance.get("contributions", []); alliance["contributions"].append({"member": member_id, "type": "resource", "resource": resource_id, "amount": amount, "day": _day()})
    _add_trust(alliance, member_id, 3)
    _refresh_level(alliance)
    _set_resources(resources); alliances[id] = alliance; _save(alliances); _message("Donated %d %s to '%s'." % [amount, resource_id, alliance["name"]]); return {"ok": true, "message": "Alliance received %d %s." % [amount, resource_id]}

func start_cooperative_project(member_id: String, project_name: String = "Regional Railway Project") -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    if not _can_govern(alliance, member_id) and int(alliance.get("member_trust", {}).get(member_id, 50)) < 25:
        return {"ok": false, "message": "Members below 25 trust cannot start cooperative projects."}
    for existing in alliance.get("projects", []):
        if str(existing.get("id", "")) == RAILWAY_PROJECT_ID and str(existing.get("status", "active")) == "active": return {"ok": false, "message": "Regional Railway Project is already active."}
    alliance["projects"].append({"id": RAILWAY_PROJECT_ID, "name": "Regional Railway Project", "description": "Connect Renew Region and improve regional resource movement.", "status": "active", "started_day": _day(), "requirements": RAILWAY_REQUIREMENTS.duplicate(true), "contributed": {"money": 0, "steel": 0, "timber": 0, "project_points": 0}, "contributors": [], "effects": RAILWAY_EFFECTS.duplicate(true)})
    alliances[id] = alliance; _save(alliances); _message("Regional Railway Project started. Members must contribute $1M, 500 steel, 100 timber and 100 project points.")
    return {"ok": true, "project": alliance["projects"].back().duplicate(true), "message": "Regional Railway Project started."}

func contribute_to_railway(member_id: String, money: int = 0, steel: int = 0, timber: int = 0, project_points: int = 0) -> Dictionary:
    if money < 0 or steel < 0 or timber < 0 or project_points < 0 or (money + steel + timber + project_points) <= 0: return {"ok": false, "message": "Contribution must contain at least one positive amount."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id]); var index := -1
    for i in range(alliance.get("projects", []).size()):
        if str(alliance["projects"][i].get("id", "")) == RAILWAY_PROJECT_ID: index = i; break
    if index < 0: return {"ok": false, "message": "Regional Railway Project has not been started."}
    var project: Dictionary = alliance["projects"][index]
    if str(project.get("status", "")) != "active": return {"ok": false, "message": "Regional Railway Project is already complete."}
    var req: Dictionary = project["requirements"]; var current: Dictionary = project["contributed"]
    money = min(money, max(0, int(req["money"]) - int(current["money"]))); steel = min(steel, max(0, int(req["steel"]) - int(current["steel"]))); timber = min(timber, max(0, int(req["timber"]) - int(current["timber"]))); project_points = min(project_points, max(0, int(req["project_points"]) - int(current["project_points"])))
    var resources: Variant = _resources()
    if steel > int(resources.get("steel", 0)) or timber > int(resources.get("timber", 0)):
        return {"ok": false, "message": "Not enough steel or timber for this railway contribution."}
    var spend: Dictionary = state_adapter.spend(money, "regional railway contribution") if money > 0 else {"ok": true, "amount": 0}
    if not bool(spend.get("ok", false)): return {"ok": false, "message": "Not enough cash for this railway contribution."}
    resources["steel"] = int(resources.get("steel", 0)) - steel; resources["timber"] = int(resources.get("timber", 0)) - timber; _set_resources(resources)
    current["money"] = int(current["money"]) + money; current["steel"] = int(current["steel"]) + steel; current["timber"] = int(current["timber"]) + timber; current["project_points"] = int(current["project_points"]) + project_points; project["contributed"] = current
    if not project["contributors"].has(member_id): project["contributors"].append(member_id)
    _add_trust(alliance, member_id, 2)
    _refresh_level(alliance)
    if _railway_complete(project):
        _complete_railway(project); _message("Regional Railway Project completed! Transport costs -10%, resource delivery +10%, regional reputation +5.")
    else: _message("%s contributed to the Regional Railway Project." % member_id)
    alliance["projects"][index] = project; alliances[id] = alliance; _save(alliances)
    return {"ok": true, "project": project.duplicate(true), "message": "Railway contribution recorded."}

func allocate_treasury_to_railway(member_id: String, amount: int) -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Allocation amount must be positive."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    if not _can_govern(alliance, member_id): return {"ok": false, "message": "Only the founder or directors can allocate treasury funds."}
    if int(alliance.get("treasury", 0)) < amount: return {"ok": false, "message": "Treasury holds $%d." % int(alliance.get("treasury", 0))}
    var index := -1
    for i in range(alliance.get("projects", []).size()):
        if str(alliance["projects"][i].get("id", "")) == RAILWAY_PROJECT_ID: index = i; break
    if index < 0: return {"ok": false, "message": "Regional Railway Project has not been started."}
    var project: Dictionary = alliance["projects"][index]
    if str(project.get("status", "")) != "active": return {"ok": false, "message": "Regional Railway Project is already complete."}
    var room := max(0, int(project["requirements"].get("money", 0)) - int(project["contributed"].get("money", 0)))
    var moved: int = min(amount, room)
    if moved <= 0: return {"ok": false, "message": "Railway money requirement is already met."}
    alliance["treasury"] = int(alliance.get("treasury", 0)) - moved
    project["contributed"]["money"] = int(project["contributed"].get("money", 0)) + moved
    if not project["contributors"].has(member_id): project["contributors"].append(member_id)
    alliance["projects"][index] = project
    if _railway_complete(project):
        _complete_railway(project); _message("Regional Railway Project completed with treasury funding!")
    else:
        _message("%s allocated $%d treasury funds to the Regional Railway Project." % [member_id, moved])
    alliances[id] = alliance; _save(alliances)
    return {"ok": true, "project": project.duplicate(true), "allocated": moved, "treasury": int(alliance.get("treasury", 0)), "message": "Treasury funds allocated to the railway."}
func add_infrastructure(alliance_id: String, name: String, level: int = 1, cost: int = 0) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if name.strip_edges().is_empty(): return {"ok": false, "message": "Infrastructure needs a name."}
    if cost < 0 or int(alliance.get("treasury", 0)) < cost: return {"ok": false, "message": "Treasury holds $%d." % int(alliance.get("treasury", 0))}
    alliance["treasury"] = int(alliance.get("treasury", 0)) - cost
    alliance["infrastructure"].append({"name": name, "level": max(1, level), "cost": cost, "day": _day()})
    alliance["trust"] = clampf(float(alliance.get("trust", 50.0)) + 2.0, 0.0, 100.0)
    alliances[alliance_id] = alliance; _save(alliances); _message("Alliance built %s." % name)
    return {"ok": true, "message": "Alliance acquired %s." % name, "treasury": int(alliance.get("treasury", 0))}
func fund_research(alliance_id: String, project: String, cost: int = 0) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = _normalize_alliance(alliances.get(alliance_id, {}))
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if project.strip_edges().is_empty(): return {"ok": false, "message": "Research needs a project name."}
    if cost < 0 or int(alliance.get("treasury", 0)) < cost: return {"ok": false, "message": "Treasury holds $%d." % int(alliance.get("treasury", 0))}
    alliance["treasury"] = int(alliance.get("treasury", 0)) - cost
    alliance["research"].append({"project": project, "cost": cost, "day": _day()})
    alliance["trust"] = clampf(float(alliance.get("trust", 50.0)) + 2.0, 0.0, 100.0)
    alliances[alliance_id] = alliance; _save(alliances); _message("Alliance funded %s." % project)
    return {"ok": true, "message": "Alliance funded %s." % project, "treasury": int(alliance.get("treasury", 0))}

func complete_project(member_id: String, project_index: int = -1) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]; var index := project_index if project_index >= 0 else _find_active_project(alliance)
    if index < 0 or index >= alliance["projects"].size(): return {"ok": false, "message": "Project not found."}
    var project: Dictionary = alliance["projects"][index]
    if project.get("id") != RAILWAY_PROJECT_ID: return {"ok": false, "message": "Unknown cooperative project."}
    if not _railway_complete(project): return {"ok": false, "message": "Regional Railway Project still needs contributions."}
    if project.get("status") != "complete": _complete_railway(project); alliance["projects"][index] = project; alliances[id] = alliance; _save(alliances)
    return {"ok": true, "reward": RAILWAY_EFFECTS.duplicate(true), "message": "Regional Railway Project completed."}
func _railway_complete(project: Dictionary) -> bool:
    var req: Dictionary = project.get("requirements", RAILWAY_REQUIREMENTS); var c: Dictionary = project.get("contributed", {})
    return int(c.get("money", 0)) >= int(req.get("money", 1000000)) and int(c.get("steel", 0)) >= int(req.get("steel", 500)) and int(c.get("timber", 0)) >= int(req.get("timber", 100)) and int(c.get("project_points", 0)) >= int(req.get("project_points", 100))
func _complete_railway(project: Dictionary) -> void:
    project["status"] = "complete"; project["completed_day"] = _day(); project["reward_received"] = true
    var state: Variant = _state(); if state == null: return
    var supply: Dictionary = state.get_domain("supply_chain"); supply["transport_cost_multiplier"] = min(float(supply.get("transport_cost_multiplier", 1.0)), 0.90); supply["resource_delivery_multiplier"] = max(float(supply.get("resource_delivery_multiplier", 1.0)), 1.10); state.set_domain("supply_chain", supply)
    var regions: Dictionary = state.get_domain("regions"); regions["regional_reputation"] = int(regions.get("regional_reputation", 0)) + 5; state.set_domain("regions", regions)
func _find_active_project(alliance: Dictionary) -> int:
    for i in range(alliance.get("projects", []).size()):
        if alliance["projects"][i].get("status") == "active": return i
    return -1
func get_alliance(alliance_id: String) -> Dictionary: return _alliances().get(alliance_id, {}).duplicate(true)
func get_member_alliance(member_id: String = PLAYER_ID) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances); return alliances.get(id, {}).duplicate(true)
func list_alliances() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for alliance in _alliances().values(): result.append(alliance.duplicate(true))
    return result
func challenge_score(alliance: Dictionary) -> int:
    var railway_bonus := 0
    for project in alliance.get("projects", []):
        if project is Dictionary and str(project.get("status", "")) == "complete":
            railway_bonus += 50
    return int(alliance.get("members", {}).size()) * 10 + int(int(alliance.get("treasury", 0)) / 1000) + int(alliance.get("level", 1)) * 15 + int(float(alliance.get("trust", 50.0)) / 2.0) + railway_bonus
func run_alliance_challenge(member_id: String) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    var day := _day()
    if day - int(alliance.get("last_challenge_day", -1000000)) < 30:
        return {"ok": false, "message": "The next industrial challenge opens in %d days." % (30 - (day - int(alliance.get("last_challenge_day", -1000000))))}
    var ours := challenge_score(alliance)
    var standings: Array = [
        {"name": str(alliance.get("name", "alliance")), "score": ours, "ours": true},
        {"name": "Iron Compact", "score": 45 + (day % 20), "ours": false},
        {"name": "Harbor League", "score": 50 + ((day * 7) % 25), "ours": false}
    ]
    standings.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
    alliance["last_challenge_day"] = day
    var rank := 0
    for i in range(standings.size()):
        if bool(standings[i].get("ours", false)):
            rank = i + 1
    var result := {"ok": true, "rank": rank, "score": ours, "standings": standings}
    if rank == 1:
        alliance["treasury"] = int(alliance.get("treasury", 0)) + 3000
        alliance["reputation"] = float(alliance.get("reputation", 0.0)) + 5.0
        alliance["trust"] = clampf(float(alliance.get("trust", 50.0)) + 3.0, 0.0, 100.0)
        alliance["challenge_wins"] = int(alliance.get("challenge_wins", 0)) + 1
        result["prize"] = 3000
        result["message"] = "'%s' wins the industrial challenge! +$3,000 treasury, +5 reputation." % alliance.get("name", "alliance")
    else:
        result["prize"] = 0
        result["message"] = "'%s' places #%d with %d points. Strengthen treasury and trust." % [alliance.get("name", "alliance"), rank, ours]
    alliances[id] = alliance
    _save(alliances)
    _message(str(result["message"]))
    return result
func _motion_weight(alliance: Dictionary, member_id: String) -> int:
    match _role(alliance, member_id):
        "founder": return 3
        "director": return 2
    return 1
func open_motion(proposer_id: String, kind: String, target_id: String) -> Dictionary:
    if kind != "sanction" and kind != "admit":
        return {"ok": false, "message": "Motions cover sanction or admit."}
    if target_id.is_empty():
        return {"ok": false, "message": "Motions need a named member."}
    var alliances: Variant = _alliances(); var id := _member_alliance(proposer_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    if not _can_govern(alliance, proposer_id): return {"ok": false, "message": "Only the founder or directors can open motions."}
    if kind == "sanction" and (not alliance["members"].has(target_id) or str(alliance.get("founder_id", "")) == target_id):
        return {"ok": false, "message": "Sanctions target a non-founder member."}
    if kind == "admit" and alliance["members"].has(target_id):
        return {"ok": false, "message": "They are already a member."}
    for motion in alliance.get("motions", []):
        if motion is Dictionary and str(motion.get("status", "")) == "open":
            return {"ok": false, "message": "One motion at a time; vote on the open one first."}
    var votes := {}
    for member_id in alliance.get("members", {}).keys():
        if str(member_id) == proposer_id:
            continue
        if int(alliance.get("member_trust", {}).get(member_id, 50)) >= 50:
            votes[member_id] = true
        else:
            votes[member_id] = false
    alliance["motions"].append({"kind": kind, "target": target_id, "proposer": proposer_id, "votes": votes, "status": "open", "day": _day()})
    alliances[id] = alliance
    _save(alliances)
    _message("Motion opened: %s %s." % [kind, target_id])
    return {"ok": true, "message": "Motion opened to %s %s. Cast your vote." % [kind, target_id], "index": alliance["motions"].size() - 1}
func vote_motion(voter_id: String, motion_index: int, yes: bool) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(voter_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    if motion_index < 0 or motion_index >= alliance.get("motions", []).size():
        return {"ok": false, "message": "No such motion."}
    var motion: Dictionary = alliance["motions"][motion_index]
    if str(motion.get("status", "")) != "open":
        return {"ok": false, "message": "That motion already closed."}
    if (motion.get("votes", {}) as Dictionary).has(voter_id):
        return {"ok": false, "message": "You already voted on this motion."}
    (motion.get("votes", {}) as Dictionary)[voter_id] = bool(yes)
    var yes_weight := 0
    var no_weight := 0
    for member_id in (motion.get("votes", {}) as Dictionary).keys():
        if bool((motion.get("votes", {}) as Dictionary)[member_id]):
            yes_weight += _motion_weight(alliance, str(member_id))
        else:
            no_weight += _motion_weight(alliance, str(member_id))
    if yes_weight > no_weight:
        motion["status"] = "passed"
    elif no_weight >= yes_weight:
        motion["status"] = "rejected"
    else:
        motion["status"] = "open"
    alliance["motions"][motion_index] = motion
    alliances[id] = alliance
    _save(alliances)
    if str(motion["status"]) == "open":
        return {"ok": true, "status": "open", "message": "Vote recorded; the motion stays open."}
    return _execute_motion(alliances, id, motion_index)
func _execute_motion(alliances: Dictionary, id: String, motion_index: int) -> Dictionary:
    var alliance: Dictionary = _normalize_alliance(alliances[id])
    var motion: Dictionary = alliance["motions"][motion_index]
    if str(motion.get("status", "")) == "rejected":
        _message("Motion to %s %s failed." % [str(motion.get("kind", "")), str(motion.get("target", ""))])
        return {"ok": true, "status": "rejected", "message": "The motion failed."}
    var kind := str(motion.get("kind", ""))
    var target := str(motion.get("target", ""))
    if kind == "sanction":
        var done: Dictionary = sanction_member(id, str(alliance.get("founder_id", "")), target, "alliance motion")
        return {"ok": true, "status": "passed", "message": str(done.get("message", "Sanction carried out."))}
    if not alliance.has("invites") or not alliance["invites"] is Dictionary:
        alliance["invites"] = {}
    alliance["invites"][target] = {"day": _day(), "by_motion": true}
    alliances[id] = alliance
    _save(alliances)
    var joined: Dictionary = join_alliance(id, target)
    if bool(joined.get("ok", false)):
        return {"ok": true, "status": "passed", "message": "%s admitted by motion." % target}
    return {"ok": true, "status": "passed", "message": str(joined.get("message", "Admission recorded."))}
