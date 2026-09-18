extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var Collection = load("res://scripts/collection_system.gd")
    check(Collection != null, "Collection system loads")
    if Collection == null:
        quit(1)
        return

    var collection: Node = Collection.new()
    root.add_child(collection)
    await process_frame
    collection.set_process(false)

    var first: Dictionary = collection.collect("historic_properties", "Founding Warehouse", {}, {"value": 25000}, 2, "property|founding")
    check(bool(first.get("ok", false)) and not bool(first.get("already_collected", true)), "Collection accepts a new artifact")
    var duplicate: Dictionary = collection.collect("historic_properties", "Founding Warehouse", {}, {"value": 25000}, 2, "property|founding")
    check(bool(duplicate.get("already_collected", false)), "Collection deduplicates artifacts")

    collection.collect("unique_technologies", "Automation", {}, {"value": 30000}, 8, "technology|automation")
    var status: Dictionary = collection.get_status()
    check(int(status.get("total", 0)) == 2, "Collection counts permanent artifacts")
    check(int(collection.get_collection_value()) == 55000, "Collection value aggregates rewards")
    var bonuses: Dictionary = collection.get_bonuses()
    check(int(bonuses.get("reputation", 0)) >= 2, "Artifacts grant collection bonuses")
    check(int(bonuses.get("technology", 0)) >= 3, "Technology artifacts grant technology bonus")

    var restored: Node = Collection.new()
    root.add_child(restored)
    await process_frame
    restored.set_process(false)
    restored.restore_state(collection.capture_state())
    check(int(restored.get_status().get("total", 0)) == 2, "Collections survive restore")
    check(int(restored.get_bonuses().get("technology", 0)) >= 3, "Collection bonuses survive restore")

    collection.free()
    restored.free()
    print("COLLECTION SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
