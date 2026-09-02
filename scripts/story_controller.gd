extends Node

const HistorySystem = preload("res://scripts/history_system.gd")
const NewsSystem = preload("res://scripts/news_system.gd")

var history = HistorySystem.new()
var news = NewsSystem.new()
var parent: Node
var last_day := 0
var previous_stage := "Neglected"
var previous_business_open := false
var previous_reputation := 0
var initialized := false

func _ready() -> void:
    parent = get_parent()
    if parent == null:
        return
    last_day = int(parent.get("day"))
    previous_stage = str(parent.get("stage"))
    previous_business_open = bool(parent.get("business_open"))
    previous_reputation = int(parent.get("reputation"))
    _restore()
    initialized = true

func _process(_delta: float) -> void:
    if not initialized or parent == null:
        return
    var day := int(parent.get("day"))
    if day == last_day:
        return
    _record_state_changes(day)
    var edition_events: Array = []
    var latest_history := history.recent(6)
    for item in latest_history:
        if int(item["day"]) == day:
            edition_events.append({"title": item["title"], "text": item["description"], "cash": 0, "rep": 0})
    var edition := news.generate_daily(day, edition_events, latest_history, {
        "cash": int(parent.get("cash")),
        "reputation": int(parent.get("reputation"))
    })
    _persist()
    if parent.has_method("_log"):
        parent.call("_log", "RENEW DAILY: %d stories published." % edition["articles"].size())
    last_day = day

func latest_news() -> Dictionary:
    return news.latest()

func milestones() -> Array:
    return history.milestones()

func _record_state_changes(day: int) -> void:
    var stage := str(parent.get("stage"))
    if stage != previous_stage:
        var importance := "major" if stage == "Operational" else "notable"
        history.record(day, "restoration", "Restoration milestone: %s" % stage, "The Old Warehouse reached the %s stage." % stage, importance, ["old_warehouse"])
        previous_stage = stage
    var business_open := bool(parent.get("business_open"))
    if business_open and not previous_business_open:
        history.record(day, "founding", "RENEW Goods began trading", "The restored property became the first operating business of the company.", "historic", ["renew_goods"])
        previous_business_open = true
    var reputation := int(parent.get("reputation"))
    if previous_reputation < 25 and reputation >= 25:
        history.record(day, "milestone", "The company earned strategic credibility", "RENEW Goods crossed 25 reputation and entered a new competitive tier.", "major", ["renew_goods"])
    previous_reputation = reputation

func _persist() -> void:
    var game_state = _game_state()
    if game_state == null:
        return
    game_state.set_value(["history"], history.snapshot())
    game_state.set_value(["news"], news.snapshot())

func _restore() -> void:
    var game_state = _game_state()
    if game_state == null or not game_state.has_state():
        return
    var history_state = game_state.get_value(["history"], {})
    if history_state is Dictionary:
        history.restore(history_state)
    var news_state = game_state.get_value(["news"], {})
    if news_state is Dictionary:
        news.restore(news_state)

func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null:
        return null
    var root = tree.get_root()
    if root == null:
        return null
    return root.get_node_or_null("RenewGameState")
