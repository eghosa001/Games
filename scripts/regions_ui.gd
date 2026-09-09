extends CanvasLayer

## Responsive World & Regions command surface.
## Presentation only: all mutations are delegated to RegionController / RegionSystem.

var game: Node
var controller: Node
var catalog: Node
var scrim: ColorRect
var panel: Panel
var title_label: Label
var summary_label: Label
var region_scroll: ScrollContainer
var region_grid: GridContainer
var detail_label: Label
var action_grid: GridContainer
var feedback_label: Label
var close_button: Button
var selected_index := 0
var opened := false

const BG := Color("08171dF5")
const CARD := Color("10262d")
const CARD_ACTIVE := Color("18363a")
const BORDER := Color("31565d")
const TEXT := Color("edf6f3")
const MUTED := Color("91a9ad")
const ACCENT := Color("d8b76d")
const WARNING := Color("f0ad88")

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    controller = game.get_node_or_null("World/RegionController") if game != null else null
    catalog = get_tree().root.get_node_or_null("RenewRegionSystem")
    _build(); visible = false; _layout()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _build() -> void:
    scrim = ColorRect.new(); scrim.color = Color(0.01, 0.05, 0.07, 0.78); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(scrim)
    panel = Panel.new(); panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 18)); add_child(panel)
    title_label = _label("WORLD COMMAND", 18, TEXT); summary_label = _label("REGIONAL MARKETS", 9, MUTED); panel.add_child(title_label); panel.add_child(summary_label)
    close_button = _button("CLOSE", Callable(self, "_close"), 44); panel.add_child(close_button)
    region_scroll = ScrollContainer.new(); region_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; region_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(region_scroll)
    region_grid = GridContainer.new(); region_grid.columns = 2; region_grid.add_theme_constant_override("h_separation", 8); region_grid.add_theme_constant_override("v_separation", 8); region_scroll.add_child(region_grid)
    detail_label = _label("", 10, TEXT); detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(detail_label)
    action_grid = GridContainer.new(); action_grid.add_theme_constant_override("h_separation", 8); action_grid.add_theme_constant_override("v_separation", 8); panel.add_child(action_grid)
    _add_action("NEXT", Callable(self, "_next")); _add_action("PREVIOUS", Callable(self, "_previous")); _add_action("ESTABLISH", Callable(self, "_establish")); _add_action("INFRASTRUCTURE", Callable(self, "_infrastructure")); _add_action("SHIP", Callable(self, "_dispatch")); _add_action("TRADE ROUTE", Callable(self, "_trade"))
    feedback_label = _label("", 9, MUTED); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(feedback_label)

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; return label

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new(); style.bg_color = bg; style.border_color = border; style.set_border_width_all(1); style.set_corner_radius_all(radius); style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 9; style.content_margin_bottom = 9; return style

func _button(text: String, callback: Callable, min_height := 44) -> Button:
    var button := Button.new(); button.text = text; button.custom_minimum_size = Vector2(0, min_height); button.focus_mode = Control.FOCUS_NONE; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.pressed.connect(callback); button.add_theme_font_size_override("font_size", 10); button.add_theme_stylebox_override("normal", _style(Color("142c33"), BORDER, 9)); button.add_theme_stylebox_override("hover", _style(Color("1b3b40"), ACCENT, 9)); button.add_theme_stylebox_override("pressed", _style(Color("24464a"), ACCENT, 9)); button.add_theme_color_override("font_color", TEXT); button.tooltip_text = text.capitalize(); return button

func _add_action(text: String, callback: Callable) -> void: action_grid.add_child(_button(text, callback, 46))

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var w := maxf(size.x, 320.0); var h := maxf(size.y, 480.0); var narrow := w < 720.0; var phone := w < 430.0
    var margin := 8.0 if phone else (10.0 if narrow else 28.0); panel.position = Vector2(margin, margin + 8.0); panel.size = Vector2(w - margin * 2.0, h - margin * 2.0 - 8.0)
    title_label.position = Vector2(14, 10); title_label.size = Vector2(panel.size.x - 110, 28); summary_label.position = Vector2(14, 38); summary_label.size = Vector2(panel.size.x - 110, 18); close_button.position = Vector2(panel.size.x - 88, 10); close_button.size = Vector2(76, 44)
    region_scroll.position = Vector2(12, 62); region_scroll.size = Vector2(panel.size.x - 24, panel.size.y * (0.43 if narrow else 0.44)); region_grid.columns = 1 if narrow else 2
    detail_label.position = Vector2(14, region_scroll.position.y + region_scroll.size.y + 8); detail_label.size = Vector2(panel.size.x - 28, 86 if phone else (74 if narrow else 66))
    action_grid.position = Vector2(12, detail_label.position.y + detail_label.size.y + 6); action_grid.size = Vector2(panel.size.x - 24, 104 if phone else 54); action_grid.columns = 2 if narrow else 3
    for child in action_grid.get_children():
        if child is Button: child.custom_minimum_size = Vector2(0, 44 if phone else 46); child.add_theme_font_size_override("font_size", 9 if phone else 10)
    feedback_label.position = Vector2(14, action_grid.position.y + action_grid.size.y + 8); feedback_label.size = Vector2(panel.size.x - 28, maxf(40.0, panel.size.y - feedback_label.position.y - 10.0))

