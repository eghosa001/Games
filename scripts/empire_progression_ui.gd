extends CanvasLayer

## Executive progression surface. Reads existing EmpireGoals/Progression state only.
const BG := Color("08171eF5")
const CARD := Color("102831")
const BORDER := Color("31545c")
const SOFT := Color("24434b")
const TEXT := Color("edf6f3")
const MUTED := Color("89a3a7")
const ACCENT := Color("d8b76d")
const GOOD := Color("8ee6a8")

var game: Node
var panel: Panel
var scroll: ScrollContainer
var content: VBoxContainer
var title_label: Label
var summary_label: Label
var status_label: Label
var open := false
var refresh_clock := 0.0
var last_signature := ""
var applied_refreshes := 0

func _ready() -> void:
    layer = 74
    game = get_tree().root.get_node_or_null("Renew")
    _build()
    _layout()
    close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func open_screen() -> void:
    open = true
    panel.visible = true
    _refresh(true)
func close_screen() -> void:
    open = false
    if panel != null: panel.visible = false
func toggle() -> void:
    if open: close_screen()
    else: open_screen()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and open:
        close_screen()
        get_viewport().set_input_as_handled()

func _style(bg: Color, border: Color = BORDER, radius := 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 10; s.content_margin_bottom = 10
    return s

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l

func _build() -> void:
    panel = Panel.new(); panel.name = "EmpireProgressionSurface"; panel.add_theme_stylebox_override("panel", _style(BG)); add_child(panel)
    var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 16); margin.add_theme_constant_override("margin_right", 16); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14); panel.add_child(margin)
    var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 9); margin.add_child(root)
    var header := HBoxContainer.new(); root.add_child(header)
    var head_box := VBoxContainer.new(); head_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(head_box)
    title_label = _label("EMPIRE PROGRESSION", 21, TEXT); head_box.add_child(title_label)
    summary_label = _label("STRATEGIC CAMPAIGN", 10, MUTED); head_box.add_child(summary_label)
    var close := Button.new(); close.text = "CLOSE"; close.custom_minimum_size = Vector2(84, 46); close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(close_screen); header.add_child(close)
    status_label = _label("", 11, ACCENT); root.add_child(status_label)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation", 10); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(820.0, size.x - 40.0)
    var height := maxf(410.0, size.y - 82.0) if narrow else minf(700.0, size.y - 90.0)
    panel.position = Vector2(8, 66) if narrow else Vector2((size.x - width) * 0.5, 54)
    panel.size = Vector2(width, height)

func _goals() -> Node:
    return game.get_node_or_null("Systems/EmpireGoals") if game != null else null
func _progression() -> Node:
    return game.get_node_or_null("Systems/Progression") if game != null else null
func _strategic_progression() -> Node:
    return game.get_node_or_null("Systems/StrategicProgression") if game != null else null
func _victory() -> Node:
    return get_node_or_null("/root/RenewVictorySystem")
func _regions() -> Node:
    return game.get_node_or_null("World/RegionController") if game != null else null

func _owned_assets() -> int:
    if game == null or game.expansion == null: return 0
    var count := 0
    for item in game.expansion.properties:
        if bool(item.get("owned", false)): count += 1
    for item in game.expansion.resource_sites:
        if bool(item.get("owned", false)): count += 1
    return count

func _rank(rep: int) -> String:
    if rep >= 40: return "INDUSTRIAL TITAN"
    if rep >= 25: return "REGIONAL POWER"
    if rep >= 15: return "RISING HOUSE"
    if rep >= 8: return "ESTABLISHED FIRM"
    if rep >= 3: return "EMERGING COMPANY"
    return "NEW OPERATOR"

func _card(title: String, body: String, accent := ACCENT) -> void:
    var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(CARD, SOFT, 12)); content.add_child(card)
    var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5); card.add_child(box)
    var h := Label.new(); h.text = title.to_upper(); h.add_theme_font_size_override("font_size", 11); h.add_theme_color_override("font_color", accent); box.add_child(h)
    var b := Label.new(); b.text = body; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.add_theme_font_size_override("font_size", 13); b.add_theme_color_override("font_color", TEXT); box.add_child(b)

