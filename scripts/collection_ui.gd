extends CanvasLayer

var system
var main
var panel: PanelContainer
var summary: Label
var content: VBoxContainer
var selected_type := "all"
const TYPES := ["all", "historic_properties", "rare_machinery", "landmark_businesses", "unique_technologies", "special_contracts", "famous_employees", "world_event_artifacts"]

func _ready() -> void:
    layer = 61
    system = get_node_or_null("/root/RenewCollectionSystem")
    main = get_tree().current_scene
    _build_ui()
    _set_visible(false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            _set_visible(not panel.visible)
            if panel.visible: _refresh()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and panel.visible:
            _set_visible(false)
            get_viewport().set_input_as_handled()

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.position = Vector2(110, 55)
    panel.size = Vector2(1060, 610)
    add_child(panel)
    var root := VBoxContainer.new()
    panel.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    var title := Label.new()
    title.text = "CORPORATE COLLECTIONS  [C]"
    title.add_theme_font_size_override("font_size", 24)
    header.add_child(title)
    var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
    var close := Button.new(); close.text = "Close"; close.pressed.connect(func(): _set_visible(false)); header.add_child(close)
    summary = Label.new(); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(summary)
    var tabs := HBoxContainer.new(); root.add_child(tabs)
    for type in TYPES:
        var b := Button.new(); b.text = "All" if type == "all" else type.replace("_", " ").capitalize(); b.pressed.connect(_select.bind(type)); tabs.add_child(b)
    var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)

func _set_visible(value: bool) -> void:
    if is_instance_valid(panel): panel.visible = value

func _select(type: String) -> void:
    selected_type = type
    _refresh()

func _refresh() -> void:
    if system == null: return
    var status: Dictionary = system.get_status()
    var bonuses: Dictionary = status.get("bonuses", {})
    summary.text = "Collection value: $%s  •  Items: %d\nGameplay rewards: %s\nPress C to close." % [_money(int(status.get("value", 0))), int(status.get("total", 0)), _bonus_text(bonuses)]
    for child in content.get_children(): child.queue_free()
    var items: Array = system.get_all() if selected_type == "all" else system.list_collection(selected_type)
    if items.is_empty():
        var empty := Label.new(); empty.text = "No items collected in this category yet."; content.add_child(empty); return
    for item in items:
        var card := PanelContainer.new(); card.custom_minimum_size = Vector2(0, 82); content.add_child(card)
        var box := VBoxContainer.new(); card.add_child(box)
        var head := Label.new(); head.text = "%s  •  Day %d" % [str(item.get("title", "Collection item")), int(item.get("day", 1))]; head.add_theme_font_size_override("font_size", 16); box.add_child(head)
        var details: Dictionary = item.get("details", {})
        var reward: Dictionary = item.get("reward", {})
        var detail := Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.text = "Type: %s\n%s\nReward: %s" % [str(item.get("type", "")).replace("_", " ").capitalize(), _dict_text(details), _dict_text(reward)]; box.add_child(detail)

func _bonus_text(bonuses: Dictionary) -> String:
    var parts: Array[String] = []
    for key in bonuses.keys(): parts.append("%s %s" % [str(key).replace("_", " "), _format_bonus(bonuses[key])])
    return ", ".join(parts) if not parts.is_empty() else "None yet"

func _format_bonus(value) -> String:
    var number := float(value)
    return "+%.0f%%" % (number * 100.0) if abs(number) < 1.0 else "+%d" % int(number)

func _dict_text(data: Dictionary) -> String:
    var parts: Array[String] = []
    for key in data.keys(): parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(data[key])])
    return " • ".join(parts)

func _money(value: int) -> String:
    return "%,d" % value
