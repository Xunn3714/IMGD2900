extends Node2D

var kind: StringName = &"orange"
var speed: float = 120.0
var animation_time: float = 0.0
var bob_phase: float = 0.0

func configure(ingredient_kind: StringName, art: Texture2D, travel_speed: float) -> void:
	kind = ingredient_kind
	speed = travel_speed
	bob_phase = randf_range(0.0, TAU)
	var visual: Sprite2D = $Visual
	visual.texture = art
	var target_size: float = 40.0 if kind == &"soda" else (68.0 if kind == &"grape" else 56.0)
	var factor: float = minf(target_size / art.get_width(), target_size / art.get_height())
	visual.scale = Vector2.ONE * factor

func advance(delta: float) -> void:
	position.x += speed * delta
	animation_time += delta
	var bob: float = sin(animation_time * 6.0 + bob_phase)
	var tilt: float = sin(animation_time * 10.0 + bob_phase) * 0.1
	var visual: Sprite2D = $Visual
	visual.position.y = bob * 2.0
	visual.rotation = tilt
