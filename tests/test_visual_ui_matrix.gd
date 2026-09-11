extends SceneTree

# Rendered UI evidence gate. Run this under Xvfb/non-headless Godot.
# Every managed screen is rendered at a representative phone and desktop size,
# checked for non-empty/varied pixels, and saved as CI evidence.

const VIEWPORTS := [Vector2i(390, 844), Vector2i(1280, 720)]
const SCREENS := [
    "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel",
    "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel",
    "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel",
    "PortfolioPanel", "CorporationsPanel", "RegionsPanel", "WorldOpportunitiesPanel",
    "BusinessOperationsPanel", "ProductionControlPanel", "SupplyChainPanel",
    "EmpireExpansionPanel", "EmpireIntelligencePanel", "EmpireProgressionPanel",
    "EmpireIdentityPanel", "NotificationsCenterPanel", "SaveLoadPanel",
    "RenewDiplomacyUI", "CustomerSegmentsUI",
]
const OUTPUT_DIR := "res://artifacts/ui-matrix"
const MIN_NON_DARK_SAMPLES := 24
const MIN_VARIANCE := 0.00008

var checks := 0
var failures: Array[String] = []
var game: Node
var manager: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    _check(packed != null, "Main scene loads")
    if packed == null:
        _finish()
        return
    game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    manager = root.get_node_or_null("RenewUIScreenManager")
    _check(manager != null, "UIScreenManager resolves")
    if manager == null:
        _finish()
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

    for viewport_size in VIEWPORTS:
        root.size = viewport_size
        root.size_changed.emit()
        await process_frame
        await process_frame
        for screen_name in SCREENS:
            manager.show_screen(screen_name)
            await process_frame
            await process_frame
            await process_frame
            _check(manager.is_screen_open(screen_name), "%s opens at %s" % [screen_name, viewport_size])
            await _capture_screen(screen_name, viewport_size)
            manager.hide_all_screens()
            await process_frame

    _finish()

func _capture_screen(screen_name: String, viewport_size: Vector2i) -> void:
    var texture := root.get_viewport().get_texture()
    _check(texture != null, "%s has render texture at %s" % [screen_name, viewport_size])
    if texture == null:
        return
    var image := texture.get_image()
    _check(image != null and not image.is_empty(), "%s renders pixels at %s" % [screen_name, viewport_size])
    if image == null or image.is_empty():
        return

    var non_dark := 0
    var samples := 0
    var sum := 0.0
    var sum_sq := 0.0
    var step_x := maxi(1, image.get_width() / 24)
    var step_y := maxi(1, image.get_height() / 16)
    for y in range(0, image.get_height(), step_y):
        for x in range(0, image.get_width(), step_x):
            var c := image.get_pixel(x, y)
            var luminance := (c.r + c.g + c.b) / 3.0
            if luminance > 0.025:
                non_dark += 1
            sum += luminance
            sum_sq += luminance * luminance
            samples += 1
    var divisor := maxf(float(samples), 1.0)
    var mean := sum / divisor
    var variance := maxf(sum_sq / divisor - mean * mean, 0.0)
    _check(non_dark >= MIN_NON_DARK_SAMPLES, "%s frame has visible content at %s" % [screen_name, viewport_size])
    _check(variance >= MIN_VARIANCE, "%s frame has visual variation at %s" % [screen_name, viewport_size])

    var safe_name := screen_name.to_snake_case()
    var path := "%s/%s_%dx%d.png" % [OUTPUT_DIR, safe_name, viewport_size.x, viewport_size.y]
    var err := image.save_png(path)
    _check(err == OK, "%s screenshot saved at %s" % [screen_name, viewport_size])
    if err == OK:
        print("UI MATRIX SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _check(ok: bool, label: String) -> void:
    checks += 1
    if ok:
        print("PASS: " + label)
    else:
        failures.append(label)
        push_error("FAIL: " + label)

func _finish() -> void:
    print("--- VISUAL UI MATRIX SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures:
            print("FAILED: " + failure)
    else:
        print("VISUAL UI MATRIX: PASS")
    if game != null and is_instance_valid(game):
        game.free()
    await process_frame
    quit(1 if not failures.is_empty() else 0)
