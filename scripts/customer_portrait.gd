extends TextureRect
## Display-only: change customer when the next cup hides the result panel.

@export var portraits: Array[Texture2D] = []
var portrait_index: int = 0
var round_result: Panel

func _ready() -> void:
	if not portraits.is_empty():
		texture = portraits[0]
	round_result = get_node("../../Result")
	round_result.visibility_changed.connect(_on_result_visibility_changed)

func _on_result_visibility_changed() -> void:
	if round_result.visible or portraits.is_empty():
		return
	portrait_index = (portrait_index + 1) % portraits.size()
	texture = portraits[portrait_index]
