extends Node

## Progression-aware presentation adapter for the mobile management shell.
##
## The underlying systems stay directly callable for save compatibility and
## automated tests. This adapter only controls discovery on the phone UI so the
## player meets strategic systems in the intended company-growth order.

const EXISTING_BUTTON_REQUIREMENTS := {
    "FINANCE & PORTFOLIO": "finance",
    "REGIONS": "regions",
    "SUPPLY CHAIN": "supply_chain",
    "EXPANSION": "branches",
    "RIVALS & INTELLIGENCE": "competitors",
    "TECHNOLOGY": "technology",
    "ALLIANCES": "alliances"
}

const BUSINESS_INJECTIONS := [
    {"feature":"employees", "text":"EMPLOYEE MANAGEMENT", "screen":"EmployeePanel"},
    {"feature":"contracts", "text":"CONTRACTS", "screen":"ContractPanel"}
]

const WORLD_INJECTIONS := [
    {"feature":"alliances", "text":"ALLIANCE STRATEGY", "screen":"AlliancePanel"},
    {"feature":"diplomacy", "text":"DIPLOMACY & TREATIES", "screen":"RenewDiplomacyUI"},
    {"feature":"infrastructure", "text":"INFRASTRUCTURE", "screen":"InfrastructurePanel"},
    {"feature":"technology", "text":"TECHNOLOGY & RESEARCH", "screen":"TechnologyPanel"},
    {"feature":"acquisitions", "text":"CORPORATIONS & ACQUISITIONS", "screen":"CorporationsPanel"},
    {"feature":"headquarters", "text":"HEADQUARTERS & WORLD POWER", "screen":"HeadquartersPanel"},
    {"feature":"legacy", "text":"LEGACY & COLLECTIONS", "screen":"CollectionPanel"}
]

var _refresh_clock := 0.0
var _last_tab := -1
var _last_level := -1

func _process(delta: float) -> void:
    _refresh_clock += delta
    if _refresh_clock < 0.12:
        return
    _refresh_clock = 0.0
    var mobile := _mobile_shell()
    if mobile == null or not bool(mobile.call("_is_mobile_layout")):
        return
    var action_box = mobile.get("action_box")
    if action_box == null or not is_instance_valid(action_box):
        return
    var progression := _progression()
    if progression == null:
        return
    var tab := int(mobile.get("active_tab"))
    var level := int(progression.get_level()) if progression.has_method("get_level") else 1
    _apply_existing_visibility(action_box, progression)
    _remove_stale_injections(action_box)
    if tab == 1:
        _inject_entries(mobile, action_box, progression, BUSINESS_INJECTIONS)
    elif tab == 2:
        _inject_entries(mobile, action_box, progression, WORLD_INJECTIONS)
    elif tab == 3:
        _inject_company_menu(mobile, action_box, progression)
    _last_tab = tab
    _last_level = level

func _progression():
    var services := get_node_or_null("/root/RenewServices")
    if services != null and services.has_method("get_service"):
        return services.get_service("RenewProgressionSystem")
    return get_node_or_null("/root/RenewProgressionSystem")

func _mobile_shell():
    return get_node_or_null("/root/Renew/UI/MainHUD/MobileScaleFix")

func _has_feature(progression, feature: String) -> bool:
    if progression == null:
        return false
    if progression.has_method("has_unlock"):
        return bool(progression.has_unlock(feature))
    return false

func _apply_existing_visibility(action_box: Node, progression) -> void:
    for child in action_box.get_children():
        if not child is Button:
            continue
        if bool(child.get_meta("progression_injected", false)):
            continue
        var label := str(child.text).strip_edges().to_upper()
        if EXISTING_BUTTON_REQUIREMENTS.has(label):
            var feature := str(EXISTING_BUTTON_REQUIREMENTS[label])
            child.visible = _has_feature(progression, feature)
            child.disabled = not child.visible

func _remove_stale_injections(action_box: Node) -> void:
    for child in action_box.get_children():
        if child is Button and bool(child.get_meta("progression_injected", false)):
            child.queue_free()

func _inject_entries(mobile: Node, action_box: Node, progression, entries: Array) -> void:
    for entry in entries:
        if not _has_feature(progression, str(entry.get("feature", ""))):
            continue
        _add_progression_screen(mobile, action_box, str(entry.get("text", "")), str(entry.get("screen", "")))

func _inject_company_menu(mobile: Node, action_box: Node, progression) -> void:
    # The MORE tab remains a records/save area, but unlocked strategic layers
    # are mirrored here so a player can always find a newly earned capability.
    var entries := [
        {"feature":"contracts", "text":"CONTRACTS", "screen":"ContractPanel"},
        {"feature":"alliances", "text":"ALLIANCES", "screen":"AlliancePanel"},
        {"feature":"diplomacy", "text":"DIPLOMACY", "screen":"RenewDiplomacyUI"},
        {"feature":"infrastructure", "text":"INFRASTRUCTURE", "screen":"InfrastructurePanel"},
        {"feature":"technology", "text":"TECHNOLOGY", "screen":"TechnologyPanel"},
        {"feature":"acquisitions", "text":"CORPORATIONS & ACQUISITIONS", "screen":"CorporationsPanel"},
        {"feature":"headquarters", "text":"HEADQUARTERS", "screen":"HeadquartersPanel"},
        {"feature":"legacy", "text":"LEGACY & COLLECTIONS", "screen":"CollectionPanel"}
    ]
    _inject_entries(mobile, action_box, progression, entries)

func _add_progression_screen(mobile: Node, action_box: Node, text: String, screen: String) -> void:
    if text.is_empty() or screen.is_empty():
        return
    for child in action_box.get_children():
        if child is Button and str(child.text).strip_edges().to_upper() == text.to_upper():
            return
    var button: Button = null
    if mobile.has_method("_action_button"):
        var made = mobile.call("_action_button", text)
        if made is Button:
            button = made
    if button == null:
        button = Button.new()
        button.text = text
        button.custom_minimum_size = Vector2(0, 54)
    button.set_meta("progression_injected", true)
    button.tooltip_text = "Unlocked through company progression."
    button.pressed.connect(_open_screen.bind(screen))
    action_box.add_child(button)

func _open_screen(screen: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen)
