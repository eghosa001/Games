extends Node

## RENEW Alliance V1.
## Basic player alliances only: membership, invitations, chat, contributions,
## cooperative projects and rewards. Persistent facts live in GameState.alliances.

const PLAYER_ID := "player"
const MAX_MEMBERS := 6
const PROJECT_COST := 1000
const PROJECT_REWARD := 2500

func _state() -> Node:
    return get_node_or_null("/root/RenewGameState")

func _alliances() -> Dictionary:
    var state := _state()
    if state == null:
        return {}
    return state.get_value("alliances", "alliances", {})

func _save(alliances: Dictionary) -> void:
    var state := _state()
    if state != null:
        state.set_value("alliances", "alliances", alliances)

func _cash() -> int:
    var state := _state()
    return int(state.get_value("economy", "cash", 0)) if state != null else 0

func _set_cash(value: int) -> void:
    var state := _state()
    if state != null:
        state.set_value("economy", "cash", value)

func _resources() -> Dictionary:
    var state := _state()
    if state == null:
        return {}
    return state.get_value("resources", "resources", {})

func _set_resources(value: Dictionary) -> void:
    var state := _state()
    if state != null:
        state.set_value("resources", "resources", value)

func _day() -> int:
    var state := _state()
    return int(state.get_value("player", "day", 1)) if state != null else 1

func _message(text: String) -> void:
    var state := _state()
    if state == null:
        return
    state.set_value("company", "message", text)
    var logs: Array = state.get_value("company", "log_lines", [])
    logs.append(text)
    if logs.size() > 20:
        logs = logs.slice(logs.size() - 20, logs.size())
    state.set_value("company", "log_lines", logs)

func _next_id(alliances: Dictionary) -> String:
    var n := 1
    while alliances.has("alliance_%d" % n):
        n += 1
    return "alliance_%d" % n

func _member_alliance(member_id: String, alliances: Dictionary) -> String:
    for id in alliances.keys():
        var alliance: Dictionary = alliances[id]
        if str(alliance.get("status", "active")) == "active" and alliance.get("members", {}).has(member_id):
            return str(id)
    return ""

func create_alliance(name: String, founder_id: String = PLAYER_ID) -> Dictionary:
    name = name.strip_edges()
    if name.is_empty():
        return {"ok": false, "message": "Alliance name is required."}
    var alliances := _alliances()
    if not _member_alliance(founder_id, alliances).is_empty():
        return {"ok": false, "message": "%s is already in an alliance." % founder_id}
    var id := _next_id(alliances)
    alliances[id] = {
        "id": id,
        "name": name,
        "status": "active",
        "founder_id": founder_id,
        "members": {founder_id: {"role": "founder", "joined_day": _day()}},
        "invites": [],
        "chat": [],
        "treasury": 0,
        "resources": {},
        "projects": [],
        "created_day": _day()
    }
    _save(alliances)
    _message("Alliance '%s' created." % name)
    return {"ok": true, "alliance": alliances[id].duplicate(true), "message": "Alliance '%s' created." % name}

func invite_member(alliance_id: String, inviter_id: String, member_id: String) -> Dictionary:
    var alliances := _alliances()
    var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != "active":
        return {"ok": false, "message": "Alliance not found."}
    if not alliance["members"].has(inviter_id):
        return {"ok": false, "message": "Only alliance members can invite."}
    if alliance["members"].size() >= MAX_MEMBERS:
        return {"ok": false, "message": "V1 alliance member limit reached."}
    if member_id.is_empty() or alliance["members"].has(member_id) or _member_alliance(member_id, alliances) != "":
        return {"ok": false, "message": "Member cannot be invited."}
    if not alliance["invites"].has(member_id):
        alliance["invites"].append(member_id)
    alliances[alliance_id] = alliance
    _save(alliances)
    _message("Invitation sent to %s." % member_id)
    return {"ok": true, "message": "Invitation sent to %s." % member_id}

func join_alliance(alliance_id: String, member_id: String = PLAYER_ID) -> Dictionary:
    var alliances := _alliances()
    var alliance: Dictionary = alliances.get(alliance_id, {})
    if alliance.is_empty() or alliance.get("status") != "active":
        return {"ok": false, "message": "Alliance not found."}
    if alliance["members"].has(member_id):
        return {"ok": false, "message": "Already a member."}
    if not alliance["invites"].has(member_id):
        return {"ok": false, "message": "No invitation found for %s." % member_id}
    alliance["invites"].erase(member_id)
    alliance["members"][member_id] = {"role": "member", "joined_day": _day()}
    alliances[alliance_id] = alliance
    _save(alliances)
    _message("%s joined '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s joined the alliance." % member_id}

func leave_alliance(member_id: String = PLAYER_ID) -> Dictionary:
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    if str(alliance.get("founder_id", "")) == member_id:
        return {"ok": false, "message": "Founder must transfer leadership before leaving in V1."}
    alliance["members"].erase(member_id)
    alliances[id] = alliance
    _save(alliances)
    _message("%s left '%s'." % [member_id, alliance["name"]])
    return {"ok": true, "message": "%s left the alliance." % member_id}

func post_message(alliance_id: String, member_id: String, text: String) -> Dictionary:
    var alliances := _alliances()
    var alliance: Dictionary = alliances.get(alliance_id, {})
    text = text.strip_edges()
    if alliance.is_empty() or not alliance.get("members", {}).has(member_id):
        return {"ok": false, "message": "Member is not in this alliance."}
    if text.is_empty():
        return {"ok": false, "message": "Message cannot be empty."}
    alliance["chat"].append({"member": member_id, "text": text, "day": _day()})
    if alliance["chat"].size() > 50:
        alliance["chat"] = alliance["chat"].slice(alliance["chat"].size() - 50, alliance["chat"].size())
    alliances[alliance_id] = alliance
    _save(alliances)
    return {"ok": true, "message": "Alliance message posted."}

