extends Node

## Autonomous NPC corporate politics for AllianceSystem.
## NPCs can join/form alliances, contribute, vote, sanction, defect and contest
## leadership. Successful control challenges can replace the Chairman.

var _last_day := 0

func _process(_delta: float) -> void:
    var game := get_tree().current_scene
    if game == null or not "day" in game: return
    var day := int(game.day)
    if day <= 0 or day == _last_day: return
    _last_day = day
    var rivals = game.get("rivals")
    var system = get_node_or_null("/root/RenewAllianceSystem")
    if rivals == null or system == null or not "rivals" in rivals: return
    simulate_day(system, rivals.rivals, day)

func simulate_day(system: Node, npcs: Array, day: int) -> Array[String]:
    var news: Array[String] = []
    for npc in npcs:
        if not npc is Dictionary: continue
        var id := str(npc.get("id", ""))
        if id.is_empty(): continue
        var alliance: Dictionary = system.get_member_alliance(id)
        if alliance.is_empty():
            var event := _seek_or_found(system, npc, day)
            if not event.is_empty(): news.append(event)
            alliance = system.get_member_alliance(id)
        if alliance.is_empty(): continue
        if _should_defect(npc, alliance, day):
            var left := system.leave_alliance(id)
            if bool(left.get("ok", false)):
                news.append("%s betrayed %s and withdrew from the alliance." % [npc.get("name", id), alliance.get("name", "the alliance")])
            continue
        _contribute(system, npc, alliance, day, news)
        _vote(system, npc, alliance, news)
        _sanction(system, npc, alliance, npcs, day, news)
        _contest_governance(system, npc, alliance, day, news)
    return news

func _seek_or_found(system: Node, npc: Dictionary, day: int) -> String:
    var id := str(npc.get("id", ""))
    var relationship := int(npc.get("relationship", 0))
    var priorities: Array = npc.get("strategic_priorities", [])
    var best_id := ""
    var best_score := -999999.0
    for alliance in system.list_alliances():
        if str(alliance.get("status", "active")) != "active": continue
        if alliance.get("members", {}).has(id): continue
        var score := float(alliance.get("reputation", 25.0)) + float(alliance.get("trust", 50.0)) * 0.5 + float(relationship) * 0.8
        if "alliances" in priorities: score += 18.0
        if int(alliance.get("treasury", 0)) >= 15000: score += 8.0
        if score > best_score: best_score = score; best_id = str(alliance.get("id", ""))
    if not best_id.is_empty() and (relationship >= 15 or "alliances" in priorities):
        var result := system.join_alliance(best_id, id)
        if bool(result.get("ok", false)): return "%s joined %s." % [npc.get("name", id), result["alliance"]["name"]]
    var cash := int(npc.get("cash", 0))
    if cash >= 35000 and day % 7 == 0 and relationship >= 0:
        var seed := min(20000, int(cash * 0.10))
        var created := system.create_alliance(id, "%s Business Coalition" % npc.get("name", id), seed)
        if bool(created.get("ok", false)):
            npc["cash"] = cash - seed
            return "%s founded %s." % [npc.get("name", id), created["alliance"]["name"]]
    return ""

func _contribute(system: Node, npc: Dictionary, alliance: Dictionary, day: int, news: Array[String]) -> void:
    if day % 2 != 0: return
    var id := str(npc.get("id", ""))
    var cash := int(npc.get("cash", 0))
    if cash < 20000: return
    var relationship := int(npc.get("relationship", 0))
    var rate := 0.02
    if relationship >= 25: rate += 0.025
    if float(alliance.get("trust", 50)) >= 70: rate += 0.02
    if "alliances" in npc.get("strategic_priorities", []): rate += 0.015
    var amount := int(clamp(float(cash) * rate, 500.0, 10000.0))
    var result := system.contribute(id, amount)
    if bool(result.get("ok", false)):
        npc["cash"] = cash - amount
        news.append("%s contributed $%d to %s." % [npc.get("name", id), amount, alliance.get("name", "the alliance")])

