extends CanvasLayer

## Player-facing cooperation and restoration network.
## Uses the authoritative Alliance V1 API; never edits finance/game cash directly.
const PLAYER_ID := "player"
const PARTNERS := [
    {"id":"apex_materials", "name":"Apex Materials", "role":"Materials & heavy supply"},
    {"id":"northstar_logistics", "name":"Northstar Logistics", "role":"Transport & distribution"},
    {"id":"greenbuild_industries", "name":"GreenBuild Industries", "role":"Sustainable construction"}
]
var panel: Panel
var status: Label
var project: Label
var partner_box: HBoxContainer
var alliance_system: Node
var partner_buttons: Array[Button] = []
var visible_width := 1280.0

func _ready() -> void:
    alliance_system = get_node_or_null("/root/RenewAllianceSystem")
    _build()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _build() -> void:
    panel = Panel.new()
    panel.name = "AllianceCouncil"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(panel)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("0f2026")
    style.border_color = Color("3d6c68")
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0, 0, 0, 0.35)
    style.shadow_size = 10
    panel.add_theme_stylebox_override("panel", style)

    var title := Label.new()
    title.text = "ALLIANCE COUNCIL  •  RESTORATION NETWORK"
    title.name = "Title"
    title.add_theme_font_size_override("font_size", 16)
    title.add_theme_color_override("font_color", Color("f0f6f3"))
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(title)

    status = Label.new()
    status.name = "Status"
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 11)
    status.add_theme_color_override("font_color", Color("b9ceca"))
    status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(status)

    project = Label.new()
    project.name = "Project"
    project.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    project.add_theme_font_size_override("font_size", 11)
    project.add_theme_color_override("font_color", Color("d5b56b"))
    project.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(project)

    _add_button("CREATE ALLIANCE", _create_alliance)
    _add_button("CONTRIBUTE $1,000", _contribute)
    _add_button("START RAILWAY", _project)
    _add_button("BUILD INFRA", _infra)
    _add_button("FUND RESEARCH", _research)

    var partners_title := Label.new()
    partners_title.text = "CORPORATE PARTNERS"
    partners_title.add_theme_font_size_override("font_size", 10)
    partners_title.add_theme_color_override("font_color", Color("829a9c"))
    partners_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(partners_title)

    partner_box = HBoxContainer.new()
    partner_box.add_theme_constant_override("separation", 7)
    partner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(partner_box)
    for partner in PARTNERS:
        var card := VBoxContainer.new()
        card.custom_minimum_size = Vector2(180, 64)
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var name := Label.new()
        name.text = partner["name"]
        name.add_theme_font_size_override("font_size", 10)
        name.add_theme_color_override("font_color", Color("e2eeeb"))
        name.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(name)
        var role := Label.new()
        role.text = partner["role"]
        role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        role.add_theme_font_size_override("font_size", 8)
        role.add_theme_color_override("font_color", Color("80989b"))
        role.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(role)
        var invite := Button.new()
        invite.text = "INVITE"
        invite.custom_minimum_size = Vector2(84, 28)
        invite.focus_mode = Control.FOCUS_NONE
        invite.mouse_filter = Control.MOUSE_FILTER_STOP
        invite.pressed.connect(_invite_partner.bind(partner["id"], partner["name"]))
        card.add_child(invite)
        partner_box.add_child(card)
        partner_buttons.append(invite)

