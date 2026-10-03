extends Node

## Runtime bridge for the approved warm architectural RESTORA direction.
## The gameplay HUD remains authoritative; this layer adds the high-value visual
## storytelling surfaces without duplicating any simulation or navigation logic.

const CALDER_ART := preload("res://Assets/Art/restora_calder_works.svg")
const REGION_ART := preload("res://Assets/Art/restora_region_map.svg")

var _last_content_id := 0
var _last_view := ""

func _process(_delta: float) -> void:
    var hud := get_parent()
    if hud == null:
        return
    var content = hud.get("mobile_content")
    if not content is Control or not is_instance_valid(content):
        return
    var view := str(hud.get("active_view"))
    var content_id := content.get_instance_id()
    var marker := content.get_node_or_null("FigmaEnhancementMarker")
    if content_id == _last_content_id and view == _last_view and marker != null:
        return
    _last_content_id = content_id
    _last_view = view
    _add_marker(content)
    match view:
        "live":
            _enhance_home(hud, content)
        "property":
            _enhance_property(hud, content)
        "world":
            _enhance_world(content)

func _add_marker(content: Control) -> void:
    var old := content.get_node_or_null("FigmaEnhancementMarker")
    if old != null:
        old.queue_free()
    var marker := Node.new()
    marker.name = "FigmaEnhancementMarker"
    content.add_child(marker)

func _art(name_value: String, texture: Texture2D, size_value: Vector2) -> TextureRect:
    var art := TextureRect.new()
    art.name = name_value
    art.texture = texture
    art.size = size_value
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return art

func _label(node: Node, name_value: String, text_value: String, rect: Rect2, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.name = name_value
    label.text = text_value
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.48))
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.add_child(label)
    return label

func _theme_color(role: String, fallback: Color) -> Color:
    var manager := get_node_or_null("/root/RestoraThemeManager")
    return manager.color(role) if manager != null and manager.has_method("color") else fallback

func _shift_content(content: Control, threshold: float, amount: float, excluded: Control) -> void:
    for child in content.get_children():
        if child is Control and child != excluded and child.position.y >= threshold:
            child.position.y += amount
    content.custom_minimum_size.y += amount
    content.size.y += amount

func _enhance_home(hud: Node, content: Control) -> void:
    var hero := content.get_node_or_null("ExecutiveHero") as Control
    if hero == null or hero.get_node_or_null("ActiveRestorationArt") != null:
        return
    _shift_content(content, 270.0, 70.0, hero)
    hero.size.y = 246.0
    hero.clip_contents = true
    var art := _art("ActiveRestorationArt", CALDER_ART, Vector2(hero.size.x, 116.0))
    hero.add_child(art)
    hero.move_child(art, 0)
    var scrim := ColorRect.new()
    scrim.name = "ActiveRestorationScrim"
    scrim.position = Vector2(0, 74)
    scrim.size = Vector2(hero.size.x, 42)
    scrim.color = Color(0.08, 0.07, 0.05, 0.62)
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero.add_child(scrim)
    hero.move_child(scrim, 1)
    var eyebrow := hero.get_node_or_null("Eyebrow") as Label
    var title := hero.get_node_or_null("HeroTitle") as Label
    var goal := hero.get_node_or_null("HeroGoal") as Label
    var action := hero.get_node_or_null("PrimaryNextMove") as Button
    if eyebrow != null:
        eyebrow.text = "ACTIVE RESTORATION"
        eyebrow.position = Vector2(21, 91)
        eyebrow.size.x = hero.size.x - 42
    if title != null:
        title.text = "The Calder Works"
        title.position = Vector2(21, 126)
        title.size = Vector2(hero.size.x - 42, 27)
    if goal != null:
        goal.text = "Victorian textile mill • %d%% restored • %s" % [int(hud.call("_building_progress")), str(hud.call("_building_stage_name"))]
        goal.position = Vector2(21, 155)
        goal.size = Vector2(hero.size.x - 42, 30)
    if action != null:
        action.text = "CONTINUE RESTORATION"
        action.position = Vector2(21, 202)
        action.size = Vector2(hero.size.x - 42, 38)
    for child in hero.get_children():
        if child is Panel and child != art and is_equal_approx(child.position.y, 112.0):
            child.position.y = 190.0

func _enhance_property(hud: Node, content: Control) -> void:
    var selected := content.get_node_or_null("SelectedProperty") as Control
    if selected == null or selected.get_node_or_null("PropertyVisual") != null:
        return
    _shift_content(content, 310.0, 112.0, selected)
    selected.size.y += 112.0
    var existing := selected.get_children()
    for child in existing:
        if child is Control:
            child.position.y += 112.0
    var art := _art("PropertyVisual", CALDER_ART, Vector2(selected.size.x, 126.0))
    selected.add_child(art)
    selected.move_child(art, 0)
    var type_label := selected.get_node_or_null("Type") as Label
    if type_label != null:
        type_label.text = "Victorian textile mill • Foundry Ward"
    var detail := selected.get_node_or_null("Detail") as Label
    if detail != null:
        detail.text += " • Target £740K"

func _enhance_world(content: Control) -> void:
    if content.get_node_or_null("StrategicRegionMap") != null:
        return
    for child in content.get_children():
        if child is Control and child.position.y >= 82.0:
            child.position.y += 206.0
    content.custom_minimum_size.y += 206.0
    content.size.y += 206.0
    var map_card := Panel.new()
    map_card.name = "StrategicRegionMap"
    map_card.position = Vector2(18, 82)
    map_card.size = Vector2(content.size.x - 36.0, 188.0)
    map_card.clip_contents = true
    map_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = _theme_color("surface", Color("fffdf7"))
    style.border_color = _theme_color("border", Color("c9bda9"))
    style.set_border_width_all(1)
    style.set_corner_radius_all(20)
    style.shadow_color = Color(0, 0, 0, 0.10)
    style.shadow_size = 9
    style.shadow_offset = Vector2(0, 4)
    map_card.add_theme_stylebox_override("panel", style)
    content.add_child(map_card)
    var art := _art("RegionMapArt", REGION_ART, map_card.size)
    map_card.add_child(art)
    _label(map_card, "MapLabel", "YOUR REGIONAL FOOTPRINT", Rect2(14, 14, map_card.size.x - 28, 18), 10, _theme_color("gold", Color("9a6728")))