func _refresh(force := false) -> void:
    if game == null: game = get_tree().root.get_node_or_null("Renew")
    if game == null: return
    var goals := _goals(); var progression := _progression()
    var strategic := _strategic_progression()
    var victory := _victory()
    var company_level := int(strategic.get_level()) if strategic != null and strategic.has_method("get_level") else 1
    var rep := int(game.reputation); var assets := _owned_assets()
    var goal_done: int = int(goals.completed_count()) if goals != null and goals.has_method("completed_count") else 0
    var goal_total: int = int(goals.goals.size()) if goals != null else 0
    var milestone_done: int = int(progression.claimed.size()) if progression != null else 0
    var milestone_total: int = int(progression.milestones.size()) if progression != null else 0
    var region_count := 1
    var region := _regions()
    if region != null and region.regions != null: region_count = max(1, int(region.regions.player_presence.count(1)))

    var current_goal: Dictionary = goals.current_goal() if goals != null and goals.has_method("current_goal") else {}
    var goal_claim_parts: Array[String] = []
    if goals != null:
        for goal in goals.goals:
            var goal_id := str(goal.get("id", ""))
            goal_claim_parts.append("%s=%s" % [goal_id, str(bool(goals.claimed.get(goal_id, false)))])
    var msg := str(game.message)
    var xp := int(strategic.get_xp()) if strategic != null and strategic.has_method("get_xp") else 0
    var next_xp := int(strategic.get_next_level_xp()) if strategic != null and strategic.has_method("get_next_level_xp") else -1
    var victory_signature := ""
    var prestige_signature := ""
    if victory != null:
        if victory.has_method("progress_text"):
            victory_signature = str(victory.progress_text())
        if victory.has_method("prestige_wins") and victory.has_method("prestige_bonuses"):
            var signature_bonuses: Dictionary = victory.prestige_bonuses()
            prestige_signature = "%d|%d|%d|%d" % [
                int(victory.prestige_wins()),
                int(signature_bonuses.get("starting_cash", 0)),
                int(signature_bonuses.get("starting_reputation", 0)),
                int(signature_bonuses.get("starting_research", 0))
            ]
    var signature := "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s" % [
        rep, assets, goal_done, goal_total, milestone_done, milestone_total, region_count,
        int(game.total_profit), int(game.day), company_level,
        str(xp) + ":" + str(next_xp),
        ",".join(goal_claim_parts),
        str(current_goal.get("id", "")) + "|" + str(current_goal.get("title", "")) + "|" + str(current_goal.get("text", "")),
        msg,
        victory_signature + "|" + prestige_signature
    ]
    if not force and signature == last_signature: return
    last_signature = signature
    applied_refreshes += 1
    status_label.text = "LEVEL %d  •  %s  •  REP %d  •  %d ASSETS  •  %d REGION%s" % [company_level, _rank(rep), rep, assets, region_count, "" if region_count == 1 else "S"]
    summary_label.text = "CAMPAIGN %d/%d GOALS  •  %d/%d MILESTONES" % [goal_done, goal_total, milestone_done, milestone_total]
    for child in content.get_children(): child.queue_free()
    _card("NEXT STRATEGIC OBJECTIVE", "%s\n%s" % [str(current_goal.get("title", "CAMPAIGN COMPLETE")), str(current_goal.get("text", "Every current company objective is complete."))], ACCENT)
    _card("EMPIRE POSITION", "%s\nReputation %d  •  Operating profit $%s\nAssets controlled %d  •  Regional footholds %d" % [_rank(rep), rep, String.num_int64(int(game.total_profit)), assets, region_count], GOOD)
    if goals != null:
        for goal in goals.goals:
            var id := str(goal.get("id", "")); var done := bool(goals.claimed.get(id, false)); var state := "COMPLETE" if done else "IN PROGRESS"
            var tint := GOOD if done else MUTED
            _card("%s  •  %s" % [state, str(goal.get("title", id))], str(goal.get("text", "")) + ("\nReward: +$%s and +%d reputation" % [String.num_int64(int(goal.get("cash", 0))), int(goal.get("rep", 0))]), tint)
    if progression != null:
        _card("MILESTONE TRACKER", "%d of %d milestones claimed.\nThese achievements mark the company's transformation from a single site into a connected economic empire." % [milestone_done, milestone_total], ACCENT)
    if msg != "": _card("LATEST EXECUTIVE NOTICE", msg, ACCENT)
    var victory_text := "Victory tracking is unavailable."
    var prestige_text := "No legacy bonuses banked yet."
    if victory != null:
        if victory.has_method("progress_text"):
            victory_text = str(victory.progress_text())
        if victory.has_method("prestige_wins") and victory.has_method("prestige_bonuses"):
            var wins := int(victory.prestige_wins())
            var bonuses: Dictionary = victory.prestige_bonuses()
            prestige_text = "%d campaign win%s banked  •  heir capital +$%s  •  reputation +%d  •  research +%d" % [
                wins, "" if wins == 1 else "s",
                String.num_int64(int(bonuses.get("starting_cash", 0))),
                int(bonuses.get("starting_reputation", 0)),
                int(bonuses.get("starting_research", 0))
            ]
    _card("VICTORY PATHS", victory_text, ACCENT)
    _card("PRESTIGE & LEGACY", prestige_text, GOOD if victory != null and victory.has_method("prestige_wins") and int(victory.prestige_wins()) > 0 else MUTED)
    if strategic != null and strategic.has_method("get_next_level_xp"):
        var progression_text := "Maximum company level reached. Endgame and prestige systems are fully unlocked." if next_xp < 0 else "Company Level %d  •  %d XP  •  next level at %d XP.\nAdvance through meaningful restoration, operations, contracts, expansion and profit." % [company_level, xp, next_xp]
        _card("COMPANY LEVEL", progression_text, GOOD if next_xp < 0 else ACCENT)

func _process(delta: float) -> void:
    if not open: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)
