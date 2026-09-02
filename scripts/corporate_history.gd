extends RefCounted
class_name CorporateHistory

## Permanent, player-facing history. This is deliberately separate from the
## short-lived activity log so important moments survive for the lifetime of a save.

const MAX_ENTRIES := 500
var entries: Array[Dictionary] = []

func record(day: int, category: String, title: String, detail: String) -> Dictionary:
    var entry := {
        "day": day,
        "category": category,
        "title": title,
        "detail": detail
    }
    entries.append(entry)
    if entries.size() > MAX_ENTRIES:
        entries.pop_front()
    return entry

func record_milestone(day: int, milestone: String, detail: String) -> Dictionary:
    return record(day, "Milestone", milestone, detail)

func latest(limit: int = 20) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var start := maxi(0, entries.size() - limit)
    for i in range(start, entries.size()):
        result.append(entries[i].duplicate(true))
    result.reverse()
    return result

func has_title(title: String) -> bool:
    for entry in entries:
        if String(entry.get("title", "")) == title:
            return true
    return false

func serialize() -> Dictionary:
    return {"entries":entries.duplicate(true)}

func deserialize(data: Dictionary) -> void:
    entries.clear()
    for entry in data.get("entries", []):
        entries.append(entry.duplicate(true))
    if entries.size() > MAX_ENTRIES:
        entries = entries.slice(entries.size() - MAX_ENTRIES)
