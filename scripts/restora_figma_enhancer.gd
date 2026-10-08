extends Node

## Runtime bridge for the approved warm architectural RESTORA direction.
## The gameplay HUD remains authoritative; this layer adds the high-value visual
## storytelling surfaces without duplicating any simulation or navigation logic.

const WAREHOUSE_STAGES := preload("res://Assets/Art/building_warehouse_progression.svg")
const WORKSHOP_STAGES := preload("res://Assets/Art/building_factory_progression.svg")
const COMMERCIAL_STAGES := preload("res://Assets/Art/building_office_progression.svg")
const REGION_ART := preload("res://Assets/Art/restora_region_map.svg")

var _last_content_id := 0
var _last_view := ""
var _art_refresh_elapsed := 0.0

func _process(delta: float) -> void:
    var hud := get_parent()
    if hud == null:
        return
    var content_value = hud.get("mobile_content")
    if not content_value is Control or not is_instance_valid(content_value):
        return
    var content: Control = content_value as Control
    var view := str(hud.get("active_view"))
    var content_id: int = content.get_instance_id()
    var marker: Node = content.get_node_or_null("FigmaEnhancementMarker")
    if content_id == _last_content_id and view == _last_view and marker != null:
        _art_refresh_elapsed += delta
        if _art_refresh_elapsed >= 0.25 and view in ["live", "property"]:
            _art_refresh_elapsed = 0.0
            _sync_stage_art(content, hud, view)
        return
    _art_refresh_elapsed = 0.0
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
    # Configure texture minimum sizing before assigning its source and bounds;
    # otherwise Godot can retain the atlas's native 256x144 minimum and
    # repaint beyond the intended 84px-tall mobile preview.
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_SCALE
    art.texture = texture
    art.custom_minimum_size = Vector2.ZERO
    art.size = size_value
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

func _property_sheet(hud: Node) -> Texture2D:
    match str(hud.call("_building_type")):
        "Workshop":
            return WORKSHOP_STAGES
        "Commercial Building":
            return COMMERCIAL_STAGES
        _:
            return WAREHOUSE_STAGES

func _stage_art(name_value: String, hud: Node, size_value: Vector2) -> TextureRect:
    var frame := AtlasTexture.new()
    frame.atlas = _property_sheet(hud)
    frame.region = Rect2(0, clampi(int(hud.call("_building_stage_slot")), 0, 5) * 144, 256, 144)
    var art := _art(name_value, frame, size_value)
    # KEEP_ASPECT_CENTERED can paint the atlas at native 256x144
    # outside its requested Control bounds. Scale the 16:9 stage frame into
    # its allocated card and explicitly clip it, preventing button overlaps.
    art.stretch_mode = TextureRect.STRETCH_SCALE
    art.clip_contents = true
    return art

func _sync_stage_art(content: Control, hud: Node, view: String) -> void:
    var art_name := "ActiveRestorationArt" if view == "live" else "PropertyVisual"
    var art := content.find_child(art_name, true, false) as TextureRect
    if art == null or not art.texture is AtlasTexture:
        return
    var frame := art.texture as AtlasTexture
    var next_sheet := _property_sheet(hud)
    if frame.atlas != next_sheet:
        frame.atlas = next_sheet
    var next_y := float(clampi(int(hud.call("_building_stage_slot")), 0, 5) * 144)
    if not is_equal_approx(frame.region.position.y, next_y):
        frame.region = Rect2(0, next_y, 256, 144)

func _enhance_home(hud: Node, content: Control) -> void:
    var hero := content.get_node_or_null("ExecutiveHero") as Control
    if hero == null or hero.get_node_or_null("ActiveRestorationArt") != null:
        return
    # Keep the established Figma card height, but dedicate its visual region
    # to the actual warehouse stage rather than a distant heritage building.
    _shift_content(content, 270.0, 70.0, hero)
    hero.size.y = 246.0
    hero.clip_contents = true

    var art_width := maxf(118.0, hero.size.x * 0.42)
    var art := _stage_art("ActiveRestorationArt", hud, Vector2(art_width, 84.0))
    art.position = Vector2(hero.size.x - art_width - 16.0, 96.0)
    hero.add_child(art)
    hero.move_child(art, 0)

    var eyebrow := hero.get_node_or_null("Eyebrow") as Label
    var title := hero.get_node_or_null("HeroTitle") as Label
    var goal := hero.get_node_or_null("HeroGoal") as Label
    var action := hero.get_node_or_null("PrimaryNextMove") as Button
    if eyebrow != null:
        eyebrow.text = "NEXT MOVE"
        eyebrow.position = Vector2(21, 16)
        eyebrow.size.x = hero.size.x - 42.0
    if title != null:
        # Do not replace this with a hardcoded property name: the core HUD
        # refreshes it from the real current objective as the player advances.
        title.position = Vector2(21, 43)
        title.size = Vector2(hero.size.x - 42.0, 51)
        title.add_theme_font_size_override("font_size", 18 if hero.size.x < 310 else 20)
    if goal != null:
        goal.position = Vector2(21, 103)
        # The old 34px maximum height constrains assignments to size.
        # Apply a larger maximum BEFORE setting the size. In Godot a zero
        # maximum collapses the control, rather than disabling its limit.
        var detail_size := Vector2(maxf(110.0, art.position.x - 31.0), 84.0)
        goal.custom_maximum_size = detail_size
        goal.custom_minimum_size = Vector2.ZERO
        goal.size = detail_size
        goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        goal.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
        goal.clip_text = true
        goal.add_theme_font_size_override("font_size", 10 if hero.size.x < 310.0 else 11)
    if action != null:
        action.text = "OPEN NEXT STEP"
        action.position = Vector2(21, 195)
        action.size = Vector2(hero.size.x - 42.0, 44)
        action.add_theme_font_size_override("font_size", 12)
    for child in hero.get_children():
        if child is Panel:
            if is_equal_approx(child.position.y, 112.0):
                child.position.y = 183.0
            elif child.size.x <= 8.0:
                child.size.y = hero.size.y

func _enhance_property(hud: Node, content: Control) -> void:
    var selected := content.get_node_or_null("SelectedProperty") as Control
    if selected == null or selected.get_node_or_null("PropertyVisual") != null:
        return
    _shift_content(content, 310.0, 112.0, selected)
    selected.size.y += 112.0
    for child in selected.get_children():
        if child is Control:
            child.position.y += 112.0
    var art_size := Vector2(minf(selected.size.x - 36.0, 199.0), 112.0)
    var art := _stage_art("PropertyVisual", hud, art_size)
    art.position = Vector2((selected.size.x - art_size.x) * 0.5, 0)
    selected.add_child(art)
    selected.move_child(art, 0)
    # Preserve the authoritative property name, type and valuation labels.

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
