extends CanvasLayer

## Mobile-first control surface. Presentation only; gameplay remains owned by Main/command systems.
var parent: Node
var root: Control
var status_label: Label
var goal_label: Label
var actions: GridContainer
var feedback: Label

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    if parent == null: return
    root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    status_label = Label.new(); status_label.position = Vector2(24, 18); status_label.size = Vector2(900, 36); status_label.add_theme_font_size_override("font_size", 18); root.add_child(status_label)
    goal_label = Label.new(); goal_label.position = Vector2(24, 56); goal_label.size = Vector2(900, 34); goal_label.add_theme_font_size_override("font_size", 14); root.add_child(goal_label)
    var scroll := ScrollContainer.new(); scroll.position = Vector2(18, 105); scroll.size = Vector2(900, 145); scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(scroll)
    actions = GridContainer.new(); actions.columns = 3; actions.add_theme_constant_override("h_separation", 10); actions.add_theme_constant_override("v_separation", 8); scroll.add_child(actions)
    feedback = Label.new(); feedback.position = Vector2(24, 265); feedback.size = Vector2(900, 80); feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback.add_theme_font_size_override("font_size", 14); root.add_child(feedback)
    _refresh()

func _process(_delta: float) -> void:
    if parent == null or status_label == null: return
    status_label.text = "$%s   |   REP %d   |   DAY %d" % [String.num_int64(int(parent.cash)), int(parent.reputation), int(parent.day)]
    if goal_label == null: return
    if not bool(parent.owned): goal_label.text = "GOAL  •  Inspect and acquire the abandoned warehouse."
    elif str(parent.stage) != "Operational": goal_label.text = "GOAL  •  Finish restoring the warehouse."
    elif not bool(parent.business_open): goal_label.text = "GOAL  •  Open RENEW Goods."
    elif int(parent.total_profit) <= 0: goal_label.text = "GOAL  •  Produce goods and close a profitable day."
    else: goal_label.text = "GOAL  •  Expand your empire and control the network."

func _add_button(text: String, callback: Callable) -> void:
    var button := Button.new(); button.text = text; button.custom_minimum_size = Vector2(210, 46); button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_run.bind(text, callback)); actions.add_child(button)

func _run(label: String, callback: Callable) -> void:
    if not callback.is_valid(): feedback.text = "%s\nUnavailable." % label; return
    var result = callback.call()
    if result is Dictionary and result.has("message"): feedback.text = String(result["message"])
    elif not String(parent.message).is_empty(): feedback.text = String(parent.message)
    else: feedback.text = "%s completed." % label
    _refresh()

func _refresh() -> void:
    if actions == null or parent == null: return
    for child in actions.get_children(): child.queue_free()
    _add_button("INSPECT", parent.inspect_property); _add_button("ACQUIRE", parent.acquire_property); _add_button("RESTORE", parent.restore_property); _add_button("OPEN BUSINESS", parent.open_business)
    _add_button("BUY INPUTS", parent.buy_inputs); _add_button("PRODUCE", parent.produce_goods); _add_button("HIRE", parent.hire_employee); _add_button("UPGRADE", parent.upgrade_business)
    _add_button("MARKETING", parent.marketing_campaign); _add_button("PRICE", parent.change_price); _add_button("SUPPLIER", parent.cycle_supplier); _add_button("END DAY", parent.advance_day)
    _add_button("EXPAND", parent.buy_expansion); _add_button("UPGRADE ASSET", parent.upgrade_expansion); _add_button("ALLIANCE", parent.make_alliance_offer); _add_button("IMPROVE RELATION", parent.improve_alliance)
    _add_button("LOAN", parent.take_loan); _add_button("REPAY", parent.repay_loan)
