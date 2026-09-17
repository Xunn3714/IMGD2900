extends Node2D

var kind: StringName = &"orange"
var speed: float = 120.0

func configure(ingredient_kind: StringName, art: Texture2D, travel_speed: float) -> void:
	kind = ingredient_kind
	speed = travel_speed
	var visual: Sprite2D = $Visual
	visual.texture = art
	var factor: float = minf(40.0 / art.get_width(), 40.0 / art.get_height())
	visual.scale = Vector2.ONE * factor

func advance(delta: float) -> void:
	position.x += speed * delta
