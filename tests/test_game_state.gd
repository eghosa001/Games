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
    var core := {"cash":25000,"day":7,"reputation":12,"owned":true,"business_open":true,"employees":4,"roster":[{"id":"emp_001","status":"active"}],"resources":{"materials":18},"contract_days":3,"rivals":[{"name":"Test Rival","relationship":40}],"total_profit":4200}
    var snapshot: Dictionary = state.capture(core)
    check(snapshot.get("state_version", 0) == 7, "GameState writes current version")
    check(snapshot.has("domains"), "GameState contains domain map")
    check(snapshot.has("legacy"), "GameState preserves migration-compatible flat state")
    for domain in state.DOMAINS: check(snapshot["domains"].has(domain), "Domain exists: " + str(domain))
    check(state.get_value("economy","cash",0) == 25000, "Economy owns cash")
    check(state.get_value("player","day",0) == 7, "Player domain owns day")
    check(state.get_value("player","reputation",0) == 12, "Player domain owns reputation")
    check(state.get_value("properties","owned",false) == true, "Properties domain owns property state")
    check(state.get_value("businesses","business_open",false) == true, "Businesses domain owns operating state")
    check(state.get_value("employees","employees",null) == null, "Employee count is not stored in GameState")
    check(state.get_value("employees","roster",[]).size() == 1, "Employees domain owns employee roster")
    check(state.get_value("contracts","contract_days",0) == 3, "Contracts domain owns contract state")
    check(not state.get_domain("alliances").has("relationship"), "Alliances has no duplicate competitor relationship")
    check(not state.get_domain("diplomacy").has("relationship"), "Diplomacy has no duplicate competitor relationship")
    check(not state.get_domain("progression").has("reputation"), "Progression has no duplicate player reputation")
    check(not state.get_domain("progression").has("day"), "Progression has no duplicate player day")
    check(not state.get_domain("analytics").has("last_profit"), "Analytics has no duplicate economy profit")
    state.set_value("economy","cash",18000); check(state.get_value("economy","cash",0) == 18000, "Canonical economy write works")
    state.set_value("player","day",9); check(state.get_value("player","day",0) == 9, "Canonical player write works")
    var before := state.get_domain("economy"); state.set_value("economy","day",99); check(state.get_domain("economy") == before, "Cross-domain key is rejected")
    var restored = State.new(); root.add_child(restored); await process_frame; restored.restore_state_compat(snapshot)
    check(restored.get_value("economy","cash",0) == 25000, "Canonical state restores economy")
    check(restored.get_value("competitors","rivals",[]).size() == 1, "Canonical state restores competitors")
    print("GAME STATE RESULT: %d passed, %d failed" % [passed, failed]); quit(1 if failed > 0 else 0)
