extends CanvasLayer

## Responsive cooperation and restoration network presentation.
## Financial/alliance mutations are delegated to the authoritative Alliance V1 API.
const PLAYER_ID := "player"
const FOUNDING_NAME := "RENEW Restoration Consortium"
const FOUNDING_AMOUNT := 1000
const PARTNERS := [{"id":"apex_materials","name":"Apex Materials","role":"Materials & heavy supply"},{"id":"northstar_logistics","name":"Northstar Logistics","role":"Transport & distribution"},{"id":"greenbuild_industries","name":"GreenBuild Industries","role":"Sustainable construction"}]
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
    alliance_system = get_node_or_null("/root/RenewAllianceSystem")
    finance = get_node_or_null("/root/RenewFinanceSystem")
    _build(); _layout(); _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s
func _build() -> void:
    panel = Panel.new(); panel.name = "AllianceCouncil"; panel.mouse_filter = Control.MOUSE_FILTER_STOP; panel.add_theme_stylebox_override("panel", _style(Color("0d2028"), Color("3d6c68"), 14)); add_child(panel)
    title = Label.new(); title.text = "ALLIANCE COUNCIL  •  RESTORATION NETWORK"; title.add_theme_font_size_override("font_size", 18); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(title)
    close_button = Button.new(); close_button.text = "CLOSE"; close_button.custom_minimum_size = Vector2(80,46); close_button.focus_mode = Control.FOCUS_NONE; close_button.pressed.connect(_close); panel.add_child(close_button)
    status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.add_theme_font_size_override("font_size", 11); panel.add_child(status)
    project = Label.new(); project.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; project.add_theme_font_size_override("font_size", 11); project.add_theme_color_override("font_color", Color("d5b56b")); panel.add_child(project)
    _add_button("CREATE ALLIANCE  •  $1,000", _create_alliance); _add_button("CONTRIBUTE $1,000", _contribute); _add_button("START RAILWAY", _project); _add_button("BUILD INFRA  •  $5,000", _infra); _add_button("FUND RESEARCH  •  $5,000", _research)
    var partners_title := Label.new(); partners_title.name = "PartnersTitle"; partners_title.text = "CORPORATE PARTNERS"; partners_title.add_theme_font_size_override("font_size", 10); partners_title.add_theme_color_override("font_color", Color("829a9c")); panel.add_child(partners_title)
    partner_scroll = ScrollContainer.new(); partner_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; partner_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(partner_scroll)
    partner_box = HBoxContainer.new(); partner_box.add_theme_constant_override("separation", 8); partner_scroll.add_child(partner_box)
    for partner in PARTNERS:
        var card := VBoxContainer.new(); card.custom_minimum_size = Vector2(178, 82); partner_box.add_child(card)
        var name := Label.new(); name.text = partner["name"]; name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; name.add_theme_font_size_override("font_size", 10); card.add_child(name)
        var role := Label.new(); role.text = partner["role"]; role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; role.add_theme_font_size_override("font_size", 8); role.add_theme_color_override("font_color", Color("80989b")); card.add_child(role)
        var invite := Button.new(); invite.text = "INVITE"; invite.custom_minimum_size = Vector2(0,44); invite.focus_mode = Control.FOCUS_NONE; invite.pressed.connect(_invite_partner.bind(partner["id"], partner["name"])); card.add_child(invite)
func _add_button(text: String, callback: Callable) -> void:
    var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_NONE; b.custom_minimum_size = Vector2(0,44); b.pressed.connect(callback); panel.add_child(b)
func _game() -> Node: return get_tree().current_scene
func _player_alliance() -> Dictionary: return alliance_system.get_member_alliance(PLAYER_ID) if alliance_system != null and alliance_system.has_method("get_member_alliance") else {}
func _message(text: String) -> void:
    var game := _game(); if game != null: game.message = text
    _refresh()
func _create_alliance() -> void:
    if alliance_system == null: _message("Alliance system is unavailable."); return
    var existing := _player_alliance()
    if not existing.is_empty(): _message("You already lead %s." % str(existing.get("name", "an alliance"))); return
    if not alliance_system.has_method("create_alliance_with_finance"):
        _message("Alliance funding transaction is unavailable."); return
    var result: Dictionary = alliance_system.create_alliance_with_finance(finance, PLAYER_ID, FOUNDING_NAME, FOUNDING_AMOUNT)
    _message(str(result.get("message", "Alliance creation failed.")))
func _contribute() -> void:
    if alliance_system == null: _message("Alliance system is unavailable."); return
    if not alliance_system.has_method("contribute_from_finance"):
        _message("Alliance contribution transaction is unavailable."); return
    _message(str(alliance_system.contribute_from_finance(finance, PLAYER_ID, 1000).get("message", "Contribution could not be completed.")))