func _vote(system: Node, npc: Dictionary, alliance: Dictionary, news: Array[String]) -> void:
    for motion_id in alliance.get("votes", {}).keys():
        var motion: Dictionary = alliance["votes"][motion_id]
        if str(motion.get("status", "open")) != "open": continue
        var relationship := int(npc.get("relationship", 0))
        var text := str(motion.get("motion", "")).to_lower()
        var choice := relationship >= 0
        if text.contains("sanction") or text.contains("expel"): choice = relationship < -10
        if text.contains("director") or text.contains("governance") or text.contains("chairman") or text.contains("control"): choice = relationship >= 10
        var result := system.vote(str(alliance["id"]), str(npc.get("id", "")), str(motion_id), choice)
        if bool(result.get("ok", false)) and str(result.get("status", "")) == "passed":
            news.append("%s helped pass '%s' in %s." % [npc.get("name", "corporation"), motion.get("motion", motion_id), alliance.get("name", "the alliance")])

func _sanction(system: Node, npc: Dictionary, alliance: Dictionary, npcs: Array, day: int, news: Array[String]) -> void:
    if day % 5 != 0: return
    var relationship := int(npc.get("relationship", 0))
    if relationship > -20: return
    var id := str(npc.get("id", ""))
    for member_id in alliance.get("members", {}).keys():
        var target_id := str(member_id)
        if target_id == id: continue
        var target := _find(npcs, target_id)
        if target.is_empty() or int(target.get("relationship", 0)) >= relationship: continue
        var result := system.sanction(str(alliance["id"]), target_id, "Corporate conflict and breach of alliance interests.")
        if bool(result.get("ok", false)): news.append("%s sanctioned %s inside %s." % [npc.get("name", id), target.get("name", target_id), alliance.get("name", "the alliance")])
        return

func _should_defect(npc: Dictionary, alliance: Dictionary, day: int) -> bool:
    var id := str(npc.get("id", ""))
    if str(alliance.get("founder_id", "")) == id: return false
    var relationship := int(npc.get("relationship", 0))
    var trust := float(alliance.get("trust", 50))
    var retaliation := int(npc.get("retaliation", 0))
    if trust < 20 and relationship < 0: return true
    return retaliation > 0 and relationship < -35 and day % 3 == 0

func _contest_governance(system: Node, npc: Dictionary, alliance: Dictionary, day: int, news: Array[String]) -> void:
    if day % 6 != 0: return
    var id := str(npc.get("id", ""))
    if str(alliance.get("founder_id", "")) == id: return
    var member: Dictionary = alliance.get("members", {}).get(id, {})
    var contribution := int(member.get("contributed", 0))
    var chairman_id := str(alliance.get("founder_id", ""))
    var chairman: Dictionary = alliance.get("members", {}).get(chairman_id, {})
    var chairman_contribution := int(chairman.get("contributed", 0))
    if contribution <= max(1, chairman_contribution) * 1.25: return
    if int(npc.get("relationship", 0)) < 10: return
    var control := get_node_or_null("/root/RenewAllianceControl")
    if control == null: return
    var motion_id := "control_%s_%d" % [id, day]
    var opened := system.open_vote(str(alliance["id"]), id, motion_id, "%s control challenge against Chairman" % id)
    if not bool(opened.get("ok", false)): return
    # The challenger votes first; other NPC votes are processed on their turns.
    var result := system.vote(str(alliance["id"]), id, motion_id, true)
    if not bool(result.get("ok", false)): return
    if str(result.get("status", "")) != "passed": return
    var support := float(result.get("yes_percent", 0.0)) / 100.0
    if support < 0.67: return
    var coup := control.execute_coup(str(alliance["id"]), id, support, "NPC governance coup")
    if bool(coup.get("ok", false)):
        news.append("%s seized control of %s and became Chairman." % [npc.get("name", id), alliance.get("name", "the alliance")])

func _find(npcs: Array, id: String) -> Dictionary:
    for npc in npcs:
        if npc is Dictionary and str(npc.get("id", "")) == id: return npc
    return {}
