extends Node2D

var kind: StringName = &"orange"
var speed: float = 120.0

func configure(ingredient_kind: StringName, art: Texture2D, travel_speed: float) -> void:
	kind = ingredient_kind
	speed = travel_speed
	var visual: Sprite2D = $Visual
	visual.texture = art
	var target_size: float = 40.0 if kind == &"soda" else (68.0 if kind == &"grape" else 56.0)
	var factor: float = minf(target_size / art.get_width(), target_size / art.get_height())
	visual.scale = Vector2.ONE * factor

func advance(delta: float) -> void:
	position.x += speed * delta
