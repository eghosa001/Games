extends Node2D

# Direct management layer for the three expansion businesses.
# It deliberately lives beside main.gd so the original restoration loop remains stable.

var selected := 0
var parent: Node

func _ready() -> void:
    parent = get_parent()
    queue_redraw()

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_7: select_business(0)
        KEY_8: select_business(1)
        KEY_9: select_business(2)
        KEY_Z: produce_selected()
        KEY_Y: sell_selected()
        KEY_G: hire_selected()
        KEY_COMMA: price_selected(-10)
        KEY_PERIOD: price_selected(10)
        KEY_0: toggle_selected()
    queue_redraw()

func select_business(index: int) -> void:
    if parent == null: return
    if index < 0 or index >= parent.expansion.properties.size(): return
    selected = index
    parent.selected_expansion = index
    var p = parent.expansion.properties[index]
    parent.message = "Managing %s — %s." % [p["name"], p["industry"]]
    parent._log("BUSINESS SELECTED: %s." % p["name"])

func produce_selected() -> void:
    if parent == null: return
    var result = parent.expansion.produce(selected)
    parent.message = result["message"]
    if result["ok"]:
        parent.reputation += 1
        parent._log("%s" % result["message"])

func sell_selected() -> void:
    if parent == null: return
    var result = parent.expansion.sell(selected)
    parent.message = result["message"]
    if result["ok"]:
        parent.cash += int(result["profit"])
        parent.total_profit += int(result["profit"])
        parent.last_profit = int(result["profit"])
        parent.last_sales = int(result["revenue"])
        parent._log("%s Net $%s." % [result["message"], parent._money(int(result["profit"]))])

func hire_selected() -> void:
    if parent == null: return
    var result = parent.expansion.hire(selected, parent.cash)
    if result["ok"]:
        parent.cash -= int(result["cost"])
        parent.reputation += 1
    parent.message = result["message"]
    parent._log("EMPIRE: " + result["message"])

func price_selected(delta: int) -> void:
    if parent == null: return
    var result = parent.expansion.change_price(selected, delta)
    parent.message = result["message"]
    if result["ok"]: parent._log("PRICING: " + result["message"])

func toggle_selected() -> void:
    if parent == null: return
    var result = parent.expansion.toggle_active(selected)
    parent.message = result["message"]
    parent._log("OPERATIONS: " + result["message"])

func _draw() -> void:
    if parent == null or not is_instance_valid(parent): return
    if selected < 0 or selected >= parent.expansion.properties.size(): return
    var p = parent.expansion.properties[selected]
    if not p["owned"]: return

    # Management card sits over the old empire panel without changing the
    # restoration/business UI underneath it.
    draw_rect(Rect2(855,92,385,245), Color("202e38"), true)
    draw_string(ThemeDB.fallback_font, Vector2(872,119), "ACTIVE BUSINESS MANAGEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7891a5"))
    draw_string(ThemeDB.fallback_font, Vector2(872,147), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(872,172), "%s • %s • LEVEL %d" % [p["type"],p["industry"],p["level"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(872,198), "STATUS %s   STAFF %d" % ["OPEN" if p["active"] else "PAUSED",p["employees"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,221), "INVENTORY %d   PRICE $%d" % [p["stock"],p["price"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d27a"))
    draw_string(ThemeDB.fallback_font, Vector2(872,244), "[Z] Produce   [Y] Sell   [G] Hire", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,266), "[,] Price -10   [.] Price +10   [0] Open/Pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,289), "[7] Retail   [8] Factory   [9] Warehouse", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,312), "Last business net: $%s" % parent._money(int(p["last_profit"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8ee6a8"))
