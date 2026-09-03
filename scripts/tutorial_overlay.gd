extends CanvasLayer

const Tutorial = preload("res://scripts/tutorial.gd")
var game: Node
var tutorial = Tutorial.new()
var overlay_root: Control
var panel: Panel
var title_label: Label
var body_label: Label
var progress_label: Label
var hint_label: Label
var continue_button: Button
var collapsed_button: Button
var dismissed: Variant = false
var last_step: Variant = -1

func _ready() -> void:
    game = get_parent()
    _build()
    _refresh()
    overlay_root.resized.connect(_layout_responsive)
    _layout_responsive()

func _process(_delta: float) -> void:
    if game == null:
        return
    var current_action: String = String(tutorial.current().get("action", "COMPLETE"))
    if not tutorial.completed and current_action != "COMPLETE":
        var old_step: int = int(tutorial.step)
        tutorial.notify(current_action, game)
        if tutorial.step != old_step:
            game.message = "TUTORIAL COMPLETE: %s" % String(tutorial.current().get("title", "Next step"))
    _refresh()

func _build() -> void:
    overlay_root = Control.new()
    overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(overlay_root)
    panel = Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay_root.add_child(panel)
    title_label = Label.new()
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_label.add_theme_font_size_override("font_size", 16)
    panel.add_child(title_label)
    progress_label = Label.new()
    progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_label.add_theme_font_size_override("font_size", 11)
    panel.add_child(progress_label)
    body_label = Label.new()
    body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.add_theme_font_size_override("font_size", 12)
    panel.add_child(body_label)
    hint_label = Label.new()
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_label.add_theme_font_size_override("font_size", 11)
    panel.add_child(hint_label)
    continue_button = Button.new()
    continue_button.text = "GOT IT"
    continue_button.focus_mode = Control.FOCUS_NONE
    continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
    continue_button.pressed.connect(_dismiss_current)
    panel.add_child(continue_button)
    collapsed_button = Button.new()
    collapsed_button.text = "TUTORIAL"
    collapsed_button.focus_mode = Control.FOCUS_NONE
    collapsed_button.mouse_filter = Control.MOUSE_FILTER_STOP
    collapsed_button.pressed.connect(_expand)
    collapsed_button.hide()
    overlay_root.add_child(collapsed_button)

func _layout_responsive() -> void:
    if overlay_root == null or panel == null:
        return
    var w: Variant = maxf(overlay_root.size.x, 320.0)
    var h: Variant = maxf(overlay_root.size.y, 480.0)
    var narrow: Variant = w < 700.0
    if narrow:
        panel.position = Vector2(12, minf(418.0, h - 150.0))
        panel.size = Vector2(w - 24.0, 86.0)
        title_label.position = Vector2(12, 8)
        title_label.size = Vector2(w - 150.0, 24)
        progress_label.position = Vector2(12, 32)
        progress_label.size = Vector2(w - 24.0, 18)
        body_label.position = Vector2(12, 50)
        body_label.size = Vector2(w - 24.0, 34)
        hint_label.hide()
        continue_button.position = Vector2(w - 112.0, 8)
        continue_button.size = Vector2(96, 32)
    else:
        panel.position = Vector2(24, 82)
        panel.size = Vector2(360, 150)
        title_label.position = Vector2(18, 12)
        title_label.size = Vector2(324, 28)
        progress_label.position = Vector2(18, 40)
        progress_label.size = Vector2(324, 20)
        body_label.position = Vector2(18, 66)
        body_label.size = Vector2(324, 48)
        hint_label.position = Vector2(18, 112)
        hint_label.size = Vector2(200, 24)
        hint_label.show()
        continue_button.position = Vector2(248, 108)
        continue_button.size = Vector2(92, 32)
    collapsed_button.position = Vector2(12, minf(418.0, h - 150.0))
    collapsed_button.size = Vector2(120, 40)

func _refresh() -> void:
    if dismissed or game == null:
        return
    var current: Dictionary = tutorial.current()
    var step: int = int(tutorial.step)
    if step != last_step:
        last_step = step
    title_label.text = String(current.get("title", "RENEW TUTORIAL"))
    progress_label.text = "PHASE A  •  STEP %d/%d" % [min(step + 1, tutorial.steps.size()), tutorial.steps.size()]
    body_label.text = String(current.get("text", "Keep building."))
    hint_label.text = "Goal: " + String(current.get("action", "COMPLETE"))
    if tutorial.completed:
        continue_button.text = "HIDE"
        hint_label.text = "PHASE A COMPLETE • SCALE THE EMPIRE"

func _dismiss_current() -> void:
    var action: String = String(tutorial.current().get("action", ""))
    tutorial.notify(action, game)
    _hide_overlay()

func _hide_overlay() -> void:
    dismissed = true
    panel.hide()
    collapsed_button.show()

func _collapse() -> void:
    _hide_overlay()

func _expand() -> void:
    dismissed = false
    panel.show()
    collapsed_button.hide()
    _layout_responsive()
    _refresh()
