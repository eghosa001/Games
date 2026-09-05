extends Node
class_name RenewLiveOpsSystem

const SEASON_LENGTH := 30
var current_season: Variant = 1
var season_start_day: Variant = 1
var offers: Dictionary = {}
var challenges: Dictionary = {}
var community_goal: Variant = {"id":"community_goal","title":"World Recovery Fund","target":100000.0,"progress":0.0,"reward":{"cash":15000.0,"reputation":8}}
var last_day: Variant = -1

var seasonal_catalog: Variant = [
    {"id":"industrial_festival","title":"Industrial Renaissance","duration":10,"reward":{"production":1.10,"reputation":5}},
    {"id":"global_trade_week","title":"Global Trade Week","duration":7,"reward":{"sales":1.15,"logistics":0.90}},
    {"id":"innovation_month","title":"Innovation Drive","duration":14,"reward":{"research":1.25,"technology":1.10}}
]

func _ready() -> void:
    _ensure_content(_day())

func _process(_delta: float) -> void:
    var day: Variant = _day()
    if day == last_day: return
    last_day = day
    process_day(day)

func process_day(day: int) -> void:
    if day - season_start_day >= SEASON_LENGTH:
        current_season += 1
        season_start_day = day
        offers.clear()
        challenges.clear()
        _ensure_content(day)
        _track("liveops_season_started", {"season":current_season,"day":day})
    _ensure_content(day)
    _expire_content(day)
    _advance_community_goal(day)

func _ensure_content(day: int) -> void:
    var world = get_node_or_null("/root/RenewWorldEventSystem")
    if world == null: return
    var catalog_index: Variant = (current_season - 1) % seasonal_catalog.size()
    var season_def: Dictionary = seasonal_catalog[catalog_index]
    var event_id: Variant = "season_%d_%s" % [current_season, season_def["id"]]
    if world.events.has(event_id): return
    var def: Variant = {"id":event_id,"category":"seasonal","duration":int(season_def["duration"]),"scope":"global","causes":["season_rotation"],"effects":season_def["reward"].duplicate(true),"choices":[{"id":"participate","label":"Participate","effects":{"reputation":2}}],"follow_up_events":[]}
    world.register_event(def)
    world.trigger(event_id, {"season":current_season,"liveops":true}, day)
    offers["seasonal"] = {"id":event_id,"title":season_def["title"],"expires_day":day + int(season_def["duration"])}
    offers["limited_opportunity"] = {"id":"limited_opportunity_%d" % current_season,"title":"Limited Strategic Opportunity","expires_day":day + 5,"reward":{"cash":5000.0,"reputation":3}}
    challenges["challenge_%d" % current_season] = {"title":"Seasonal Expansion Challenge","target":2,"progress":0,"reward":{"cash":10000.0,"reputation":5},"expires_day":season_start_day + SEASON_LENGTH}

func _expire_content(day: int) -> void:
    for key in offers.keys():
        if int(offers[key].get("expires_day", day + 1)) < day: offers.erase(key)
    for key in challenges.keys():
        if int(challenges[key].get("expires_day", day + 1)) < day: challenges.erase(key)

func _apply_reward(reward: Dictionary, reason: String) -> void:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var cash_reward := int(round(float(reward.get("cash", 0.0))))
    if finance != null and cash_reward > 0:
        finance.receive(cash_reward, reason)
    var state = get_node_or_null("/root/RenewGameState")
    var reputation_reward := int(reward.get("reputation", 0))
    if state != null and reputation_reward != 0:
        var reputation := int(state.get_value("player", "reputation", 0))
        state.set_value("player", "reputation", reputation + reputation_reward)

func _advance_community_goal(day: int) -> void:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    var contribution: Variant = 0.0
    if finance != null:
        contribution = max(0.0, float(finance.get("cash"))) * 0.001
    community_goal["progress"] = min(float(community_goal["target"]), float(community_goal["progress"]) + contribution)
    if float(community_goal["progress"]) >= float(community_goal["target"]):
        _apply_reward(community_goal.get("reward", {}), "LiveOps community goal reward")
        community_goal["progress"] = 0.0
        _track("liveops_community_goal_completed", {"day":day})

func complete_challenge(challenge_id: String, progress := 1) -> Dictionary:
    if not challenges.has(challenge_id): return {"ok":false,"error":"challenge_not_found"}
    var c: Dictionary = challenges[challenge_id]
    c["progress"] = int(c.get("progress",0)) + int(progress)
    if int(c["progress"]) >= int(c.get("target",1)):
        _apply_reward(c.get("reward", {}), "LiveOps challenge reward")
        _track("liveops_challenge_completed", {"id":challenge_id})
    challenges[challenge_id] = c
    return {"ok":true,"challenge":c.duplicate(true)}

func get_state() -> Dictionary:
    return {"season":current_season,"season_start_day":season_start_day,"offers":offers.duplicate(true),"challenges":challenges.duplicate(true),"community_goal":community_goal.duplicate(true)}

func capture_state() -> Dictionary: return get_state().merged({"last_day":last_day})

func restore_state(state: Dictionary) -> void:
    current_season = int(state.get("season",1))
    season_start_day = int(state.get("season_start_day",1))
    offers = state.get("offers",{}).duplicate(true)
    challenges = state.get("challenges",{}).duplicate(true)
    community_goal = state.get("community_goal",community_goal).duplicate(true)
    last_day = int(state.get("last_day",-1))

func _track(name: String, data: Dictionary) -> void:
    var analytics = get_node_or_null("/root/RenewAnalyticsSystem")
    if analytics != null and analytics.has_method("track"): analytics.track(name, data)

func _day() -> int:
    var state = get_node_or_null("/root/RenewGameState")
    return int(state.get_value("player", "day", 1)) if state != null else 1