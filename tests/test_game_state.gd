extends SceneTree

var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1; print("PASS: " + label)
    else: failed += 1; push_error("FAIL: " + label)
func run() -> void:
    var State = load("res://scripts/game_state.gd")
    check(State != null, "GameState script loads")
    if State == null: quit(1); return
    var state = State.new(); root.add_child(state); await process_frame
    state.set_value("economy", "cash", 25000); state.set_value("player", "day", 7); state.set_value("player", "reputation", 12); state.set_value("properties", "owned", true); state.set_value("businesses", "business_open", true); state.set_value("employees", "roster", [{"id":"emp_001","status":"active"}])
    var snapshot: Dictionary = state.capture()
    check(int(snapshot.get("schema_version", 0)) == 8, "GameState writes schema version 8"); check(snapshot.has("domains"), "GameState contains canonical domain map"); check(not snapshot.has("legacy"), "New GameState saves do not contain legacy payload")
    for domain in state.DOMAINS: check(snapshot["domains"].has(domain), "Domain exists: " + str(domain))
    check(state.get_value("economy","cash",0) == 25000, "Economy owns cash"); check(state.get_value("player","day",0) == 7, "Player owns day"); check(state.get_value("player","reputation",0) == 12, "Player owns reputation"); check(state.get_value("properties","owned",false), "Properties owns property state"); check(state.get_value("businesses","business_open",false), "Businesses owns operating state"); check(state.get_value("employees","employees",null) == null, "Employee count is not duplicated in GameState"); check(state.get_value("employees","roster",[]).size() == 1, "Employees owns roster")
    var before: Dictionary = state.get_domain("economy").duplicate(true); state.set_value("economy","day",99); check(state.get_domain("economy") == before, "Cross-domain key is rejected")
    var restored = State.new(); root.add_child(restored); await process_frame
    check(not restored.restore(snapshot).is_empty(), "Canonical schema restores successfully"); check(restored.get_value("economy","cash",0) == 25000, "Restored economy cash"); check(restored.get_value("player","day",0) == 7, "Restored player day"); check(restored.get_value("employees","roster",[]).size() == 1, "Restored employee roster")
    print("GAME STATE RESULT: %d passed, %d failed" % [passed, failed]); quit(1 if failed > 0 else 0)
