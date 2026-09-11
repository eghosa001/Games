extends CanvasLayer

## Responsive cooperation and restoration network presentation.
## Keeps the council focused on high-level alliance decisions; detailed
## infrastructure/research actions belong in their dedicated systems.
const PLAYER_ID := "player"
const FOUNDING_NAME := "RENEW Restoration Consortium"
const FOUNDING_AMOUNT := 1000
const PARTNERS := [{"id":"apex_materials","name":"Apex Materials","role":"Materials & heavy supply"},{"id":"northstar_logistics","name":"Northstar Logistics","role":"Transport & distribution"},{"id":"greenbuild_industries","name":"GreenBuild Industries","role":"Sustainable construction"}]
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")

var dimmer: ColorRect
var panel: Panel
var status: Label
var project: Label
var partner_scroll: ScrollContainer
var partner_box: HBoxContainer
var title: Label
var close_button: Button
var alliance_system: Node
var finance: Node
var visible_width := 1280.0

func _ready() -> void:
    layer = 55
    alliance_system = get_node_or_null("/root/RenewAllianceSystem")
    finance = get_node_or_null("/root/RenewFinanceSystem")
    _build()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    return s

func _button_style(bg: Color = SURFACE_2, border: Color = BORDER) -> StyleBoxFlat:
    var s := _style(bg, border, 8)
    s.content_margin_left = 9
    s.content_margin_right = 9
    s.content_margin_top = 6
    s.content_margin_bottom = 6
    return s

func _style_button(b: Button, bg: Color = SURFACE_2, border: Color = BORDER) -> void:
    b.add_theme_stylebox_override("normal", _button_style(bg, border))
    b.add_theme_stylebox_override("hover", _button_style(Color("17343d"), ACCENT))
    b.add_theme_stylebox_override("pressed", _button_style(Color("1b454c"), ACCENT))
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_color_override("font_hover_color", Color.WHITE)
    b.add_theme_font_size_override("font_size", 9 if visible_width < 390.0 else 10)

func _build() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "AllianceScrim"
    dimmer.color = Color(0.015, 0.055, 0.07, 0.76)
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "AllianceCouncil"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, Color("3d6c68"), 14))
    add_child(panel)

    title = Label.new()
    title.text = "COOPERATION NETWORK"
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", TEXT)
    panel.add_child(title)

    var subtitle := Label.new()
    subtitle.name = "Subtitle"
    subtitle.text = "Alliance strategy  •  shared capital  •  corporate diplomacy"
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", MUTED)
    panel.add_child(subtitle)

    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(80, 46)
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(_close)
    _style_button(close_button)
    panel.add_child(close_button)

    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 11)
    status.add_theme_color_override("font_color", TEXT)
    panel.add_child(status)

    project = Label.new()
    project.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    project.add_theme_font_size_override("font_size", 10)
    project.add_theme_color_override("font_color", ACCENT)
    panel.add_child(project)

    _add_button("CREATE ALLIANCE  •  $1,000", _create_alliance)
    _add_button("CONTRIBUTE  •  $1,000", _contribute)
    _add_button("START RAILWAY", _project)
    _add_button("GOVERN  •  VOTE", _govern)
    _add_button("ENTER CHALLENGE", _challenge)

    var partners_title := Label.new()
    partners_title.name = "PartnersTitle"
    partners_title.text = "CORPORATE PARTNERS"
    partners_title.add_theme_font_size_override("font_size", 10)
    partners_title.add_theme_color_override("font_color", MUTED)
    panel.add_child(partners_title)

    partner_scroll = ScrollContainer.new()
    partner_scroll.name = "PartnerScroll"
    partner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    partner_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(partner_scroll)

    partner_box = HBoxContainer.new()
    partner_box.add_theme_constant_override("separation", 8)
    partner_scroll.add_child(partner_box)
    for partner in PARTNERS:
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(178, 82)
        card.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 8))
        partner_box.add_child(card)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 2)
        card.add_child(box)
        var name := Label.new()
        name.text = partner["name"]
        name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name.add_theme_font_size_override("font_size", 10)
        name.add_theme_color_override("font_color", TEXT)
        box.add_child(name)
        var role := Label.new()
        role.text = partner["role"]
        role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        role.add_theme_font_size_override("font_size", 8)
        role.add_theme_color_override("font_color", MUTED)
        box.add_child(role)
        var invite := Button.new()
        invite.text = "INVITE"
        invite.custom_minimum_size = Vector2(0, 44)
        invite.focus_mode = Control.FOCUS_NONE
        invite.pressed.connect(_invite_partner.bind(partner["id"], partner["name"]))
        _style_button(invite)
        box.add_child(invite)

