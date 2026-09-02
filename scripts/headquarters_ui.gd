extends CanvasLayer

var system = null
var main = null
var panel: PanelContainer
var status_label: Label
var area_label: Label
var upgrade_button: Button
var area_button: Button
var selected_area := "executive_offices"
var area_ids: Array = ["executive_offices", "board_room", "research", "training", "archives", "museum", "technology_center"]

func _ready() -> void:
    system = get_node_or_null("/root/RenewHeadquartersSystem")
    main = get_parent()
    _build_ui()
    _refresh()

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(25, 110)
    panel.size = Vector2(360, 300)
    add_child(panel)
    var box := VBoxContainer.new()
    panel.add_child(box)

    var title := Label.new()
    title.text = "HEADQUARTERS"
    title.add_theme_font_size_override("font_size", 22)
    box.add_child(title)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(status_label)

    upgrade_button = Button.new()
    upgrade_button.text = "UPGRADE HEADQUARTERS"
    upgrade_button.pressed.connect(_upgrade_hq)
    box.add_child(upgrade_button)

    var area_title := Label.new()
    area_title.text = "Functional Areas"
    box.add_child(area_title)

    area_label = Label.new()
    area_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(area_label)

    area_button = Button.new()
    area_button.text = "BUILD / UPGRADE SELECTED AREA"
    area_button.pressed.connect(_build_area)
    box.add_child(area_button)

    var cycle := Button.new()
    cycle.text = "NEXT AREA"
    cycle.pressed.connect(_next_area)
    box.add_child(cycle)

func _upgrade_hq() -> void:
    if system == null or main == null: return
    var result: Dictionary = system.upgrade(int(main.get("cash")), int(main.get("day")))
    if bool(result.get("ok", false)):
        main.cash -= int(result["cost"])
        main.message = "HQ upgraded to %s." % result["stage"]
        if main.has_method("_log"): main._log("HEADQUARTERS: upgraded to %s (-$%s)." % [result["stage"], _money(int(result["cost"]))])
    else:
        main.message = str(result.get("reason", "HQ upgrade unavailable."))
    _refresh()

func _build_area() -> void:
    if system == null or main == null: return
    var result: Dictionary
    if system.has_area(selected_area):
        result = system.upgrade_area(selected_area, int(main.get("cash")))
    else:
        result = system.unlock_area(selected_area, int(main.get("cash")))
    if bool(result.get("ok", false)):
        main.cash -= int(result["cost"])
        main.message = "%s is now operational (level %d)." % [result["area"], int(result.get("level", 1))]
        if main.has_method("_log"): main._log("HQ AREA: %s level %d (-$%s)." % [result["area"], int(result.get("level", 1)), _money(int(result["cost"]))])
    else:
        main.message = str(result.get("reason", "Area unavailable."))
    _refresh()

func _next_area() -> void:
    var index := area_ids.find(selected_area)
    selected_area = area_ids[(index + 1) % area_ids.size()]
    _refresh()

func _refresh() -> void:
    if system == null or main == null: return
    var check: Dictionary = system.can_upgrade(int(main.get("cash")))
    var next_text := "MAX LEVEL"
    if bool(check.get("ok", false)): next_text = "%s ($%s)" % [check["stage"], _money(int(check["cost"]))]
    elif system.get_stage_index() < 4: next_text = "%s" % check.get("reason", "Locked")
    status_label.text = "Stage: %s\nValue invested: $%s\nCash: $%s\nNext: %s\nAreas: %d/%d" % [system.get_stage(), _money(system.headquarters_value), _money(int(main.get("cash"))), next_text, _built_count(), area_ids.size()]
    upgrade_button.disabled = system.get_stage_index() >= 4
    var spec = system.AREA_SPECS[selected_area]
    var built := system.has_area(selected_area)
    var level := system.area_level(selected_area)
    area_label.text = "%s\nRequired stage: %s\nStatus: %s\nLevel: %d\nBase cost: $%s" % [spec["name"], system.STAGES[int(spec["min_stage"])], "Operational" if built else ("Unlocked" if system.get_stage_index() >= int(spec["min_stage"]) else "Locked"), level, _money(int(spec["cost"]) * max(1, level))]
    area_button.text = "UPGRADE %s" % spec["name"].to_upper() if built else "BUILD %s" % spec["name"].to_upper()

func _built_count() -> int:
    var count := 0
    for area_id in area_ids:
        if system.has_area(area_id): count += 1
    return count

func _money(value: int) -> String:
    return "%,d" % value
