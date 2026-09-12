extends SceneTree

# Complete rendered visual audit for RENEW.
# Captures every command page and every managed detail screen at phone and desktop sizes.
# Intended for non-headless Godot under Xvfb in GitHub Actions.

const VIEWPORTS := [Vector2i(390, 844), Vector2i(1280, 720)]
const SECTOR_NAMES := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
const PAGE_NAMES := [
    ["OVERVIEW", "PROPERTY", "OWNERSHIP", "RECORDS"],
    ["OVERVIEW", "PRODUCTION", "BUSINESS", "PEOPLE", "COMMERCIAL", "CONTRACTS", "NEGOTIATION", "FINANCE", "FUNDING"],
    ["OVERVIEW", "RIVALS", "ALLIANCES", "CORPORATE", "GROWTH", "REGIONS", "CHARTERS", "CAPITAL", "EQUITY", "TECHNOLOGY"],
    ["OVERVIEW", "REGIONAL MANAGEMENT", "OPERATIONS", "EMPIRE MANAGEMENT", "EVENTS"],
]
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
const OUTPUT_DIR := "res://artifacts/visual-audit"

var game: Node
var manager: Node
var hud: Node
var failures: Array[String] = []
var captures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        _fail("Main scene failed to load")
        _finish()
        return

    game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await _settle(5)

    manager = root.get_node_or_null("RenewUIScreenManager")
    hud = root.get_node_or_null("Renew/UI/MainHUD")
    if manager == null:
        _fail("RenewUIScreenManager not found")
    if hud == null:
        _fail("MainHUD not found")
    if manager == null or hud == null:
        _finish()
        return

    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    _write_manifest_header()

    for viewport_size in VIEWPORTS:
        root.size = viewport_size
        root.size_changed.emit()
        await _settle(4)

        manager.hide_all_screens()
        await _settle(2)
        await _capture("startup", viewport_size)

        for sector_index in range(SECTOR_NAMES.size()):
            hud.call("_set_tab", sector_index)
            await _settle(3)
            for page_index in range(PAGE_NAMES[sector_index].size()):
                hud.call("_set_page", page_index)
                await _settle(3)
                var key := "hud_%s_%s" % [SECTOR_NAMES[sector_index].to_lower(), PAGE_NAMES[sector_index][page_index].to_lower().replace(" ", "_")]
                await _capture(key, viewport_size)

        hud.call("_set_tab", 0)
        hud.call("_set_page", 0)
        manager.hide_all_screens()
        await _settle(2)

        for screen_name in SCREENS:
            manager.show_screen(screen_name)
            await _settle(4)
            if not manager.is_screen_open(screen_name):
                _fail("Screen did not open: %s at %s" % [screen_name, viewport_size])
            await _capture("screen_%s" % screen_name.to_snake_case(), viewport_size)
            manager.hide_all_screens()
            await _settle(2)

    _finish()

func _settle(frames: int) -> void:
    for _i in range(frames):
        await process_frame

func _capture(name: String, viewport_size: Vector2i) -> void:
    var texture := root.get_viewport().get_texture()
    if texture == null:
        _fail("No render texture for %s at %s" % [name, viewport_size])
        return
    var image := texture.get_image()
    if image == null or image.is_empty():
        _fail("Empty screenshot for %s at %s" % [name, viewport_size])
        return

    var safe_name := name.to_lower().replace(" ", "_")
    var filename := "%s_%dx%d.png" % [safe_name, viewport_size.x, viewport_size.y]
    var path := "%s/%s" % [OUTPUT_DIR, filename]
    var err := image.save_png(path)
    if err != OK:
        _fail("Could not save %s" % path)
        return

    captures += 1
    _append_manifest(filename)
    print("VISUAL AUDIT SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _write_manifest_header() -> void:
    var file := FileAccess.open(OUTPUT_DIR + "/manifest.txt", FileAccess.WRITE)
    if file == null:
        _fail("Could not create visual audit manifest")
        return
    file.store_line("RENEW COMPLETE VISUAL AUDIT")
    file.store_line("Command pages: 28")
    file.store_line("Managed screens: %d" % SCREENS.size())
    file.store_line("Viewports: phone 390x844, desktop 1280x720")
    file.store_line("")
    file.close()

func _append_manifest(filename: String) -> void:
    var file := FileAccess.open(OUTPUT_DIR + "/manifest.txt", FileAccess.READ_WRITE)
    if file == null:
        return
    file.seek_end()
    file.store_line(filename)
    file.close()

func _fail(message: String) -> void:
    failures.append(message)
    push_error("VISUAL AUDIT FAIL: " + message)

func _release_player(player: AudioStreamPlayer) -> void:
    if player == null or not is_instance_valid(player):
        return
    player.stop()
    player.stream = null
    player.free()

func _shutdown_procedural_audio() -> void:
    # AudioStreamGeneratorPlayback is RefCounted independently of its player.
    # Release both the script-held playback handles and their players before
    # SceneTree shutdown so ObjectDB diagnostics reflect real ownership leaks.
    var audio_manager := root.get_node_or_null("RenewAudioManager")
    if audio_manager != null and is_instance_valid(audio_manager):
        audio_manager.set_process(false)
        audio_manager.set("_music_playback", null)
        var music_player: Variant = audio_manager.get("_music_player")
        if music_player is AudioStreamPlayer:
            _release_player(music_player as AudioStreamPlayer)
        audio_manager.set("_music_player", null)
        var sfx_players: Variant = audio_manager.get("_sfx_players")
        if sfx_players is Array:
            for player: Variant in (sfx_players as Array).duplicate():
                if player is AudioStreamPlayer:
                    _release_player(player as AudioStreamPlayer)
            (sfx_players as Array).clear()

    var ambient := game.get_node_or_null("Systems/RenewAmbientAudio") if game != null and is_instance_valid(game) else null
    if ambient != null and is_instance_valid(ambient):
        ambient.set_process(false)
        ambient.set("_playback", null)
        var ambient_player: Variant = ambient.get("_player")
        if ambient_player is AudioStreamPlayer:
            _release_player(ambient_player as AudioStreamPlayer)
        ambient.set("_player", null)

func _finish() -> void:
    print("--- COMPLETE VISUAL AUDIT SUMMARY ---")
    print("Screenshots captured: %d" % captures)
    print("Failures: %d" % failures.size())
    for failure in failures:
        print("FAILED: " + failure)

    if manager != null and is_instance_valid(manager):
        manager.hide_all_screens()
        await _settle(2)

    _shutdown_procedural_audio()
    await _settle(2)

    if current_scene == game:
        current_scene = null

    if game != null and is_instance_valid(game):
        game.queue_free()
        await process_frame
        await process_frame

    game = null
    manager = null
    hud = null
    await process_frame
    await process_frame

    quit(1 if not failures.is_empty() else 0)