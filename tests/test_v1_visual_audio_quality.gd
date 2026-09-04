extends SceneTree

# V1 quality gate for the presentation layer.
# Visual checks are deterministic and run headlessly. When rendering is available,
# a PNG audit frame is written for CI artifact inspection.
# Audio checks validate the runtime audio contract without pretending that a
# synthetic tone proves artistic mix quality. Missing game audio is reported as
# a warning until production audio assets are installed.

var passed: int = 0
var failed: int = 0
var warnings: int = 0
var failures: Array[String] = []

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func warn(label: String) -> void:
    warnings += 1
    print("WARN: " + label)

func run() -> void:
    await test_visual_quality()
    await test_audio_quality()
    print("\nRENEW V1 VISUAL/AUDIO QUALITY RESULT: %d passed, %d failed, %d warnings" % [passed, failed, warnings])
    if failed > 0:
        for item in failures:
            print("FAILED: " + item)
        quit(1)
    quit(0)

func _load_main() -> Node:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "quality Main scene loads")
    if scene == null:
        return null
    var game = scene.instantiate()
    check(game != null, "quality Main scene instantiates")
    if game == null:
        return null
    root.add_child(game)
    await process_frame
    await process_frame
    return game

func test_visual_quality() -> void:
    var game = await _load_main()
    if game == null:
        return

    check(game.get_node_or_null("World/MainRenderer") != null, "visual main renderer present")
    check(game.get_node_or_null("World/PropertyVisual") != null, "visual property renderer present")
    check(game.get_node_or_null("World/WorldView") != null, "visual world map present")
    check(game.get_node_or_null("UI/MainHUD") != null, "visual mobile HUD present")
    check(game.get_node_or_null("UI/StrategyHUD") != null, "visual strategy HUD present")
    check(game.get_node_or_null("UI/HeadquartersPanel") != null, "visual headquarters presentation present")
    check(game.get_node_or_null("UI/EmployeePanel") != null, "visual employee presentation present")

    check(ResourceLoader.exists("res://assets/ui/renew_logo.svg"), "visual RENEW logo asset present")
    var resource_names := ["timber", "iron", "energy", "food", "electronics"]
    for name in resource_names:
        check(ResourceLoader.exists("res://Assets/ui/resource_icons/%s.svg" % name), "visual resource icon present: " + name)

    var viewport := get_viewport()
    check(viewport != null, "visual viewport available")
    if viewport != null:
        var size := viewport.get_visible_rect().size
        check(size.x >= 1200.0 and size.y >= 680.0, "visual viewport is HD-sized")
        var image := viewport.get_texture().get_image()
        check(image != null and image.get_width() > 0 and image.get_height() > 0, "visual frame rendered")
        if image != null and image.get_width() > 0:
            var probe_points := [
                Vector2i(8, 8), Vector2i(image.get_width() / 2, 8),
                Vector2i(8, image.get_height() / 2), Vector2i(image.get_width() / 2, image.get_height() / 2)
            ]
            var unique_colors := {}
            for point in probe_points:
                var c := image.get_pixelv(point)
                unique_colors[c.to_html()] = true
            check(unique_colors.size() >= 2, "visual frame has meaningful tonal variation")

            DirAccess.make_dir_recursive_absolute("artifacts")
            var save_error := image.save_png("artifacts/v1_visual_quality.png")
            check(save_error == OK, "visual audit PNG saved")

    game.free()
    await process_frame

func test_audio_quality() -> void:
    # AudioStreamPlayer is the correct non-positional primitive for UI/menu sounds.
    # We inspect the composed scene rather than inventing a fake pass for absent audio.
    var game = await _load_main()
    if game == null:
        return

    var players: Array[Node] = []
    _collect_audio_players(game, players)
    if players.is_empty():
        warn("no AudioStreamPlayer nodes are installed yet; audio quality gate is waiting for production audio")
    else:
        check(players.size() >= 1, "audio player infrastructure present")
        for player in players:
            var stream = player.get("stream")
            check(stream != null, "audio player has a valid stream: " + player.name)
            var bus := String(player.get("bus"))
            check(bus != "", "audio player has a named bus: " + player.name)
            var volume := float(player.get("volume_db"))
            check(volume <= 0.0 and volume >= -30.0, "audio player level is in sane UI range: " + player.name)

    var audio_bus_count := AudioServer.get_bus_count()
    check(audio_bus_count >= 1, "audio master bus exists")
    check(AudioServer.get_bus_index(&"Master") >= 0, "audio Master bus is addressable")

    # A procedural smoke tone proves that the runtime can create a valid stream,
    # without claiming subjective sound-design quality.
    var generator := AudioStreamGenerator.new()
    generator.mix_rate = 22050.0
    generator.buffer_length = 0.1
    var player := AudioStreamPlayer.new()
    player.stream = generator
    player.volume_db = -12.0
    game.add_child(player)
    player.play()
    await process_frame
    check(player.has_stream_playback(), "audio runtime can start a generated stream")
    player.stop()
    player.queue_free()

    game.free()
    await process_frame

func _collect_audio_players(node: Node, result: Array[Node]) -> void:
    if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
        result.append(node)
    for child in node.get_children():
        _collect_audio_players(child, result)
