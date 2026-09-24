extends CanvasLayer

# Compatibility shim for the retired floating strategy summary.
# The production RESTORA command UI already presents market signals and the next
# objective in dedicated, responsive surfaces. Keeping a second CanvasLayer
# summary caused it to overlap the desktop REP card, so this node remains only
# for coordinator compatibility and never renders a duplicate player-facing HUD.
var root: Control
var panel: Panel
var label: Label
var _coordinator_active := false

func _coordinator() -> Node:
    return RenewServices.get_service("RenewUIRegionCoordinator")

func _ready() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    panel = Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.hide()
    root.add_child(panel)

    label = Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(label)

    root.resized.connect(_layout_responsive)
    _layout_responsive()
    set_process(false)

func _enter_tree() -> void:
    var coordinator := _coordinator()
    if coordinator != null:
        coordinator.set_active_screen("")

func _layout_responsive() -> void:
    if panel != null:
        panel.hide()

func _should_show() -> bool:
    return false

func _get_rect() -> Rect2:
    if panel == null or not panel.visible:
        return Rect2()
    return panel.get_global_rect()

func _set_coordinator_active(value: bool) -> void:
    _coordinator_active = value

func _on_screen_changed(_open: bool) -> void:
    if panel != null:
        panel.hide()
