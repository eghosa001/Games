extends CanvasLayer

# Presentation layer for moments that deserve more than a status-line update.
# It observes game state and never changes the simulation itself.
var game: Node
var banner: Panel
var title_label: Label
var body_label: Label
var timer: Variant = 0.0
var seen: Variant = {}

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    var root_control := Control.new()
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_control)
    banner = Panel.new()
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.modulate.a = 0.0
    root_control.add_child(banner)
    title_label = Label.new()
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(title_label)
    body_label = Label.new()
    body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(body_label)
    _layout()
    var window := get_tree().root
    if window != null and not window.size_changed.is_connected(_layout):
        window.size_changed.connect(_layout)
    _seed()

func _layout() -> void:
    if banner == null or title_label == null or body_label == null:
        return
    var window := get_tree().root
    if window == null:
        return
    var size := Vector2(window.size)
    var narrow := size.x < 600.0
    var margin := 12.0 if narrow else 24.0
    var width := minf(920.0, maxf(280.0, size.x - margin * 2.0))
    var height := 132.0 if narrow else 150.0
    height = minf(height, maxf(104.0, size.y - 24.0))
    banner.size = Vector2(width, height)
    banner.position = Vector2((size.x - width) * 0.5, clampf(size.y * 0.14, 12.0, maxf(12.0, size.y - height - 12.0)))
    var inner_width := maxf(1.0, width - 28.0)
    title_label.position = Vector2(14.0, 10.0)
    title_label.size = Vector2(inner_width, 36.0)
    body_label.position = Vector2(14.0, 48.0)
    body_label.size = Vector2(inner_width, maxf(44.0, height - 58.0))
    title_label.add_theme_font_size_override("font_size", 18 if narrow else 26)
    body_label.add_theme_font_size_override("font_size", 12 if narrow else 16)

func _process(delta: float) -> void:
    if game == null:
        game = get_tree().root.get_node_or_null("Renew")
        if game == null:
            return
        _seed()
    _check()
    if timer > 0.0:
        timer -= delta
        if timer <= 0.0:
            _hide_banner()

func _seed() -> void:
    if game == null:
        seen = {}
        return
    seen = {
        "opened": bool(game.business_open),
        "expansion": _expansion_count() > 0,
        "acquisition": int(game.acquisition_count) > 0,
        "profit": int(game.total_profit) > 0,
        "takeover": _takeover_wins() > 0
    }

func _check() -> void:
    if game == null:
        return
    var states: Variant = {
        "opened": bool(game.business_open),
        "expansion": _expansion_count() > 0,
        "acquisition": int(game.acquisition_count) > 0,
        "profit": int(game.total_profit) > 0,
        "takeover": _takeover_wins() > 0
    }
    var moments: Variant = {
        "opened": ["FIRST BUSINESS", "Your restored property is now a living company. Make it profitable."],
        "expansion": ["EMPIRE EXPANSION", "Your first additional asset is working toward a larger network."],
        "acquisition": ["COMPETITOR ACQUIRED", "You turned competition into ownership. The market just changed."],
        "profit": ["FIRST PROFIT", "The business model works. Reinvest, expand and protect your advantage."],
        "takeover": ["GIANT CHALLENGED", "You won a hostile takeover. You are no longer playing small."]
    }
    for id in states:
        if bool(states[id]) and not bool(seen.get(id, false)):
            seen[id] = true
            var moment: Array = moments[id]
            _show_banner(String(moment[0]), String(moment[1]))
            return

func _expansion_count() -> int:
    var count: Variant = 0
    if game == null or game.expansion == null:
        return count
    for p in game.expansion.properties:
        if bool(p.get("owned", false)):
            count += 1
    return count

func _takeover_wins() -> int:
    if game == null:
        return 0
    var corporate = game.get_node_or_null("World/Corporate")
    if corporate == null:
        return 0
    return int(corporate.takeover_wins)

func _show_banner(title: String, body: String) -> void:
    _layout()
    title_label.text = "★ " + title + " ★"
    body_label.text = body
    banner.show()
    timer = 5.0
    var tween: Variant = create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    banner.scale = Vector2(0.92, 0.92)
    banner.modulate.a = 0.0
    tween.tween_property(banner, "scale", Vector2.ONE, 0.28)
    tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.20)

func _hide_banner() -> void:
    var tween: Variant = create_tween()
    tween.tween_property(banner, "modulate:a", 0.0, 0.25)
