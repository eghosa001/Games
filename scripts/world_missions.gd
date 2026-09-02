extends Node2D

# RENEW World Missions - recurring narrative opportunities and economic choices.
var parent
var active := false
var title := ""
var text := ""
var option_a := ""
var option_b := ""
var mission_type := ""
var expires_day := 0
var reward_preview := ""
var cooldown := 2
var completed := 0

var missions := [
    {"type":"community","title":"The Neighborhood Is Watching","text":"A neglected block near your district needs cleanup. A visible investment could build loyalty before a rival moves in.","a":"Spend $3,000","b":"Ignore it","reward":"+6 reputation"},
    {"type":"supplier","title":"Supplier in Trouble","text":"A small supplier has lost a major customer. Helping them now could secure favorable terms for your growing empire.","a":"Invest $5,000","b":"Walk away","reward":"12-day supply discount"},
    {"type":"giant","title":"The Giant Starts a Price War","text":"The Giant has slashed prices in your district. You can defend your customers or protect your cash.","a":"Defend market ($4,000)","b":"Hold prices","reward":"+8 reputation or save cash"},
    {"type":"ally","title":"An Ally Needs You","text":"A business ally needs emergency working capital. Helping strengthens the relationship; refusing may make them less loyal.","a":"Help ($2,500)","b":"Refuse","reward":"+12 relationship"},
    {"type":"boom","title":"Regional Construction Boom","text":"A sudden construction boom is creating demand for building materials. Your empire can react before competitors do.","a":"Commit $6,000","b":"Stay cautious","reward":"+30% expansion production for 5 days"},
    {"type":"distressed","title":"Distressed Asset Opportunity","text":"A failing local operator is willing to sell a useful facility cheaply. It could become your next foothold.","a":"Buy for $12,000","b":"Pass","reward":"Asset + reputation"}
]

func _ready() -> void:
    parent = get_parent()
    queue_redraw()

func _process(_delta: float) -> void:
    if parent == null: return
    if active and parent.day > expires_day:
        active = false
        parent._log("WORLD: The opportunity expired before you acted.")
        parent.message = "A world opportunity expired. Timing matters."
    elif not active and cooldown > 0:
        cooldown -= 1
    elif not active and cooldown <= 0 and parent.day >= 4 and parent.day % 3 == 1:
        _spawn()
    queue_redraw()

func _spawn() -> void:
    var pool := missions.duplicate()
    pool.shuffle()
    var m: Dictionary = pool[0]
    mission_type = str(m["type"])
    title = str(m["title"])
    text = str(m["text"])
    option_a = str(m["a"])
    option_b = str(m["b"])
    reward_preview = str(m["reward"])
    expires_day = parent.day + 2
    active = true
    parent.message = "WORLD OPPORTUNITY: %s" % title
    parent._log("WORLD OPPORTUNITY: %s — %s" % [title, text])

func choose_a() -> void:
    if not active: parent.message = "No active world opportunity."; return
    var success := true
    match mission_type:
        "community":
            success = _spend(3000)
            if success: parent.reputation += 6
        "supplier":
            success = _spend(5000)
            if success:
                parent.rivals.rivals[parent.selected_rival]["relationship"] = min(100, int(parent.rivals.rivals[parent.selected_rival]["relationship"]) + 8)
                parent.reputation += 3
        "giant":
            success = _spend(4000)
            if success: parent.reputation += 8; parent.rivals.rivals[0]["price"] = max(85, int(parent.rivals.rivals[0]["price"]) + 8)
        "ally":
            success = _spend(2500)
            if success: parent.rivals.rivals[parent.selected_rival]["relationship"] = min(100, int(parent.rivals.rivals[parent.selected_rival]["relationship"]) + 12)
        "boom":
            success = _spend(6000)
            if success: parent.expansion.boom_days = 5; parent.reputation += 5
        "distressed":
            success = _spend(12000)
            if success: parent.acquisition_count += 1; parent.reputation += 10
    if success: _complete("You committed resources and turned the opportunity into an advantage.")

func choose_b() -> void:
    if not active: parent.message = "No active world opportunity."; return
    match mission_type:
        "community": parent.reputation = max(0, parent.reputation - 1)
        "supplier": parent.rivals.rivals[parent.selected_rival]["relationship"] = max(-100, int(parent.rivals.rivals[parent.selected_rival]["relationship"]) - 4)
        "giant": parent._log("WORLD: You refused to match The Giant. Cash preserved, but customers noticed.")
        "ally": parent.rivals.rivals[parent.selected_rival]["relationship"] = max(-100, int(parent.rivals.rivals[parent.selected_rival]["relationship"]) - 7)
        "boom": parent.message = "You stayed cautious and preserved cash while competitors chased the boom."
        "distressed": parent.message = "You passed on the distressed asset. Another buyer may claim it."
    _complete("You declined the opportunity. The market will remember the choice.")

func _spend(amount: int) -> bool:
    if parent.cash < amount:
        parent.message = "You need $%s to take this opportunity." % parent._money(amount)
        return false
    parent.cash -= amount
    return true

func _complete(result: String) -> void:
    completed += 1
    active = false
    cooldown = 3
    parent.expansion.unlock_from_reputation(parent.reputation)
    parent.districts.update_unlocks(parent.reputation)
    parent._log("WORLD DECISION: %s" % result)
    parent.message = result

func _draw() -> void:
    if parent == null or not active: return
    var panel := Rect2(855, 80, 385, 255)
    draw_rect(panel, Color("171c25"), true)
    draw_rect(panel, Color("7c91a3"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(870, 105), "WORLD OPPORTUNITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f0f4f7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 130), title, HORIZONTAL_ALIGNMENT_LEFT, 350, 15, Color("ffd166"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 153), text, HORIZONTAL_ALIGNMENT_LEFT, 350, 12, Color("d6e0e7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 215), "A: %s" % option_a, HORIZONTAL_ALIGNMENT_LEFT, 350, 12, Color("9fd3ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 237), "B: %s" % option_b, HORIZONTAL_ALIGNMENT_LEFT, 350, 12, Color("9fd3ff"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 260), "Potential: %s" % reward_preview, HORIZONTAL_ALIGNMENT_LEFT, 350, 12, Color("c7d0d7"))
    draw_string(ThemeDB.fallback_font, Vector2(870, 283), "Expires after Day %d" % expires_day, HORIZONTAL_ALIGNMENT_LEFT, 350, 12, Color("ffadad"))

func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo: return
    match event.keycode:
        KEY_F1: choose_a()
        KEY_F2: choose_b()
