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

func create_alliance(name: String, founder_id: String = PLAYER_ID) -> Dictionary:
    name = name.strip_edges()
    if name.is_empty(): return {"ok": false, "message": "Alliance name is required."}
    var alliances: Variant = _alliances()
    if not _member_alliance(founder_id, alliances).is_empty(): return {"ok": false, "message": "%s is already in an alliance." % founder_id}
    var id: Variant = _next_id(alliances)
    alliances[id] = {"id": id, "name": name, "status": "active", "founder_id": founder_id, "members": {founder_id: {"role": "founder", "joined_day": _day()}}, "invites": [], "chat": [], "treasury": 0, "resources": {}, "projects": [], "created_day": _day()}
    _save(alliances); _message("Alliance '%s' created." % name)
    return {"ok": true, "alliance": alliances[id].duplicate(true), "message": "Alliance '%s' created." % name}
func invite_member(alliance_id: String, inviter_id: String, member_id: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if not alliance["members"].has(inviter_id): return {"ok": false, "message": "Only alliance members can invite."}
    if alliance["members"].size() >= MAX_MEMBERS: return {"ok": false, "message": "V1 alliance member limit reached."}
    if member_id.is_empty() or alliance["members"].has(member_id) or _member_alliance(member_id, alliances) != "": return {"ok": false, "message": "Member cannot be invited."}
    if not alliance["invites"].has(member_id): alliance["invites"].append(member_id)
    alliances[alliance_id] = alliance; _save(alliances); _message("Invitation sent to %s." % member_id)
    return {"ok": true, "message": "Invitation sent to %s." % member_id}
func join_alliance(alliance_id: String, member_id: String = PLAYER_ID) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != "active": return {"ok": false, "message": "Alliance not found."}
    if alliance["members"].has(member_id): return {"ok": false, "message": "Already a member."}
    if not alliance["invites"].has(member_id): return {"ok": false, "message": "No invitation found for %s." % member_id}
    alliance["invites"].erase(member_id); alliance["members"][member_id] = {"role": "member", "joined_day": _day()}
    alliances[alliance_id] = alliance; _save(alliances); _message("%s joined '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s joined the alliance." % member_id}
func leave_alliance(member_id: String = PLAYER_ID) -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    if str(alliance.get("founder_id", "")) == member_id: return {"ok": false, "message": "Founder must transfer leadership before leaving in V1."}
    alliance["members"].erase(member_id); alliances[id] = alliance; _save(alliances); _message("%s left '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s left the alliance." % member_id}
func post_message(alliance_id: String, member_id: String, text: String) -> Dictionary:
    var alliances: Variant = _alliances(); var alliance: Dictionary = alliances.get(alliance_id, {}); text = text.strip_edges()
    if alliance.is_empty() or not alliance.get("members", {}).has(member_id): return {"ok": false, "message": "Member is not in this alliance."}
    if text.is_empty(): return {"ok": false, "message": "Message cannot be empty."}
    alliance["chat"].append({"member": member_id, "text": text, "day": _day()}); if alliance["chat"].size() > 50: alliance["chat"] = alliance["chat"].slice(alliance["chat"].size() - 50, alliance["chat"].size())
    alliances[alliance_id] = alliance; _save(alliances); return {"ok": true, "message": "Alliance message posted."}
func donate_money(member_id: String, amount: int) -> Dictionary:
    if amount <= 0: return {"ok": false, "message": "Donation amount must be positive."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var spend := state_adapter.spend(amount, "alliance donation")
    if not bool(spend.get("ok", false)): return {"ok": false, "message": "Insufficient cash for donation."}
    var alliance: Dictionary = alliances[id]; alliance["treasury"] = int(alliance.get("treasury", 0)) + amount
    alliance["contributions"] = alliance.get("contributions", []); alliance["contributions"].append({"member": member_id, "type": "money", "amount": amount, "day": _day()})
    alliances[id] = alliance; _save(alliances); _message("Donated $%d to '%s'." % [amount, alliance["name"]]); return {"ok": true, "message": "Alliance received $%d." % amount}
func donate_resource(member_id: String, resource_id: String, amount: int) -> Dictionary:
    if resource_id.is_empty() or amount <= 0: return {"ok": false, "message": "Invalid resource donation."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var resources: Variant = _resources(); if int(resources.get(resource_id, 0)) < amount: return {"ok": false, "message": "Not enough %s to donate." % resource_id}
    var alliance: Dictionary = alliances[id]; resources[resource_id] = int(resources.get(resource_id, 0)) - amount; alliance["resources"][resource_id] = int(alliance["resources"].get(resource_id, 0)) + amount
    alliance["contributions"] = alliance.get("contributions", []); alliance["contributions"].append({"member": member_id, "type": "resource", "resource": resource_id, "amount": amount, "day": _day()})
    _set_resources(resources); alliances[id] = alliance; _save(alliances); _message("Donated %d %s to '%s'." % [amount, resource_id, alliance["name"]]); return {"ok": true, "message": "Alliance received %d %s." % [amount, resource_id]}

func start_cooperative_project(member_id: String, project_name: String = "Regional Railway Project") -> Dictionary:
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    for existing in alliance.get("projects", []):
        if str(existing.get("id", "")) == RAILWAY_PROJECT_ID and str(existing.get("status", "active")) == "active": return {"ok": false, "message": "Regional Railway Project is already active."}
    alliance["projects"].append({"id": RAILWAY_PROJECT_ID, "name": "Regional Railway Project", "description": "Connect Renew Region and improve regional resource movement.", "status": "active", "started_day": _day(), "requirements": RAILWAY_REQUIREMENTS.duplicate(true), "contributed": {"money": 0, "steel": 0, "timber": 0, "project_points": 0}, "contributors": [], "effects": RAILWAY_EFFECTS.duplicate(true)})
    alliances[id] = alliance; _save(alliances); _message("Regional Railway Project started. Members must contribute $1M, 500 steel, 100 timber and 100 project points.")
    return {"ok": true, "project": alliance["projects"].back().duplicate(true), "message": "Regional Railway Project started."}

func contribute_to_railway(member_id: String, money: int = 0, steel: int = 0, timber: int = 0, project_points: int = 0) -> Dictionary:
    if money < 0 or steel < 0 or timber < 0 or project_points < 0 or (money + steel + timber + project_points) <= 0: return {"ok": false, "message": "Contribution must contain at least one positive amount."}
    var alliances: Variant = _alliances(); var id := _member_alliance(member_id, alliances)
    if id.is_empty(): return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]; var index := -1
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
    var spend := state_adapter.spend(money, "regional railway contribution") if money > 0 else {"ok": true, "amount": 0}
    if not bool(spend.get("ok", false)): return {"ok": false, "message": "Not enough cash for this railway contribution."}
    resources["steel"] = int(resources.get("steel", 0)) - steel; resources["timber"] = int(resources.get("timber", 0)) - timber; _set_resources(resources)
    current["money"] = int(current["money"]) + money; current["steel"] = int(current["steel"]) + steel; current["timber"] = int(current["timber"]) + timber; current["project_points"] = int(current["project_points"]) + project_points; project["contributed"] = current
    if not project["contributors"].has(member_id): project["contributors"].append(member_id)
    if _railway_complete(project):
        _complete_railway(project); _message("Regional Railway Project completed! Transport costs -10%, resource delivery +10%, regional reputation +5.")
    else: _message("%s contributed to the Regional Railway Project." % member_id)
    alliance["projects"][index] = project; alliances[id] = alliance; _save(alliances)
    return {"ok": true, "project": project.duplicate(true), "message": "Railway contribution recorded."}

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