func open_screen() -> void:
    opened = true; visible = true
    if controller == null and game != null: controller = game.get_node_or_null("World/RegionController")
    if catalog == null: catalog = get_tree().root.get_node_or_null("RenewRegionSystem")
    _layout(); _refresh()

func close_screen() -> void: opened = false; visible = false

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: close_screen()

func _refresh() -> void:
    if controller == null: detail_label.text = "Regional command is unavailable."; return
    var regions = controller.regions; var list: Array = regions.regions
    if list.is_empty(): return
    selected_index = clampi(int(regions.selected), 0, list.size() - 1)
    for child in region_grid.get_children(): child.queue_free()
    for i in range(list.size()):
        var data: Dictionary = list[i]; var unlocked := bool(data.get("unlocked", false)); var owned := int(regions.player_presence[i]) > 0; var status := "LOCKED" if not unlocked else ("OPERATING" if owned else "AVAILABLE")
        var card := Button.new(); card.text = "%s\nTIER %d  •  %s\nMARKET %.2fx  •  RIVALS %d  •  INFRA %d" % [str(data.get("name", "Region")), int(data.get("tier", 1)), status, float(regions.market_levels[i]), int(regions.rival_presence[i]), int(regions.infrastructure[i])]; card.custom_minimum_size = Vector2(0, 72); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL; card.focus_mode = Control.FOCUS_NONE; card.disabled = not unlocked; card.pressed.connect(_select.bind(i)); card.add_theme_font_size_override("font_size", 10); card.add_theme_stylebox_override("normal", _style(CARD_ACTIVE if i == selected_index else CARD, ACCENT if i == selected_index else BORDER, 10)); card.add_theme_stylebox_override("hover", _style(Color("1b3b40"), ACCENT, 10)); card.add_theme_color_override("font_color", TEXT if unlocked else WARNING); region_grid.add_child(card)
    _update_detail(); _layout()

func _select(index: int) -> void:
    if controller == null: return
    var result = controller.regions.select(index, int(game.reputation)); feedback_label.text = str(result.get("message", "Region selection unavailable."))
    if bool(result.get("ok", false)):
        selected_index = index
        if game != null and game.has_method("_log"):
            game._log("REGION: " + feedback_label.text)
    _refresh()

func _update_detail() -> void:
    var r: Dictionary = controller.regions.current(); var unlocked := bool(r.get("unlocked", false)); var presence := int(r.get("player_presence", 0))
    detail_label.text = "%s  •  TIER %d  •  %s\nPopulation %s  |  Demand %.2fx  |  Market %.2fx  |  Wage %.2fx\nLogistics %.2fx  |  Competition %.2fx  |  Local REP %.0f  |  Presence %d\n%s" % [str(r.get("name", "Region")), int(r.get("tier", 1)), "UNLOCKED" if unlocked else "LOCKED", String.num_int64(int(r.get("population", 0))), float(r.get("demand", 1.0)), float(r.get("market_level", 1.0)), float(r.get("regional_wage", 1.0)), float(r.get("logistics", 1.0)), float(r.get("competition", 1.0)), float(r.get("local_reputation", 0.0)), presence, str(r.get("special", "Regional market"))]
    summary_label.text = "REGIONAL MARKETS  •  %d TERRITORIES  •  %d OPERATING" % [controller.regions.regions.size(), controller.regions.player_presence.count(1)]
    if not unlocked: feedback_label.text = "%s unlocks at %d reputation." % [str(r.get("name", "This region")), int(r.get("rep", 0))]

func _next() -> void:
    if controller != null: controller.next_region(); _refresh()
func _previous() -> void:
    if controller != null: controller.previous_region(); _refresh()
func _establish() -> void:
    if controller != null: controller.establish_region(); _feedback_from_controller(); _refresh()
func _infrastructure() -> void:
    if controller != null: controller.upgrade_infrastructure(); _feedback_from_controller(); _refresh()
func _dispatch() -> void:
    if controller != null: controller.dispatch_goods(); _feedback_from_controller(); _refresh()
func _trade() -> void:
    if controller != null: controller.establish_trade_route(); _feedback_from_controller(); _refresh()
func _feedback_from_controller() -> void:
    if controller != null: feedback_label.text = str(controller.message)