func _add_button(text: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(0, 44)
    b.pressed.connect(callback)
    _style_button(b)
    panel.add_child(b)

func _game() -> Node:
    return get_tree().current_scene

func _player_alliance() -> Dictionary:
    return alliance_system.get_member_alliance(PLAYER_ID) if alliance_system != null and alliance_system.has_method("get_member_alliance") else {}

func _message(text: String) -> void:
    var game := _game()
    if game != null:
        game.message = text
    _refresh()

func _create_alliance() -> void:
    if alliance_system == null:
        _message("Alliance system is unavailable.")
        return
    var existing := _player_alliance()
    if not existing.is_empty():
        _message("You already lead %s." % str(existing.get("name", "an alliance")))
        return
    if not alliance_system.has_method("create_alliance_with_finance"):
        _message("Alliance funding transaction is unavailable.")
        return
    var result: Dictionary = alliance_system.create_alliance_with_finance(finance, PLAYER_ID, FOUNDING_NAME, FOUNDING_AMOUNT)
    _message(str(result.get("message", "Alliance creation failed.")))

func _contribute() -> void:
    if alliance_system == null or not alliance_system.has_method("contribute_from_finance"):
        _message("Alliance contribution transaction is unavailable.")
        return
    _message(str(alliance_system.contribute_from_finance(finance, PLAYER_ID, 1000).get("message", "Contribution could not be completed.")))

func _project() -> void:
    if alliance_system != null and alliance_system.has_method("start_cooperative_project"):
        _message(String(alliance_system.start_cooperative_project(PLAYER_ID, "Regional Railway Project").get("message", "Project could not be started.")))
    else:
        _message("Cooperative project system is unavailable.")

func _challenge() -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty():
        _message("Create an alliance before entering challenges.")
        return
    if not alliance_system.has_method("run_alliance_challenge"):
        _message("Alliance challenges are unavailable.")
        return
    _message(str(alliance_system.run_alliance_challenge(PLAYER_ID).get("message", "Challenge could not be run.")))

func _govern() -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty():
        _message("Create an alliance before governing it.")
        return
    if not alliance_system.has_method("open_motion") or not alliance_system.has_method("vote_motion"):
        _message("Alliance motions are unavailable.")
        return
    var open_index := -1
    var motions: Array = alliance.get("motions", [])
    for i in range(motions.size()):
        if motions[i] is Dictionary and str(motions[i].get("status", "")) == "open":
            open_index = i
    if open_index >= 0:
        _message(str(alliance_system.vote_motion(PLAYER_ID, open_index, true).get("message", "Vote could not be cast.")))
        return
    var target := ""
    var worst := 1000
    for member_id in alliance.get("members", {}).keys():
        if str(member_id) == PLAYER_ID:
            continue
        var trust := int(alliance.get("member_trust", {}).get(member_id, 50))
        if trust < worst:
            worst = trust
            target = str(member_id)
    if target.is_empty():
        _message("No member to bring a motion against.")
        return
    _message(str(alliance_system.open_motion(PLAYER_ID, "sanction", target).get("message", "Motion could not be opened.")))

func _invite_partner(partner_id: String, partner_name: String) -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty():
        _message("Create the Restoration Consortium before inviting corporate partners.")
        return
    var result: Dictionary = alliance_system.invite_member(str(alliance.get("id", "")), PLAYER_ID, partner_id) if alliance_system.has_method("invite_member") else {"ok": false, "message": "Partner invitations are unavailable."}
    _message("Invitation sent to %s." % partner_name if bool(result.get("ok", false)) else str(result.get("message", "Partner invitation failed.")))

func _members_line(alliance: Dictionary) -> String:
    var parts: Array[String] = []
    var trust: Dictionary = alliance.get("member_trust", {})
    for member_id in alliance.get("members", {}).keys():
        var role := str(alliance["members"][member_id].get("role", "member"))
        parts.append("%s(%s:%d)" % [str(member_id), role.left(1).to_upper(), int(trust.get(member_id, 50))])
        if parts.size() >= 4:
            break
    return "No members yet." if parts.is_empty() else "  •  ".join(parts)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        visible = false

func _refresh() -> void:
    if status == null:
        return
    var alliance := _player_alliance()
    if alliance.is_empty():
        status.text = "NO ACTIVE ALLIANCE\nFounding contribution  $1,000  •  Build a six-member restoration network."
        project.text = "NEXT  CREATE ALLIANCE  →  INVITE PARTNERS  →  START REGIONAL RAILWAY"
        return
    var members: Dictionary = alliance.get("members", {})
    status.text = "%s  •  LEVEL %d\nMEMBERS %d/6  •  TREASURY $%d  •  TRUST %.0f  •  REPUTATION %.0f\n%s" % [str(alliance.get("name", "Alliance")), int(alliance.get("level", 1)), members.size(), int(alliance.get("treasury", 0)), float(alliance.get("trust", 0)), float(alliance.get("reputation", 0)), _members_line(alliance)]
    var projects: Array = alliance.get("projects", [])
    if projects.is_empty():
        project.text = "REGIONAL RAILWAY  •  NOT STARTED  •  Shared logistics backbone for the restoration economy."
    else:
        var active: Dictionary = projects.back()
        var contributed: Dictionary = active.get("contributed", {})
        var req: Dictionary = active.get("requirements", {})
        project.text = "REGIONAL RAILWAY  •  %s  •  $%d/$%d  •  STEEL %d/%d  •  TIMBER %d/%d  •  POINTS %d/%d" % [str(active.get("status", "active")).to_upper(), int(contributed.get("money", 0)), int(req.get("money", 0)), int(contributed.get("steel", 0)), int(req.get("steel", 0)), int(contributed.get("timber", 0)), int(req.get("timber", 0)), int(contributed.get("project_points", 0)), int(req.get("project_points", 0))]

func _layout() -> void:
    if panel == null:
        return
    var size := get_viewport().get_visible_rect().size
    visible_width = size.x
    var narrow := visible_width < 760.0
    var phone := visible_width < 390.0
    var width := maxf(304.0, visible_width - 16.0) if narrow else minf(590.0, visible_width - 36.0)
    var height := maxf(470.0, size.y - 78.0) if narrow else minf(500.0, size.y - 100.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, (visible_width - width) * 0.5), 82)
    panel.size = Vector2(width, height)
    title.position = Vector2(14, 10)
    title.size = Vector2(width - 108, 30)
    title.add_theme_font_size_override("font_size", 18 if phone else 20)
    var subtitle := panel.get_node_or_null("Subtitle") as Label
    if subtitle != null:
        subtitle.position = Vector2(14, 38)
        subtitle.size = Vector2(width - 28, 20)
    close_button.position = Vector2(width - 88, 7)
    close_button.size = Vector2(80, 46)
    status.position = Vector2(14, 62)
    status.size = Vector2(width - 28, 78)
    project.position = Vector2(14, 142)
    project.size = Vector2(width - 28, 48)
    var buttons: Array[Button] = []
    for child in panel.get_children():
        if child is Button and child != close_button:
            buttons.append(child)
    var y := 194.0
    var cols := 2 if narrow else 3
    var bw := (width - 42.0) / float(cols)
    for i in range(buttons.size()):
        buttons[i].position = Vector2(14 + (i % cols) * (bw + 7), y + floori(i / cols) * 50)
        buttons[i].custom_minimum_size = Vector2(0, 44)
        buttons[i].clip_text = true
        buttons[i].size = Vector2(bw, 44)
        buttons[i].add_theme_font_size_override("font_size", 9 if phone else 10)
    var partners_title := panel.get_node_or_null("PartnersTitle") as Label
    var partner_y: float = y + ceil(float(buttons.size()) / float(cols)) * 50 + 4
    if partners_title != null:
        partners_title.position = Vector2(14, partner_y)
        partners_title.size = Vector2(width - 28, 18)
    partner_scroll.position = Vector2(14, partner_y + 22)
    partner_scroll.size = Vector2(width - 28, 90)
    partner_box.custom_minimum_size = Vector2(maxf(width - 28, 560.0), 82)
    for child in partner_box.get_children():
        if child is PanelContainer:
            child.custom_minimum_size = Vector2(178, 82)
