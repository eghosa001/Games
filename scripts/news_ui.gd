extends CanvasLayer

## RENEW DAILY reader. Press D to open, Esc to close.
var panel: PanelContainer
var issue_label: Label
var archive_label: Label
var content: VBoxContainer
var open := false

func _ready() -> void:
    layer = 70
    _build()
    panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_D:
            toggle()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and open:
            toggle()
            get_viewport().set_input_as_handled()

func toggle() -> void:
    open = not open
    panel.visible = open
    if open: _refresh()

func _news():
    return get_node_or_null("/root/RenewNewsSystem")

func _build() -> void:
    panel = PanelContainer.new()
    panel.name = "RenewDaily"
    panel.position = Vector2(110, 55)
    panel.size = Vector2(1060, 610)
    panel.custom_minimum_size = Vector2(1060, 610)
    add_child(panel)
    var margin := MarginContainer.new()
    for pair in [["margin_left", 24], ["margin_right", 24], ["margin_top", 20], ["margin_bottom", 20]]:
        margin.add_theme_constant_override(str(pair[0]), int(pair[1]))
    panel.add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    margin.add_child(root)
    var header := HBoxContainer.new()
    root.add_child(header)
    issue_label = Label.new()
    issue_label.text = "RENEW DAILY"
    issue_label.add_theme_font_size_override("font_size", 28)
    header.add_child(issue_label)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close := Button.new()
    close.text = "Close [Esc]"
    close.pressed.connect(toggle)
    header.add_child(close)
    archive_label = Label.new()
    root.add_child(archive_label)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)
    content = VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 9)
    scroll.add_child(content)

func _refresh() -> void:
    var news = _news()
    if news == null:
        issue_label.text = "RENEW DAILY — unavailable"
        return
    var issue: Dictionary = news.get_current_issue()
    issue_label.text = "RENEW DAILY  •  %s" % str(issue.get("date_label", "Today's Edition"))
    archive_label.text = "Personalized business intelligence from the live simulation.  •  %d archived editions  •  Press D to close" % news.get_archive(999999).size()
    for child in content.get_children(): child.queue_free()
    var stories: Array = issue.get("stories", [])
    if stories.is_empty():
        var empty := Label.new()
        empty.text = "The newsroom has no verified developments yet."
        content.add_child(empty)
        return
    var current_section := ""
    for story in stories:
        var section := str(story.get("section", "Your Company"))
        if section != current_section:
            current_section = section
            var section_label := Label.new()
            section_label.text = "— %s —" % section.to_upper()
            section_label.add_theme_font_size_override("font_size", 18)
            content.add_child(section_label)
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(0, 82)
        content.add_child(card)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 3)
        card.add_child(box)
        var kicker := Label.new()
        kicker.text = str(story.get("kicker", "News desk")).to_upper()
        kicker.add_theme_font_size_override("font_size", 11)
        box.add_child(kicker)
        var headline := Label.new()
        headline.text = str(story.get("headline", "Verified development"))
        headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        headline.add_theme_font_size_override("font_size", 16)
        box.add_child(headline)
        var body := Label.new()
        body.text = str(story.get("body", ""))
        body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(body)

func _process(_delta: float) -> void:
    if open: _refresh()
