extends SceneTree

var passed := 0
var failed := 0

class FakeMobile:
    extends Node
    func _action_button(text: String) -> Button:
        var button := Button.new()
        button.text = text
        button.custom_minimum_size = Vector2(0, 54)
        return button

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func _button(box: Node, text: String) -> Button:
    for child in box.get_children():
        if child is Button and str(child.text) == text:
            return child
    return null

func _add_button(box: Node, text: String) -> Button:
    var b := Button.new()
    b.text = text
    box.add_child(b)
    return b

func run() -> void:
    var guide = root.get_node_or_null("RenewMobileProgressionGuide")
    var services = root.get_node_or_null("RenewServices")
    var state = root.get_node_or_null("RenewGameState")
    var progression = services.get_service("RenewProgressionSystem") if services != null else null
    check(guide != null, "Mobile progression guide autoload resolves")
    check(state != null and progression != null, "Progression stack resolves")
    if guide == null or state == null or progression == null:
        quit(1)
        return

    state.set_value("progression", "xp", 0)
    state.set_value("progression", "level", 1)
    state.set_value("progression", "unlocks", [])
    progression._backfill_semantic_unlocks()

    var box := VBoxContainer.new()
    root.add_child(box)
    var finance := _add_button(box, "FINANCE & PORTFOLIO")
    var regions := _add_button(box, "REGIONS")
    var alliances := _add_button(box, "ALLIANCES")
    var technology := _add_button(box, "TECHNOLOGY")
    guide._apply_existing_visibility(box, progression)
    check(not finance.visible, "Level 1 mobile discovery hides finance")
    check(not regions.visible, "Level 1 mobile discovery hides regions")
    check(not alliances.visible, "Level 1 mobile discovery hides alliances")
    check(not technology.visible, "Level 1 mobile discovery hides technology")

    state.set_value("progression", "xp", 1400)
    state.set_value("progression", "level", 6)
    state.set_value("progression", "unlocks", [])
    progression._backfill_semantic_unlocks()
    guide._apply_existing_visibility(box, progression)
    check(finance.visible, "Level 6 mobile discovery exposes finance")
    check(regions.visible, "Level 6 mobile discovery exposes regions")
    check(alliances.visible, "Level 6 mobile discovery exposes alliances")
    check(technology.visible, "Level 6 mobile discovery exposes technology")

    var fake := FakeMobile.new()
    root.add_child(fake)
    var injected := VBoxContainer.new()
    root.add_child(injected)
    guide._inject_entries(fake, injected, progression, guide.WORLD_INJECTIONS)
    check(_button(injected, "DIPLOMACY & TREATIES") != null, "Level 6 exposes diplomacy discovery")
    check(_button(injected, "INFRASTRUCTURE") != null, "Level 6 exposes infrastructure discovery")
    check(_button(injected, "TECHNOLOGY & RESEARCH") != null, "Level 6 exposes technology and research discovery")
    check(_button(injected, "CORPORATIONS & ACQUISITIONS") == null, "Level 6 still hides acquisitions")

    for child in injected.get_children():
        child.free()
    state.set_value("progression", "xp", 2000)
    state.set_value("progression", "level", 7)
    progression._backfill_semantic_unlocks()
    guide._inject_entries(fake, injected, progression, guide.WORLD_INJECTIONS)
    check(_button(injected, "CORPORATIONS & ACQUISITIONS") != null, "Level 7 exposes acquisitions and corporate strategy")
    check(_button(injected, "HEADQUARTERS & WORLD POWER") == null, "Level 7 still hides headquarters")

    for child in injected.get_children():
        child.free()
    state.set_value("progression", "xp", 2800)
    state.set_value("progression", "level", 8)
    progression._backfill_semantic_unlocks()
    guide._inject_entries(fake, injected, progression, guide.WORLD_INJECTIONS)
    check(_button(injected, "HEADQUARTERS & WORLD POWER") != null, "Level 8 exposes headquarters and world power")
    check(_button(injected, "LEGACY & COLLECTIONS") == null, "Level 8 still hides legacy")

    for child in injected.get_children():
        child.free()
    state.set_value("progression", "xp", 3800)
    state.set_value("progression", "level", 9)
    progression._backfill_semantic_unlocks()
    guide._inject_entries(fake, injected, progression, guide.WORLD_INJECTIONS)
    check(_button(injected, "LEGACY & COLLECTIONS") != null, "Level 9 exposes legacy and collections")

    print("MOBILE PROGRESSION GUIDE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
