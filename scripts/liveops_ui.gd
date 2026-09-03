extends CanvasLayer

var panel: Panel
var label: Label

func _ready() -> void:
    layer = 62
    panel = Panel.new()
    panel.position = Vector2(760, 80)
    panel.size = Vector2(480, 500)
    add_child(panel)
    label = Label.new()
    label.position = Vector2(20, 20)
    label.size = Vector2(440, 450)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(label)
    panel.visible = false
    set_process(true)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_L:
        panel.visible = not panel.visible
        _refresh()

func _process(_delta: float) -> void:
    if panel.visible: _refresh()

func _refresh() -> void:
    var system = get_node_or_null("/root/RenewLiveOpsSystem")
    if system == null:
        label.text = "LIVEOPS\nSystem unavailable."
        return
    var state: Dictionary = system.get_state()
    var text: Variant = "LIVEOPS — SEASON %d\n\n" % int(state.get("season",1))
    text += "ROTATING CONTENT\n"
    for item in state.get("offers", {}).values():
        text += "• %s — expires Day %d\n" % [str(item.get("title","Opportunity")), int(item.get("expires_day",0))]
    text += "\nCHALLENGES\n"
    for challenge in state.get("challenges", {}).values():
        text += "• %s: %d/%d — expires Day %d\n" % [str(challenge.get("title","Challenge")), int(challenge.get("progress",0)), int(challenge.get("target",1)), int(challenge.get("expires_day",0))]
    var goal: Dictionary = state.get("community_goal", {})
    text += "\nCOMMUNITY GOAL\n%s\nProgress: %.0f / %.0f\n" % [str(goal.get("title","Community Goal")), float(goal.get("progress",0)), float(goal.get("target",0))]
    text += "\nWorld crises and seasonal events are driven through WorldEventSystem."
    label.text = text
