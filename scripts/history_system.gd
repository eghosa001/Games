extends RefCounted
class_name RenewHistorySystem

var records: Array = []
var next_id := 1

func record(day: int, event_type: String, title: String, description: String, importance: String = "notable", related_entity_ids: Array = []) -> Dictionary:
    var entry := {
        "id": "hist_%05d" % next_id,
        "day": day,
        "type": event_type,
        "title": title,
        "description": description,
        "importance": importance,
        "related_entity_ids": related_entity_ids.duplicate(true)
    }
    next_id += 1
    records.append(entry)
    return entry.duplicate(true)

func recent(limit: int = 10) -> Array:
    var result := []
    var start := max(0, records.size() - limit)
    for i in range(records.size() - 1, start - 1, -1):
        result.append(records[i].duplicate(true))
    return result

func milestones() -> Array:
    var result := []
    for entry in records:
        if entry["importance"] == "major" or entry["importance"] == "historic":
            result.append(entry.duplicate(true))
    return result

func snapshot() -> Dictionary:
    return {"next_id": next_id, "records": records.duplicate(true)}

func restore(snapshot_data: Dictionary) -> void:
    records = snapshot_data.get("records", []).duplicate(true)
    next_id = max(1, int(snapshot_data.get("next_id", records.size() + 1)))
