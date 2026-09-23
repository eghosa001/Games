extends SceneTree

## Full rendered audit for the approved RESTORA Figma visual system.
## Captures every primary command view and every navigable management screen
## in Dark and Light at 390x844, plus tablet/desktop LIVE references.

const MOBILE_SIZE = Vector2i(390,844)
const TABLET_SIZE = Vector2i(834,1194)
const DESKTOP_SIZE = Vector2i(1280,720)
const VIEWS = ["live","property","operate","finance","empire","world","portfolio","intelligence","more","settings"]
const DEEP_SCREENS = [
    "ContractPanel","HeadquartersPanel","TechnologyPanel","AlliancePanel","EmployeePanel",
    "CollectionPanel","LiveOpsPanel","HistoryPanel","NewsPanel","InfrastructurePanel",
    "DashboardPanel","FinancePanel","PortfolioPanel","CorporationsPanel","RegionsPanel",
    "WorldOpportunitiesPanel","BusinessOperationsPanel","ProductionControlPanel",
    "SupplyChainPanel","EmpireExpansionPanel","EmpireIntelligencePanel",
    "EmpireProgressionPanel","EmpireIdentityPanel","NotificationsCenterPanel",
    "SaveLoadPanel","RenewDiplomacyUI","CustomerSegmentsUI"
]
const OUTPUT_DIR = "res://artifacts/visual-audit"
const EXPECTED_CAPTURES = 77

var game: Node
var hud: Node
var theme: Node
var manager: Node
var skin: Node
var failures: Array[String] = []
var captures = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed = load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene failed to load")
        _finish()
        return
    root.size = MOBILE_SIZE
    game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await _settle(5)
    hud = game.get_node_or_null("UI/MainHUD")
    skin = game.get_node_or_null("UI/MainHUD/PremiumUISkin")
    theme = root.get_node_or_null("RestoraThemeManager")
    manager = root.get_node_or_null("RenewUIScreenManager")
    if hud == null: _fail("MainHUD missing")
    if skin == null: _fail("PremiumUISkin missing")
    if theme == null: _fail("RestoraThemeManager missing")
    if manager == null: _fail("RenewUIScreenManager missing")
    if hud == null or skin == null or theme == null or manager == null:
        _finish()
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    _write_manifest()

    for mode in ["dark","light"]:
        theme.set_mode(mode)
        await _settle(3)
        manager.hide_all_screens()
        root.size = MOBILE_SIZE
        await _settle(2)
        hud._layout_responsive()
        skin._run_theme_refresh()
        await _settle(2)

        for view in VIEWS:
            hud.open_figma_view(view)
            manager.hide_all_screens()
            skin._run_theme_refresh()
            await _settle(3)
            await _capture("%s_%s" % [mode,view], MOBILE_SIZE)

        for screen_name in DEEP_SCREENS:
            hud.open_figma_view("more")
            manager.hide_all_screens()
            if not manager.show_screen(screen_name):
                _fail("Could not open management screen: " + screen_name)
                continue
            await _settle(2)
            skin._run_theme_refresh()
            skin._refresh_active_screen()
            await _settle(2)
            if str(manager.get_active_screen_name()) != screen_name:
                _fail("Wrong active management screen for " + screen_name)
                manager.hide_all_screens()
                continue
            await _capture("%s_screen_%s" % [mode,screen_name.to_lower()], MOBILE_SIZE)
            manager.hide_all_screens()
            await _settle(1)

    manager.hide_all_screens()
    theme.set_mode("dark")
    root.size = TABLET_SIZE
    await _settle(3)
    hud.open_figma_view("live")
    hud._layout_responsive()
    skin._run_theme_refresh()
    await _settle(3)
    await _capture("dark_tablet_live", TABLET_SIZE)

    root.size = DESKTOP_SIZE
    await _settle(3)
    hud.open_figma_view("live")
    hud._layout_responsive()
    skin._run_theme_refresh()
    await _settle(3)
    await _capture("dark_desktop_live", DESKTOP_SIZE)

    theme.set_mode("light")
    skin._run_theme_refresh()
    await _settle(3)
    await _capture("light_desktop_live", DESKTOP_SIZE)

    if captures != EXPECTED_CAPTURES:
        _fail("Expected %d screenshots, captured %d" % [EXPECTED_CAPTURES,captures])
    _finish()

func _settle(frames: int) -> void:
    for _i in range(frames):
        await process_frame

func _capture(name: String, size: Vector2i) -> void:
    var texture = root.get_viewport().get_texture()
    if texture == null:
        _fail("No render texture: " + name)
        return
    var image = texture.get_image()
    if image == null or image.is_empty():
        _fail("Empty screenshot: " + name)
        return
    var filename = "%s_%dx%d.png" % [name,size.x,size.y]
    var path = OUTPUT_DIR + "/" + filename
    if image.save_png(path) != OK:
        _fail("Could not save " + path)
        return
    captures += 1
    var file = FileAccess.open(OUTPUT_DIR + "/manifest.txt", FileAccess.READ_WRITE)
    if file != null:
        file.seek_end()
        file.store_line(filename)
        file.close()
    print("VISUAL AUDIT SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _write_manifest() -> void:
    var file = FileAccess.open(OUTPUT_DIR + "/manifest.txt", FileAccess.WRITE)
    if file == null:
        _fail("Could not create manifest")
        return
    file.store_line("RESTORA FIGMA ALL-SCREEN VISUAL AUDIT")
    file.store_line("Primary mobile views: %d x 2 themes" % VIEWS.size())
    file.store_line("Navigable management screens: %d x 2 themes" % DEEP_SCREENS.size())
    file.store_line("Responsive references: tablet LIVE + desktop LIVE dark/light")
    file.store_line("Expected screenshots: %d" % EXPECTED_CAPTURES)
    file.store_line("")
    file.close()

func _fail(message: String) -> void:
    failures.append(message)
    push_error("VISUAL AUDIT FAIL: " + message)

func _finish() -> void:
    print("--- FIGMA ALL-SCREEN VISUAL AUDIT SUMMARY ---")
    print("Screenshots captured: %d" % captures)
    print("Failures: %d" % failures.size())
    for failure in failures:
        print("FAILED: " + failure)
    if game != null and is_instance_valid(game):
        game.queue_free()
        await process_frame
    quit(1 if not failures.is_empty() else 0)
