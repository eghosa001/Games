extends CanvasLayer

## Lightweight playable UI for the persistent AllianceSystem.
const PLAYER_ID := "player"
var panel: Panel
var status: Label
var alliance_system: Node

func _ready() -> void:
    alliance_system = get_node_or_null("/root/RenewAllianceSystem")
    _build()
    _refresh()

func _build() -> void:
    panel = Panel.new()
    panel.name = "AlliancePanel"
    panel.position = Vector2(810, 430)
    panel.size = Vector2(450, 250)
    add_child(panel)
    var title: Variant = Label.new()
    title.text = "ALLIANCE COUNCIL"
    title.position = Vector2(16, 10); title.size = Vector2(400, 28)
    title.add_theme_font_size_override("font_size", 18); panel.add_child(title)
    status = Label.new()
    status.position = Vector2(16, 42); status.size = Vector2(418, 78)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; panel.add_child(status)
    _button("CREATE ALLIANCE", Vector2(16, 128), _create_alliance)
    _button("CONTRIBUTE $1,000", Vector2(150, 128), _contribute)
    _button("START PROJECT", Vector2(300, 128), _project)
    _button("BUILD INFRA", Vector2(16, 182), _infra)
    _button("FUND RESEARCH", Vector2(150, 182), _research)
    _button("PROMOTE DIRECTOR", Vector2(300, 182), _director)

func _button(text: String, pos: Vector2, callback: Callable) -> void:
    var button: Variant = Button.new(); button.text = text; button.position = pos; button.size = Vector2(132, 42)
    button.pressed.connect(callback); panel.add_child(button)

func _create_alliance() -> void:
    if alliance_system == null: return
    var existing: Variant = alliance_system.get_member_alliance(PLAYER_ID)
    if not existing.is_empty(): return
    var game: Variant = get_tree().current_scene
    var finance: Variant = get_node_or_null("/root/RenewFinanceSystem")
    if game == null or finance == null or not finance.has_method("can_afford") or not finance.can_afford(5000):
        if game != null: game.message = "Insufficient cash to establish the alliance."
        return

    # Finance is the only authority allowed to debit player cash. The alliance
    # is created unfunded, then receives the already-authorized founding payment.
    var result: Variant = alliance_system.create_alliance(PLAYER_ID, "RENEW Strategic Alliance", 0)
    if bool(result.get("ok", false)):
        var payment: Variant = finance.spend(5000, "alliance founding contribution")
        if bool(payment.get("ok", false)):
            var contribution: Variant = alliance_system.contribute(PLAYER_ID, 5000)
            if bool(contribution.get("ok", false)):
                game.cash = int(finance.cash)
                game.message = "RENEW Strategic Alliance created. You are Chairman."
            else:
                game.cash = int(finance.cash)
                game.message = "Alliance funding failed after the cash transaction."
        else:
            game.message = String(payment.get("message", "Alliance funding failed."))
    else:
        game.message = String(result.get("message", "Alliance creation failed."))
    _refresh()

func _contribute() -> void:
    if alliance_system == null: return
    var game: Variant = get_tree().current_scene
    var finance: Variant = get_node_or_null("/root/RenewFinanceSystem")
    if game == null or finance == null or not finance.has_method("can_afford") or not finance.can_afford(1000):
        if game != null: game.message = "Insufficient cash for this contribution."
        return

    # Debit first from the canonical ledger. Only after a successful debit do
    # we mutate the alliance treasury, eliminating the old dual-ledger ordering.
    var payment: Variant = finance.spend(1000, "alliance contribution")
    if not bool(payment.get("ok", false)):
        game.message = String(payment.get("message", "Contribution could not be funded."))
        _refresh()
        return
    var result: Variant = alliance_system.contribute(PLAYER_ID, 1000)
    if bool(result.get("ok", false)):
        game.cash = int(finance.cash)
        game.message = String(result.get("message", "Contribution made."))
    else:
        game.cash = int(finance.cash)
        game.message = "Contribution was debited but could not be posted to the alliance ledger."
    _refresh()

func _project() -> void:
    var alliance: Variant = _player_alliance()
    if alliance.is_empty(): return
    var result: Variant = alliance_system.add_project(alliance["id"], "Joint Market Network", "commercial", 2500)
    _message(result)

func _infra() -> void:
    var alliance: Variant = _player_alliance()
    if alliance.is_empty(): return
    var result: Variant = alliance_system.add_infrastructure(alliance["id"], "Alliance Logistics Hub", 1, 2000)
    _message(result)

func _research() -> void:
    var alliance: Variant = _player_alliance()
    if alliance.is_empty(): return
    var result: Variant = alliance_system.fund_research(alliance["id"], "Shared Production Research", 1500)
    _message(result)

func _director() -> void:
    var alliance: Variant = _player_alliance()
    if alliance.is_empty(): return
    var members: Dictionary = alliance.get("members", {})
    for member in members.keys():
        if str(member) != PLAYER_ID:
            _message(alliance_system.promote_to_director(alliance["id"], str(member), PLAYER_ID)); return
    _message({"message": "No other member is available for Director appointment."})

func _message(result: Dictionary) -> void:
    var game: Variant = get_tree().current_scene
    if game != null: game.message = String(result.get("message", "Alliance action completed."))
    _refresh()

func _player_alliance() -> Dictionary:
    return alliance_system.get_member_alliance(PLAYER_ID) if alliance_system != null else {}

func _refresh() -> void:
    if status == null: return
    var alliance: Variant = _player_alliance()
    if alliance.is_empty():
        status.text = "No alliance founded. Create one to establish a persistent organization."
        return
    status.text = "%s\nMembers: %d | Treasury: $%d\nREP: %.0f | Trust: %.0f | Assets: %d | Projects: %d\nGovernance: Chairman + Directors + member voting" % [alliance["name"], alliance["members"].size(), int(alliance["treasury"]), float(alliance["reputation"]), float(alliance["trust"]), alliance["assets"].size(), alliance["projects"].size()]