func _add_button(text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.custom_minimum_size = Vector2(132, 34)
    button.pressed.connect(callback)
    panel.add_child(button)

func _layout() -> void:
    visible_width = get_viewport().get_visible_rect().size.x
    var narrow := visible_width < 760.0
    if narrow:
        panel.position = Vector2(8, 80)
        panel.size = Vector2(maxf(304.0, visible_width - 16.0), 430)
    else:
        panel.position = Vector2(maxf(18.0, visible_width - 610.0), 92)
        panel.size = Vector2(590, 430)
    var title := panel.get_node_or_null("Title") as Label
    if title != null: title.position = Vector2(14, 12); title.size = Vector2(panel.size.x - 28, 24)
    if status != null: status.position = Vector2(14, 43); status.size = Vector2(panel.size.x - 28, 64)
    if project != null: project.position = Vector2(14, 106); project.size = Vector2(panel.size.x - 28, 54)
    var children := panel.get_children()
    var buttons: Array[Button] = []
    for child in children:
        if child is Button: buttons.append(child)
    var y := 166.0
    var cols := 3 if not narrow else 2
    for i in range(buttons.size()):
        var col := i % cols
        var row := i / cols
        var bw := (panel.size.x - 42.0) / float(cols)
        buttons[i].position = Vector2(14 + col * (bw + 7), y + row * 40)
        buttons[i].size = Vector2(bw, 34)
    var partners_title := panel.get_child(panel.get_child_count() - 2) as Label
    if partners_title != null: partners_title.position = Vector2(14, 248 if not narrow else 248); partners_title.size = Vector2(panel.size.x - 28, 18)
    if partner_box != null:
        partner_box.position = Vector2(14, 272)
        partner_box.size = Vector2(panel.size.x - 28, 80)
        for card in partner_box.get_children():
            card.custom_minimum_size = Vector2(maxf(90.0, (panel.size.x - 42.0) / 3.0), 74)

func _game() -> Node:
    return get_tree().current_scene
func _finance() -> Node:
    return get_node_or_null("/root/RenewFinanceSystem")
func _player_alliance() -> Dictionary:
    return alliance_system.get_member_alliance(PLAYER_ID) if alliance_system != null and alliance_system.has_method("get_member_alliance") else {}
func _message(text: String) -> void:
    var game := _game()
    if game != null: game.message = text
    _refresh()

func _create_alliance() -> void:
    if alliance_system == null: return
    var existing := _player_alliance()
    if not existing.is_empty():
        _message("You already lead %s." % str(existing.get("name", "an alliance")))
        return
    var result: Dictionary = alliance_system.create_alliance("RENEW Restoration Consortium", PLAYER_ID)
    _message(String(result.get("message", "Alliance creation failed.")))

func _contribute() -> void:
    if alliance_system == null: return
    var result: Dictionary = alliance_system.donate_money(PLAYER_ID, 1000)
    _message(String(result.get("message", "Contribution could not be completed.")))

func _project() -> void:
    if alliance_system == null: return
    var result: Dictionary = alliance_system.start_cooperative_project(PLAYER_ID, "Regional Railway Project")
    _message(String(result.get("message", "Project could not be started.")))

func _infra() -> void:
    var alliance := _player_alliance()
    if alliance.is_empty(): _message("Create an alliance before building shared infrastructure."); return
    var game := _game()
    if game != null and game.has_method("buy_expansion"): _message("Shared infrastructure is being coordinated through the alliance network. Use the regional Infrastructure action to commit the physical asset.")

func _research() -> void:
    var alliance := _player_alliance()
    if alliance.is_empty(): _message("Create an alliance before funding shared research."); return
    _message("Shared research is queued for the alliance network. The technology council will unlock the next cooperative upgrade.")

func _invite_partner(partner_id: String, partner_name: String) -> void:
    if alliance_system == null: return
    var alliance := _player_alliance()
    if alliance.is_empty(): _message("Create the Restoration Consortium before inviting corporate partners."); return
    var result: Dictionary = alliance_system.invite_member(str(alliance.get("id", "")), PLAYER_ID, partner_id)
    if bool(result.get("ok", false)):
        _message("Invitation sent to %s. Build trust and bring them into the restoration network." % partner_name)
    else:
        _message(String(result.get("message", "Partner invitation failed.")))

func _refresh() -> void:
    if status == null: return
    var alliance := _player_alliance()
    if alliance.is_empty():
        status.text = "No restoration consortium founded yet. Unite specialist corporations to share materials, logistics, research and infrastructure."
        project.text = "NEXT: CREATE ALLIANCE  →  INVITE PARTNERS  →  START REGIONAL RAILWAY"
        return
    status.text = "%s\nMembers %d/%d  •  Treasury $%d  •  Trust %.0f  •  Reputation %.0f" % [str(alliance.get("name", "Alliance")), alliance.get("members", {}).size(), 6, int(alliance.get("treasury", 0)), float(alliance.get("trust", 0)), float(alliance.get("reputation", 0))]
    var projects: Array = alliance.get("projects", [])
    if projects.is_empty():
        project.text = "REGIONAL RAILWAY: not started  •  Build a shared logistics backbone for the restoration economy."
    else:
        var active: Dictionary = projects.back()
        var contributed: Dictionary = active.get("contributed", {})
        var req: Dictionary = active.get("requirements", {})
        project.text = "REGIONAL RAILWAY: %s  •  $%d/$%d  •  steel %d/%d  •  timber %d/%d  •  points %d/%d" % [str(active.get("status", "active")).to_upper(), int(contributed.get("money", 0)), int(req.get("money", 0)), int(contributed.get("steel", 0)), int(req.get("steel", 0)), int(contributed.get("timber", 0)), int(req.get("timber", 0)), int(contributed.get("project_points", 0)), int(req.get("project_points", 0))]
