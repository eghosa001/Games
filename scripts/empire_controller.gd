extends Node2D

# Direct management layer for expansion businesses and owned resource assets.
# It sits beside main.gd so the restoration loop remains stable.

var selected := 0
var selected_resource := 0
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
        KEY_4: select_resource(0)
        KEY_5: select_resource(1)
        KEY_6: select_resource(2)
        KEY_Z: produce_selected()
        KEY_Y: sell_selected()
        KEY_G: hire_selected()
        KEY_COMMA: price_selected(-10)
        KEY_PERIOD: price_selected(10)
        KEY_0: toggle_selected()
        KEY_W: harvest_selected_resource()
        KEY_D: dispatch_internal_supply()
        KEY_F: buy_selected_resource_site()
        KEY_B: upgrade_selected_resource_site()
        KEY_KP_ADD: management_upgrade()
    queue_redraw()

func select_business(index: int) -> void:
    if parent == null: return
    if index < 0 or index >= parent.expansion.properties.size(): return
    selected = index
    parent.selected_expansion = index
    var p = parent.expansion.properties[index]
    parent.message = "Managing %s — %s." % [p["name"], p["industry"]]
    parent._log("BUSINESS SELECTED: %s." % p["name"])

func select_resource(index: int) -> void:
    if parent == null: return
    if index < 0 or index >= parent.expansion.resource_sites.size(): return
    selected_resource = index
    var site = parent.expansion.resource_sites[index]
    parent.message = "Resource site selected: %s (%s)." % [site["name"],site["resource"]]
    parent._log("RESOURCE SITE: %s selected." % site["name"])

func produce_selected() -> void:
    if parent == null: return
    var result = parent.expansion.produce(selected)
    parent.message = result["message"]
    if result["ok"]:
        parent.reputation += 1
        parent._log(result["message"])

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

func harvest_selected_resource() -> void:
    if parent == null: return
    var result = parent.expansion.harvest_resource(selected_resource)
    parent.message = result["message"]
    if result["ok"]:
        parent.reputation += 1
        parent._log("RESOURCE: " + result["message"])

func buy_selected_resource_site() -> void:
    if parent == null: return
    var result = parent.expansion.buy_resource_site(selected_resource, parent.cash)
    if result["ok"]:
        parent.cash -= int(result["cost"])
        parent.reputation += 4
    parent.message = result["message"]
    parent._log("RESOURCE OWNERSHIP: " + result["message"])

func upgrade_selected_resource_site() -> void:
    if parent == null: return
    var result = parent.expansion.upgrade_resource_site(selected_resource, parent.cash)
    if result["ok"]:
        parent.cash -= int(result["cost"])
        parent.reputation += 2
    parent.message = result["message"]
    parent._log("RESOURCE UPGRADE: " + result["message"])

func dispatch_internal_supply() -> void:
    if parent == null: return
    var p = parent.expansion.properties[selected]
    var moved_total := 0
    var messages: Array[String] = []
    for resource in p["inputs"]:
        var need := int(p["input_need"].get(resource, 0))
        var current := int(p["inputs"].get(resource, 0))
        var amount := max(0, need * 2 - current)
        if amount <= 0: continue
        var result = parent.expansion.supply_business(selected, resource, amount)
        if result["ok"]:
            moved_total += int(result["moved"])
            messages.append("%d %s" % [result["moved"],resource])
    # Retail can also receive finished goods made by the headquarters business.
    if p["inputs"].has("goods"):
        var goods_result = parent.expansion.transfer_core_goods(selected, 20, parent.finished_goods)
        if goods_result["ok"]:
            parent.finished_goods -= int(goods_result["moved"])
            moved_total += int(goods_result["moved"])
            messages.append("%d finished goods" % goods_result["moved"])
    if moved_total > 0:
        parent.message = "Internal logistics moved " + ", ".join(messages) + "."
        parent._log("LOGISTICS: " + parent.message)
    else:
        parent.message = "No internal supply was available. Harvest resource sites or produce core goods first."

func management_upgrade() -> void:
    if parent == null: return
    var result = parent.expansion.management_upgrade(parent.cash)
    if result["ok"]:
        parent.cash -= int(result["cost"])
        parent.reputation += 3
    parent.message = result["message"]
    parent._log("HQ: " + result["message"])

func _draw() -> void:
    if parent == null or not is_instance_valid(parent): return
    if selected < 0 or selected >= parent.expansion.properties.size(): return
    var p = parent.expansion.properties[selected]
    if not p["owned"]: return

    draw_rect(Rect2(855,92,385,320), Color("202e38"), true)
    draw_string(ThemeDB.fallback_font, Vector2(872,119), "ACTIVE BUSINESS MANAGEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7891a5"))
    draw_string(ThemeDB.fallback_font, Vector2(872,147), p["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(872,172), "%s • %s • LEVEL %d" % [p["type"],p["industry"],p["level"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b7d7ff"))
    draw_string(ThemeDB.fallback_font, Vector2(872,198), "STATUS %s   STAFF %d" % ["OPEN" if p["active"] else "PAUSED",p["employees"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,221), "STOCK %d   PRICE $%d   QUALITY %d" % [p["stock"],p["price"],p["quality"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f2d27a"))
    var input_text := ""
    for resource in p["inputs"]:
        input_text += "%s:%d/%d  " % [resource, int(p["inputs"][resource]), int(p["input_need"].get(resource,0))]
    draw_string(ThemeDB.fallback_font, Vector2(872,243), "INPUTS " + input_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d5dee6"))
    draw_string(ThemeDB.fallback_font, Vector2(872,267), "[Z] Produce   [Y] Sell   [G] Hire", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,289), "[,] Price -10   [.] Price +10   [0] Open/Pause", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,311), "[D] Internal supply   [+] Upgrade HQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ee6a8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,333), "[7] Retail  [8] Factory  [9] Warehouse", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,355), "[4/5/6] Resource sites  [W] Harvest  [F] Acquire  [B] Upgrade", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("c6d0d8"))
    draw_string(ThemeDB.fallback_font, Vector2(872,377), "Last net: $%s   HQ level: %d" % [parent._money(int(p["last_profit"])),parent.expansion.management_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8ee6a8"))
