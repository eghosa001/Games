extends CanvasLayer

# Player-facing RESTORA branding layer. Legacy Renew* implementation names stay intact
# to protect save compatibility and reduce rebrand regression risk.

const TITLE := "RESTORA"
const SUBTITLE := "BUSINESS EMPIRE"
const TAGLINE := "RESTORE  •  BUILD  •  GROW  •  COMPETE  •  EMPIRE"

func _ready() -> void:
    layer = 95
    call_deferred("_apply_brand")

func _apply_brand() -> void:
    get_window().title = "RESTORA: Business Empire"
    _replace_visible_branding(get_tree().root)

func _replace_visible_branding(node: Node) -> void:
    if node is Label:
        var label := node as Label
        if label.text == "RENEW":
            label.text = TITLE
        elif label.text.contains("RENEW Goods"):
            label.text = label.text.replace("RENEW Goods", "RESTORA Goods")
    elif node is Button:
        var button := node as Button
        if button.text.contains("RENEW Goods"):
            button.text = button.text.replace("RENEW Goods", "RESTORA Goods")
    for child in node.get_children():
        _replace_visible_branding(child)

func _process(_delta: float) -> void:
    # UI panels are created dynamically, so keep newly-created player-facing labels branded.
    _replace_visible_branding(get_tree().root)
