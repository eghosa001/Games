extends Node2D

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:
    var main = get_parent()
    if main == null: return
    draw_rect(Rect2(0, 0, 1280, 720), Color("0c1218"), true)
    draw_rect(Rect2(0, 0, 1280, 64), Color("17232d"), true)
    var font := ThemeDB.fallback_font
    draw_string(font, Vector2(28, 41), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
    draw_string(font, Vector2(160, 39), "DAY %d" % main.day, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9fb3c8"))
    draw_string(font, Vector2(270, 39), "CASH $%s" % str(main.cash), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("8ee6a8"))
    draw_string(font, Vector2(500, 39), "REP %d" % main.reputation, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f2d27a"))
    draw_string(font, Vector2(620, 39), "DEBT $%s" % str(main.debt), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffad8f"))
    draw_string(font, Vector2(790, 39), "PROFIT $%s" % str(main.total_profit), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b7d7ff"))
    _panel(Vector2(25, 82), Vector2(390, 270))
    draw_string(font, Vector2(45, 112), "RESTORATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(font, Vector2(45, 146), "OLD WAREHOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
    draw_string(font, Vector2(45, 176), str(main.stage), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("8ee6a8"))
    draw_string(font, Vector2(45, 229), "%d%% restored" % main.restoration, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    draw_string(font, Vector2(45, 258), "Next stage: $%s" % str(_next_cost(main)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2d27a"))
    draw_string(font, Vector2(45, 292), "I inspect  A acquire  R restore  O open", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6d0d8"))
    draw_string(font, Vector2(45, 318), "The building improves as you invest in it.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aab8c3"))
    _panel(Vector2(435, 82), Vector2(390, 270))
    draw_string(font, Vector2(455, 112), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(font, Vector2(455, 145), "EMPLOYEES %d   CAPACITY %d" % [main.employees, main.capacity_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
    draw_string(font, Vector2(455, 174), "GOODS %d   PRICE $%d" % [main.finished_goods, main.player_price], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("8ee6a8"))
    draw_string(font, Vector2(455, 203), "MARKETING %d" % main.marketing_level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("b7d7ff"))
    draw_string(font, Vector2(455, 234), "B buy inputs  T supplier  P price", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6d0d8"))
    draw_string(font, Vector2(455, 257), "B produce  H hire  U capacity  M marketing", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6d0d8"))
    draw_string(font, Vector2(455, 280), "N end day  K contract  J loan  V repay", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6d0d8"))
    draw_string(font, Vector2(455, 303), "Contract: %d days | $%s/day" % [main.contract_days, str(main.contract_bonus)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f2d27a"))
    draw_string(font, Vector2(455, 326), "Last P&L: $%s" % str(main.last_profit), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    _panel(Vector2(845, 82), Vector2(410, 270))
    var r = main.rivals.rivals[main.selected_rival]
    var d = main.districts.current()
    draw_string(font, Vector2(865, 112), "REGION & COMPETITION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(font, Vector2(865, 143), "[%d] %s" % [main.selected_rival + 1, r["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
    draw_string(font, Vector2(865, 171), "Price $%d | Relationship %d" % [r["price"], r["relationship"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2d27a"))
    draw_string(font, Vector2(865, 198), "1-3 select  L improve  C alliance", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c6d0d8"))
    draw_string(font, Vector2(865, 228), "District: %s" % d["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("8ee6a8"))
    draw_string(font, Vector2(865, 252), "Demand %.2fx | Logistics %.2fx" % [d["demand"], d["logistics"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b7d7ff"))
    draw_string(font, Vector2(865, 274), "Rival pressure %.0f%% | Supplier pressure %d" % [main.rivals.district_pressure(main.selected_district) * 100.0, main.rivals.supplier_pressure(main.selected_district)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffad8f"))
    draw_string(font, Vector2(865, 298), "TAB district | 1-3 rival | 7-9 business", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d0d8"))
    draw_string(font, Vector2(865, 326), "Deal: %s (%d days) | Fleet L%d" % [r["deal"], r["deal_days"], main.transport_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d27a"))
    _panel(Vector2(25, 375), Vector2(800, 315))
    draw_string(font, Vector2(45, 405), "ACTIVITY / MARKET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(font, Vector2(45, 432), "Materials $%d   Packaging $%d   Fuel $%d" % [main.economy.resources["materials"]["price"], main.economy.resources["packaging"]["price"], main.economy.resources["fuel"]["price"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
    draw_string(font, Vector2(45, 457), "Supplier tier %d | Debt payment $%s/day" % [main.supplier_choice + 1, str(main.loan_payment)], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b7d7ff"))
    for i in range(main.log_lines.size()): draw_string(font, Vector2(45, 490 + i * 27), main.log_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aab8c3"))
    _panel(Vector2(845, 375), Vector2(410, 315))
    draw_string(font, Vector2(865, 405), "CEO STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("7891a5"))
    draw_string(font, Vector2(865, 438), str(main.message), HORIZONTAL_ALIGNMENT_LEFT, 365, 15, Color.WHITE)
    draw_string(font, Vector2(865, 493), "F5 save    F9 load", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2d27a"))
    draw_string(font, Vector2(865, 530), "Core: RESTORE → BUSINESS → PROFIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ee6a8"))
    draw_string(font, Vector2(865, 556), "REGION → LOGISTICS → RESOURCES → EMPIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8ee6a8"))
    draw_string(font, Vector2(865, 610), "Deals: L alliance | C alliance offer", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2d27a"))
    draw_string(font, Vector2(865, 636), "RENEW: rebuild the world you eventually control.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aab8c3"))

func _next_cost(main) -> int:
    if main.stage == "Operational": return 0
    for i in range(main.stages.size()):
        if main.stages[i][0] == main.stage and i + 1 < main.stages.size(): return int(main.stages[i + 1][2])
    return 0

func _panel(position: Vector2, size: Vector2) -> void:
    draw_rect(Rect2(position, size), Color("111b23"), true)
