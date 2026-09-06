extends Node

## Independent leadership-coup pass. Runs after normal alliance politics and
## converts sustained NPC governance dominance into real Chairman transfer.

const CHECK_INTERVAL_SECONDS := 0.25
var _last_day: int = 0
var _day_check_timer: Timer

func _ready() -> void:
    _day_check_timer = Timer.new()
    _day_check_timer.wait_time = CHECK_INTERVAL_SECONDS
    _day_check_timer.one_shot = false
    _day_check_timer.timeout.connect(_check_current_day)
    add_child(_day_check_timer)
    _day_check_timer.start()
    call_deferred("_check_current_day")

func _exit_tree() -> void:
    if _day_check_timer != null:
        if _day_check_timer.timeout.is_connected(_check_current_day):
            _day_check_timer.timeout.disconnect(_check_current_day)
        _day_check_timer.stop()
        _day_check_timer.queue_free()
        _day_check_timer = null

func _check_current_day() -> void:
    var game: Variant = get_tree().current_scene
    if game == null or not "day" in game: return
    var day: int = int(game.day)
    if day <= 0 or day == _last_day or day % 6 != 0: return
    _last_day = day
    var rivals = game.get("rivals")
    var system = get_node_or_null("/root/RenewAllianceSystem")
    var control = get_node_or_null("/root/RenewAllianceControl")
    if rivals == null or system == null or control == null or not "rivals" in rivals: return
    for alliance in system.list_alliances():
        _consider_alliance(system, control, alliance, rivals.rivals, day)

func _consider_alliance(system: Node, control: Node, alliance: Dictionary, npcs: Array, day: int) -> void:
    if str(alliance.get("status", "")) != "active": return
    var members: Dictionary = alliance.get("members", {})
    if members.size() < 3: return
    var chairman_id: String = str(alliance.get("founder_id", ""))
    var chairman: Dictionary = _find(npcs, chairman_id)
    var chairman_rel: int = int(chairman.get("relationship", 0))
    var chairman_contribution: int = int(members.get(chairman_id, {}).get("contributed", 0))
    var challenger_id: String = ""
    var best_score: float = -999999.0
    var support: int = 0
    for member_id in members.keys():
        var id: String = str(member_id)
        if id == chairman_id: continue
        var npc: Dictionary = _find(npcs, id)
        if npc.is_empty(): continue
        var contribution: int = int(members[id].get("contributed", 0))
        var relationship: int = int(npc.get("relationship", 0))
        var role: String = str(members[id].get("role", ""))
        if role != "director": continue
        if contribution <= max(1, chairman_contribution) * 1.25: continue
        var score: float = float(contribution) + float(relationship) * 500.0
        if score > best_score:
            best_score = score
            challenger_id = id
    if challenger_id.is_empty(): return
    var challenger: Dictionary = _find(npcs, challenger_id)
    for member_id in members.keys():
        var voter_id: String = str(member_id)
        if voter_id == challenger_id:
            support += 1
            continue
        var voter: Dictionary = _find(npcs, voter_id)
        if voter.is_empty(): continue
        var relationship: int = int(voter.get("relationship", 0))
        if relationship >= 15: support += 1
        elif relationship >= 5 and chairman_rel < 0: support += 1
    var support_ratio: float = float(support) / float(members.size())
    if support_ratio < 0.67: return
    # A coup is only allowed when the challenger has stronger contribution and
    # the Chairman has lost political confidence, preventing constant coups.
    if int(challenger.get("relationship", 0)) < 15: return
    if chairman_rel >= 30 and float(alliance.get("trust", 50.0)) >= 55.0: return
    var result: Variant = control.execute_coup(str(alliance["id"]), challenger_id, support_ratio, "NPC coalition coup")
    if bool(result.get("ok", false)):
        _publish_news(game_news(), "%s seized control of %s with %d%% support." % [challenger.get("name", challenger_id), alliance.get("name", "the alliance"), int(support_ratio * 100.0)])

func _find(npcs: Array, id: String) -> Dictionary:
    for npc in npcs:
        if npc is Dictionary and str(npc.get("id", "")) == id: return npc
    return {}

func game_news() -> Node:
    return get_node_or_null("/root/RenewNewsSystem")

func _publish_news(news_system: Node, text: String) -> void:
    if news_system == null: return
    if news_system.has_method("publish"):
        news_system.publish(text)
    elif news_system.has_method("add_news"):
        news_system.add_news(text)
