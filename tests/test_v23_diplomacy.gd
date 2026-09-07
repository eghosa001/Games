extends SceneTree

## V2.3: diplomacy with consequences. Supply treaties move canonical goods,
## cancellation stings, acceptance builds goodwill, and envoy gifts court
## rivals through treasury and trust.
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
    var Diplomacy = load("res://scripts/diplomacy_system.gd")
    check(Diplomacy != null, "Diplomacy system loads")
    if Diplomacy == null:
        quit(1)
        return
    var diplomacy = Diplomacy.new()
    root.add_child(diplomacy)
    await process_frame

    var proposed: Dictionary = diplomacy.propose_treaty("player", "apex_materials", "supply", {"minimum_supply": 5}, 10)
    check(bool(proposed.get("ok", false)), "Supply treaty proposes")
    var treaty_id := str(proposed.get("treaty", {}).get("id", ""))
    var accepted: Dictionary = diplomacy.accept_treaty(treaty_id, "apex_materials")
    check(bool(accepted.get("ok", false)), "Counterparty accepts")
    check(abs(float(diplomacy.get_trust("player", "apex_materials")) - 52.0) < 0.01, "Acceptance builds trust")
    var breached: Dictionary = diplomacy.breach_treaty(treaty_id, "player", "missed shipment")
    check(bool(breached.get("ok", false)), "Breach resolves")
    check(str(breached.get("treaty", {}).get("status", "")) == "breached", "Breach marks the treaty")
    check(float(diplomacy.get_trust("player", "apex_materials")) < 52.0, "Breach burns trust")
    var cancelled: Dictionary = diplomacy.cancel_treaty(treaty_id, "player", "changed strategy")
    check(not bool(cancelled.get("ok", false)), "Breached treaties cannot be cancelled")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for envoy gifts")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.cash = 100000
        game.select_rival(0)
        var rel_before := int(game.command_system.relationship_system.rivals.rivals[0].get("relationship", 0))
        var trust_before := float(root.get_node_or_null("RenewDiplomacySystem").get_trust("player", "apex_materials"))
        game.send_envoy_gift()
        check(int(game.command_system.relationship_system.rivals.rivals[0].get("relationship", 0)) > rel_before, "Envoy gift improves relations")
        check(float(root.get_node_or_null("RenewDiplomacySystem").get_trust("player", "apex_materials")) > trust_before, "Envoy gift builds treaty trust")
        check(int(game.cash) < 100000, "Envoy gift spends treasury cash")
        game.free()
        await process_frame
    diplomacy.queue_free()
    await process_frame
    print("V23 DIPLOMACY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
