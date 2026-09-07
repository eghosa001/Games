extends SceneTree

## V3.2: corporation wars. Every 12 days past day 30 the strongest rival
## raids the weakest: assets change hands, the target's shares go on
## fire sale, and hollowed-out rivals are eliminated.
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
    var Rivals = load("res://scripts/competitors.gd")
    check(Rivals != null, "Competitor model loads")
    if Rivals == null:
        quit(1)
        return
    var rivals = Rivals.new()
    rivals._normalize()
    check(rivals.maybe_corporate_war(12).is_empty(), "No wars in the opening")
    check(rivals.maybe_corporate_war(35).is_empty(), "Wars only break out every 12 days")
    for r in rivals.rivals:
        r["cash"] = 50000
    var target_before := {}
    for r in rivals.rivals:
        target_before[str(r.get("id", ""))] = int(r.get("businesses", 0))
    var war: Dictionary = rivals.maybe_corporate_war(36)
    check(not war.is_empty(), "War breaks out on day 36")
    check(not str(war.get("attacker", "")).is_empty(), "War names an attacker")
    check(not str(war.get("target", "")).is_empty(), "War names a target")
    check(str(war.get("attacker", "")) != str(war.get("target", "")), "Attacker and target differ")
    check(not str(war.get("news", "")).is_empty(), "War produces news")
    var attacker: Dictionary = {}
    var target: Dictionary = {}
    for r in rivals.rivals:
        if str(r.get("name", "")) == str(war.get("attacker", "")):
            attacker = r
        if str(r.get("name", "")) == str(war.get("target", "")):
            target = r
    check(int(attacker.get("businesses", 0)) == int(target_before.get(str(attacker.get("id", "")), 0)) + 1, "Attacker seizes a business")
    check(int(target.get("businesses", 0)) == int(target_before.get(str(target.get("id", "")), 0)) - 1, "Target loses a business")
    check(bool(target.get("war_sale", false)), "Target shares go on fire sale")
    var target_index: int = int(rivals.rivals.find(target))
    var sale_price: int = int(rivals.share_price(target_index))
    target["war_sale"] = false
    var full_price: int = int(rivals.share_price(target_index))
    target["war_sale"] = true
    check(sale_price * 2 == full_price or sale_price * 2 == full_price - 1, "Fire sale halves the share price")
    var status: Dictionary = rivals.ai_status(target_index)
    check(bool(status.get("war_sale", false)), "Status flags the fire sale")
    check(status.has("eliminated"), "Status tracks elimination")

    rivals.rivals[0]["assets"] = 9
    rivals.rivals[0]["businesses"] = 4
    for i in range(1, rivals.rivals.size()):
        rivals.rivals[i]["cash"] = 50000
        rivals.rivals[i]["businesses"] = 1
        rivals.rivals[i]["assets"] = 1
    rivals.rivals[0]["cash"] = 50000
    var kill: Dictionary = rivals.maybe_corporate_war(48)
    check(not kill.is_empty(), "A second war breaks out on day 48")
    check(bool(kill.get("eliminated", false)), "The raid wipes out its target")
    var victim: Dictionary = rivals.rivals[1]
    check(bool(victim.get("eliminated", false)), "The weakest rival is eliminated")
    check(int(victim.get("businesses", 0)) == 0, "The victim holds no businesses")
    var victim_index := 1
    check(rivals.share_price(victim_index) == 0, "Absorbed companies stop trading")
    check(not bool(rivals.battle_status(victim_index).get("ok", false)), "No battles with absorbed companies")
    check(not bool(rivals.negotiate_acquisition(victim_index, 9999999, 100, []).get("ok", false)), "No buyouts of absorbed companies")
    var news: Array = rivals.daily_update(49)
    check(news is Array, "Daily update returns a news array")
    var eliminated_name := str(victim.get("name", ""))
    var mentions_eliminated := false
    for item in news:
        if str(item).find(eliminated_name) >= 0:
            mentions_eliminated = true
            break
    check(not mentions_eliminated, "Daily update skips the eliminated rival")
    var snapshot: Dictionary = rivals.capture_state()
    var restored = Rivals.new()
    restored.restore_state(snapshot)
    check(restored.capture_state() == snapshot, "War state persists across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads after war changes")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    print("V32 CORPORATE WARS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
