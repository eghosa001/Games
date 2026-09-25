extends Node2D

## Legacy property presentation layer retained for compatibility.
## It intentionally renders no building, world, structure, or progression artwork.
## Restoration is represented only as management status and upgrade progress.

const STEPS := ["cleaning", "repair", "painting", "furnishing"]
const GOLD := Color("e4bd68")
const GREEN := Color("67c99a")
const TEXT := Color("eef7f3")
const MUTED := Color("a7bdbe")
const PANEL := Color(0.035, 0.07, 0.08, 0.94)
const TRACK := Color("16282e")

var _time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if fmod(_time, 0.20) < delta:
		queue_redraw()

func _using_3d_world() -> bool:
	# RESTORA no longer uses a rendered property structure.
	return false

func should_draw_site_overlay() -> bool:
	return true

func _draw() -> void:
	var state = get_node_or_null("/root/RenewGameState")
	if state == null:
		return
	var catalog = state.get_value("properties", "catalog", [])
	if not catalog is Array or catalog.is_empty():
		return
	var index := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
	var property: Dictionary = catalog[index]
	var owned := bool(property.get("owned", state.get_value("properties", "owned", false)))
	var stage := _visual_stage(property, owned)
	_draw_status_only(property, stage)

func _visual_stage(property: Dictionary, owned: bool) -> String:
	if not owned:
		return "Abandoned"
	if int(property.get("cleaning", 0)) < 100:
		return "Abandoned"
	if int(property.get("repair", 0)) < 100:
		return "Cleaned"
	if int(property.get("painting", 0)) < 100:
		return "Repaired"
	if int(property.get("furnishing", 0)) < 50:
		return "Painted"
	if int(property.get("furnishing", 0)) < 100:
		return "Furnished"
	return "Operational"

func _stage_progress(stage: String) -> float:
	match stage:
		"Abandoned": return 0.0
		"Cleaned": return 0.24
		"Repaired": return 0.48
		"Painted": return 0.68
		"Furnished": return 0.86
		"Operational": return 1.0
	return 0.0

func _stage_frame(stage: String) -> int:
	match stage:
		"Abandoned": return 0
		"Cleaned": return 1
		"Repaired": return 2
		"Painted": return 3
		"Furnished": return 4
		"Operational": return 5
	return 0

func _restoration_percent(property: Dictionary) -> int:
	var total := 0
	for step in STEPS:
		total += clampi(int(property.get(step, 0)), 0, 100)
	return int(round(float(total) / float(STEPS.size())))

func _draw_status_only(property: Dictionary, stage: String) -> void:
	var viewport_size := get_viewport_rect().size
	var w := maxf(viewport_size.x, 320.0)
	var h := maxf(viewport_size.y, 240.0)
	var compact := w < 760.0
	var progress := _restoration_percent(property)
	var card_w := maxf(180.0, w - 24.0) if compact else minf(720.0, w - 36.0)
	var card_h := 112.0 if compact else 94.0
	var card := Rect2(12.0 if compact else (w - card_w) * 0.5, h - card_h - 14.0, card_w, card_h)
	var accent := GOLD if stage == "Operational" else GREEN
	var font := ThemeDB.fallback_font
	draw_rect(card, PANEL, true)
	draw_rect(Rect2(card.position, Vector2(4.0, card.size.y)), accent, true)
	draw_string(font, card.position + Vector2(16, 23), str(property.get("name", "Property")), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 14, TEXT)
	draw_string(font, card.position + Vector2(16, 44), "UPGRADE LEVEL %d/6 • %s" % [_stage_frame(stage) + 1, stage.to_upper()], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 10, MUTED)
	var bar := Rect2(card.position + Vector2(16, 58), Vector2(card.size.x - 32, 9))
	draw_rect(bar, TRACK, true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(progress) / 100.0, bar.size.y)), accent, true)
	draw_string(font, card.position + Vector2(16, 88), "%d%% RESTORED • %s" % [progress, _stage_caption(stage)], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32, 10, TEXT)

func _stage_caption(stage: String) -> String:
	match stage:
		"Abandoned": return "Inspection and cleanup required"
		"Cleaned": return "Structural repairs next"
		"Repaired": return "Finishing work next"
		"Painted": return "Fit-out in progress"
		"Furnished": return "Commissioning next"
		"Operational": return "Ready for commercial use"
	return "Restoration active"