func donate_money(member_id: String, amount: int) -> Dictionary:
    if amount <= 0 or _cash() < amount:
        return {"ok": false, "message": "Insufficient cash for donation."}
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    _set_cash(_cash() - amount)
    alliance["treasury"] = int(alliance.get("treasury", 0)) + amount
    alliance["contributions"] = alliance.get("contributions", [])
    alliance["contributions"].append({"member": member_id, "type": "money", "amount": amount, "day": _day()})
    alliances[id] = alliance
    _save(alliances)
    _message("Donated $%d to '%s'." % [amount, alliance["name"]])
    return {"ok": true, "message": "Alliance received $%d." % amount}

func donate_resource(member_id: String, resource_id: String, amount: int) -> Dictionary:
    if resource_id.is_empty() or amount <= 0:
        return {"ok": false, "message": "Invalid resource donation."}
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var resources := _resources()
    if int(resources.get(resource_id, 0)) < amount:
        return {"ok": false, "message": "Not enough %s to donate." % resource_id}
    var alliance: Dictionary = alliances[id]
    resources[resource_id] = int(resources.get(resource_id, 0)) - amount
    alliance["resources"][resource_id] = int(alliance["resources"].get(resource_id, 0)) + amount
    alliance["contributions"] = alliance.get("contributions", [])
    alliance["contributions"].append({"member": member_id, "type": "resource", "resource": resource_id, "amount": amount, "day": _day()})
    _set_resources(resources)
    alliances[id] = alliance
    _save(alliances)
    _message("Donated %d %s to '%s'." % [amount, resource_id, alliance["name"]])
    return {"ok": true, "message": "Alliance received %d %s." % [amount, resource_id]}

func start_cooperative_project(member_id: String, project_name: String = "Community Expansion") -> Dictionary:
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    if int(alliance.get("treasury", 0)) < PROJECT_COST:
        return {"ok": false, "message": "Alliance needs $%d in its treasury." % PROJECT_COST}
    alliance["treasury"] = int(alliance["treasury"]) - PROJECT_COST
    alliance["projects"].append({"id": "project_%d" % (alliance["projects"].size() + 1), "name": project_name.strip_edges(), "status": "active", "progress": 0, "required_progress": 2, "started_day": _day(), "reward": PROJECT_REWARD})
    alliances[id] = alliance
    _save(alliances)
    _message("Cooperative project '%s' started." % project_name)
    return {"ok": true, "message": "Cooperative project started."}

func contribute_to_project(member_id: String, project_index: int = -1) -> Dictionary:
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    var index := project_index
    if index < 0:
        index = _find_active_project(alliance)
    if index < 0 or index >= alliance["projects"].size():
        return {"ok": false, "message": "No active cooperative project."}
    var project: Dictionary = alliance["projects"][index]
    if project.get("status") != "active":
        return {"ok": false, "message": "Project is already complete."}
    project["progress"] = int(project.get("progress", 0)) + 1
    if int(project["progress"]) >= int(project["required_progress"]):
        project["status"] = "complete"
        alliance["treasury"] = int(alliance.get("treasury", 0)) + PROJECT_REWARD
        project["completed_day"] = _day()
        project["reward_paid"] = PROJECT_REWARD
        _message("Cooperative project '%s' completed. Alliance earned $%d." % [project["name"], PROJECT_REWARD])
    else:
        _message("%s contributed to project '%s'." % [member_id, project["name"]])
    alliance["projects"][index] = project
    alliances[id] = alliance
    _save(alliances)
    return {"ok": true, "project": project.duplicate(true), "message": "Project contribution recorded."}

func complete_project(member_id: String, project_index: int = -1) -> Dictionary:
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    if id.is_empty():
        return {"ok": false, "message": "Member is not in an alliance."}
    var alliance: Dictionary = alliances[id]
    var index := project_index if project_index >= 0 else _find_active_project(alliance)
    if index < 0 or index >= alliance["projects"].size():
        return {"ok": false, "message": "Project not found."}
    var project: Dictionary = alliance["projects"][index]
    if int(project.get("progress", 0)) < int(project.get("required_progress", 2)):
        return {"ok": false, "message": "Project still needs more cooperation."}
    if project.get("status") == "complete":
        return {"ok": false, "message": "Project is already complete."}
    project["status"] = "complete"
    alliance["treasury"] = int(alliance.get("treasury", 0)) + int(project.get("reward", PROJECT_REWARD))
    project["completed_day"] = _day()
    alliance["projects"][index] = project
    alliances[id] = alliance
    _save(alliances)
    _message("Cooperative project '%s' completed and reward received." % project["name"])
    return {"ok": true, "reward": int(project.get("reward", PROJECT_REWARD)), "message": "Project completed."}

func _find_active_project(alliance: Dictionary) -> int:
    for i in range(alliance.get("projects", []).size()):
        if alliance["projects"][i].get("status") == "active":
            return i
    return -1

func get_alliance(alliance_id: String) -> Dictionary:
    return _alliances().get(alliance_id, {}).duplicate(true)

func get_member_alliance(member_id: String = PLAYER_ID) -> Dictionary:
    var alliances := _alliances()
    var id := _member_alliance(member_id, alliances)
    return alliances.get(id, {}).duplicate(true)

func list_alliances() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for alliance in _alliances().values():
        result.append(alliance.duplicate(true))
    return result
