extends SceneTree

const POLISH := preload("res://scripts/premium_product_polish.gd")
const MIN_TOUCH := 44.0

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("RESTORA PREMIUM PRODUCT POLISH GATE")
    var polish := POLISH.new()
    root.add_child(polish)
    await process_frame

    var button := Button.new()
    button.text = "PRIMARY ACTION"
    polish._polish(button)
    _check(button.custom_minimum_size.y >= MIN_TOUCH, "Buttons enforce >=44px touch targets")
    _check(button.has_theme_stylebox_override("normal"), "Buttons never use stock normal style")
    _check(button.has_theme_stylebox_override("hover"), "Buttons have authored hover state")
    _check(button.has_theme_stylebox_override("pressed"), "Buttons have authored pressed state")
    _check(button.has_theme_stylebox_override("disabled"), "Buttons have authored disabled state")
    _check(button.has_theme_stylebox_override("focus"), "Buttons have authored keyboard focus state")

    var input := LineEdit.new()
    polish._polish(input)
    _check(input.custom_minimum_size.y >= MIN_TOUCH, "Text inputs enforce >=44px touch targets")
    _check(input.has_theme_stylebox_override("normal"), "Text inputs never use stock normal style")
    _check(input.has_theme_stylebox_override("focus"), "Text inputs have authored focus style")

    var tabs := TabBar.new()
    tabs.add_tab("OVERVIEW")
    polish._polish(tabs)
    _check(tabs.custom_minimum_size.y >= MIN_TOUCH, "Tabs enforce >=44px touch targets")
    _check(tabs.has_theme_stylebox_override("tab_selected"), "Tabs have authored selected state")
    _check(tabs.has_theme_stylebox_override("tab_hovered"), "Tabs have authored hover state")

    var list := ItemList.new()
    polish._polish(list)
    _check(list.has_theme_stylebox_override("panel"), "Lists use an authored surface")
    _check(list.has_theme_stylebox_override("selected"), "Lists use an authored selection state")

    var tree := Tree.new()
    polish._polish(tree)
    _check(tree.has_theme_stylebox_override("panel"), "Trees use an authored surface")
    _check(tree.has_theme_stylebox_override("selected_focus"), "Trees use an authored focus selection")

    var scroll := ScrollContainer.new()
    var body := Control.new()
    body.custom_minimum_size = Vector2(800, 800)
    scroll.add_child(body)
    root.add_child(scroll)
    await process_frame
    polish._polish(scroll)
    var vbar := scroll.get_v_scroll_bar()
    _check(vbar != null and vbar.has_theme_stylebox_override("grabber"), "Scrollbars use an authored grabber")
    _check(vbar != null and vbar.has_theme_stylebox_override("grabber_highlight"), "Scrollbars use an authored hover state")

    button.queue_free()
    input.queue_free()
    tabs.queue_free()
    list.queue_free()
    tree.queue_free()
    scroll.queue_free()
    polish.queue_free()
    _finish()

func _check(condition: bool, label: String) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- PREMIUM PRODUCT POLISH SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    for failure in failures:
        print("FAILED: %s" % failure)
    quit(1 if not failures.is_empty() else 0)
