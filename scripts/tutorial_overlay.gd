extends CanvasLayer

const Tutorial = preload("res://scripts/tutorial.gd")
var game: Node
var tutorial = Tutorial.new()
var panel: Panel
var title_label: Label
var body_label: Label
var progress_label: Label
var hint_label: Label
var continue_button: Button
var collapsed_button: Button
var collapsed := false
var last_step := -1

func _ready() -> void:
    game = get_parent()
    _build()
    _refresh()

func _process(_delta: float) -> void:
    if game == null:
        return
    var current_action: String = String(tutorial.current().get("action", "COMPLETE"))
    if not tutorial.completed and current_action != "COMPLETE":
        var old_step := tutorial.step
        tutorial.notify(current_action, game)
        if tutorial.step != old_step:
            game.message = "TUTORIAL COMPLETE: %s" % String(tutorial.current().get("title", "Next step"))
    _refresh()

func _build() -> void:
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    panel = Panel.new()
    panel.position = Vector2(24, 78)
    panel.size = Vector2(360, 150)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(panel)
    title_label = Label.new()
    title_label.position = Vector2(18, 12)
    title_label.size = Vector2(324, 28)
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_label.add_theme_font_size_override("font_size", 16)
    panel.add_child(title_label)
    progress_label = Label.new()
    progress_label.position = Vector2(18, 40)
    progress_label.size = Vector2(324, 20)
    progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    progress_label.add_theme_font_size_override("font_size", 11)
    panel.add_child(progress_label)
    body_label = Label.new()
    body_label.position = Vector2(18, 66)
    body_label.size = Vector2(324, 48)
    body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.add_theme_font_size_override("font_size", 12)
    panel.add_child(body_label)
    hint_label = Label.new()
    hint_label.position = Vector2(18, 112)
    hint_label.size = Vector2(200, 24)
    hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint_label.add_theme_font_size_override("font_size", 11)
    panel.add_child(hint_label)
    continue_button = Button.new()
    continue_button.text = "GOT IT"
    continue_button.position = Vector2(248, 108)
    continue_button.size = Vector2(92, 32)
    continue_button.focus_mode = Control.FOCUS_NONE
    continue_button.mouse_filter = Control.MOUSE_FILTER_STOP
    continue_button.pressed.connect(_dismiss_current)
    panel.add_child(continue_button)
    collapsed_button = Button.new()
    collapsed_button.text = "TUTORIAL"
    collapsed_button.position = Vector2(24, 78)
    collapsed_button.size = Vector2(120, 40)
    collapsed_button.focus_mode = Control.FOCUS_NONE
    collapsed_button.mouse_filter = Control.MOUSE_FILTER_STOP
    collapsed_button.pressed.connect(_expand)
    collapsed_button.hide()
    root.add_child(collapsed_button)

func _refresh() -> void:
    if collapsed or game == null:
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
    if tutorial.completed:
        _collapse()
        return
    var action: String = String(tutorial.current().get("action", ""))
    var text: String = tutorial.notify(action, game)
    if tutorial.completed:
        title_label.text = "FIRST BUSINESS COMPLETE"
        body_label.text = text
        hint_label.text = "PHASE A COMPLETE"
        continue_button.text = "HIDE"
    else:
        _refresh()

func _collapse() -> void:
    collapsed = true
    panel.hide()
    collapsed_button.show()

func _expand() -> void:
    collapsed = false
    collapsed_button.hide()
    panel.show()
    _refresh()