func _project() -> void:
    if alliance_system != null and alliance_system.has_method("start_cooperative_project"):
        _message(String(alliance_system.start_cooperative_project(PLAYER_ID, "Regional Railway Project").get("message", "Project could not be started.")))
    else: _message("Cooperative project system is unavailable.")
func _infra() -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty(): _message("Create an alliance before building shared infrastructure."); return
    if not alliance_system.has_method("add_infrastructure"): _message("Alliance infrastructure system is unavailable."); return
    var result: Dictionary = alliance_system.add_infrastructure(str(alliance.get("id", "")), "Regional Logistics Hub", 1, 5000)
    _message(str(result.get("message", "Infrastructure could not be established.")))
func _research() -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty(): _message("Create an alliance before funding shared research."); return
    if not alliance_system.has_method("fund_research"): _message("Alliance research system is unavailable."); return
    var result: Dictionary = alliance_system.fund_research(str(alliance.get("id", "")), "Cooperative Restoration Technology", 5000)
    _message(str(result.get("message", "Research could not be funded.")))
func _invite_partner(partner_id: String, partner_name: String) -> void:
    var alliance := _player_alliance()
    if alliance_system == null or alliance.is_empty(): _message("Create the Restoration Consortium before inviting corporate partners."); return
    var result: Dictionary = alliance_system.invite_member(str(alliance.get("id", "")), PLAYER_ID, partner_id) if alliance_system.has_method("invite_member") else {"ok": false, "message": "Partner invitations are unavailable."}
    _message("Invitation sent to %s." % partner_name if bool(result.get("ok", false)) else str(result.get("message", "Partner invitation failed.")))
func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager"); if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
func _refresh() -> void:
    if status == null: return
    var alliance := _player_alliance()
    if alliance.is_empty():
        status.text = "NO ACTIVE ALLIANCE\nFounding contribution  $1,000  •  Invite specialist corporations to share materials, logistics, research and infrastructure."
        project.text = "NEXT  CREATE ALLIANCE  →  INVITE PARTNERS  →  START REGIONAL RAILWAY"
        return
    status.text = "%s\nMembers %d/6  •  Treasury $%d  •  Trust %.0f  •  Reputation %.0f" % [str(alliance.get("name", "Alliance")), alliance.get("members", {}).size(), int(alliance.get("treasury", 0)), float(alliance.get("trust", 0)), float(alliance.get("reputation", 0))]
    var projects: Array = alliance.get("projects", [])
    if projects.is_empty(): project.text = "REGIONAL RAILWAY  •  Not started  •  Build a shared logistics backbone for the restoration economy."
    else:
        var active: Dictionary = projects.back(); var contributed: Dictionary = active.get("contributed", {}); var req: Dictionary = active.get("requirements", {})
        project.text = "REGIONAL RAILWAY  •  %s  •  $%d/$%d  •  steel %d/%d  •  timber %d/%d  •  points %d/%d" % [str(active.get("status", "active")).to_upper(), int(contributed.get("money", 0)), int(req.get("money", 0)), int(contributed.get("steel", 0)), int(req.get("steel", 0)), int(contributed.get("timber", 0)), int(req.get("timber", 0)), int(contributed.get("project_points", 0)), int(req.get("project_points", 0))]
func _layout() -> void:
    if panel == null: return
    visible_width = get_viewport().get_visible_rect().size.x; var size := get_viewport().get_visible_rect().size; var narrow := visible_width < 760.0; var width := maxf(304.0, visible_width - 16.0) if narrow else 590.0; var height := maxf(440.0, size.y - 78.0) if narrow else minf(500.0, size.y - 120.0)
    panel.position = Vector2(8,70) if narrow else Vector2(maxf(18.0, visible_width - width - 18.0), 92); panel.size = Vector2(width,height)
    title.position = Vector2(14,10); title.size = Vector2(width - 108,42); close_button.position = Vector2(width - 88,7); close_button.size = Vector2(80,46)
    status.position = Vector2(14,54); status.size = Vector2(width - 28,70); project.position = Vector2(14,126); project.size = Vector2(width - 28,56)
    var buttons: Array[Button] = []
    for child in panel.get_children():
        if child is Button and child != close_button: buttons.append(child)
    var y := 188.0; var cols := 2 if narrow else 3; var bw := (width - 42.0) / float(cols)
    for i in range(buttons.size()): buttons[i].position = Vector2(14 + (i % cols) * (bw + 7), y + (i / cols) * 50); buttons[i].size = Vector2(bw,44)
    var partners_title := panel.get_node_or_null("PartnersTitle") as Label; var partner_y := y + ceil(float(buttons.size()) / float(cols)) * 50 + 6
    if partners_title != null: partners_title.position = Vector2(14,partner_y); partners_title.size = Vector2(width - 28,18)
    partner_scroll.position = Vector2(14,partner_y + 22); partner_scroll.size = Vector2(width - 28,86); partner_box.custom_minimum_size = Vector2(maxf(width - 28,560.0),82)
