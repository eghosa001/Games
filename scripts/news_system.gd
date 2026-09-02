extends RefCounted
class_name RenewNewsSystem

var editions: Array = []
var next_id := 1

func generate_daily(day: int, events: Array, history: Array, player_state: Dictionary, competitor_headlines: Array = []) -> Dictionary:
    var articles: Array = []
    for event in events:
        var article := _event_article(event, day)
        if not article.is_empty():
            articles.append(article)
    for headline in competitor_headlines:
        articles.append({
            "section": "Rivals",
            "importance": 2,
            "title": "Rival activity: %s" % str(headline),
            "body": "Competitive activity is changing the market around your company."
        })
    if articles.is_empty():
        var cash := int(player_state.get("cash", 0))
        articles.append({
            "section": "Your Company",
            "importance": 1,
            "title": "A quiet day at RENEW",
            "body": "No major disruption was recorded today. Cash position: $%s." % str(cash)
        })
    articles.sort_custom(func(a, b): return int(a["importance"]) > int(b["importance"]))
    var edition := {
        "id": "daily_%05d" % next_id,
        "day": day,
        "articles": articles.slice(0, 12)
    }
    next_id += 1
    editions.append(edition)
    if editions.size() > 90:
        editions.pop_front()
    return edition.duplicate(true)

func latest() -> Dictionary:
    if editions.is_empty():
        return {}
    return editions[editions.size() - 1].duplicate(true)

func snapshot() -> Dictionary:
    return {"next_id": next_id, "editions": editions.duplicate(true)}

func restore(snapshot_data: Dictionary) -> void:
    editions = snapshot_data.get("editions", []).duplicate(true)
    next_id = max(1, int(snapshot_data.get("next_id", editions.size() + 1)))

func _event_article(event: Dictionary, day: int) -> Dictionary:
    var title := str(event.get("title", "World event"))
    var text := str(event.get("text", event.get("description", "The market changed.")))
    var cash := int(event.get("cash", 0))
    var rep := int(event.get("rep", 0))
    var impact := abs(cash) + abs(rep) * 500
    return {
        "section": "World",
        "importance": 3 if impact >= 5000 else 2,
        "title": title,
        "body": "%s Financial impact: $%s. Reputation impact: %s." % [text, str(cash), str(rep)],
        "day": day
    }
