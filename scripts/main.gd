extends Control
## Space is the only gameplay key.
signal exit_requested
const Rules = preload("res://scripts/round_rules.gd")
const INGREDIENT_SCENE: PackedScene = preload("res://scenes/ingredient.tscn")
const TRACK_LEFT: float = 32.0
const TRACK_RIGHT: float = 608.0
const TRACK_Y: float = 226.0

@export_group("Playtest tuning")
@export_range(60.0, 240.0, 5.0) var ingredient_speed: float = 120.0
@export_range(0.8, 3.0, 0.1) var spawn_interval: float = 1.5
@export_range(32.0, 120.0, 8.0) var hit_width: float = 64.0
@export_range(15.0, 120.0, 5.0) var round_duration: float = 45.0
@export var distractors_enabled: bool = true

@export_group("Replaceable artwork")
@export var customer_art: Texture2D = preload("res://icon.svg")
@export var orange_art: Texture2D = preload("res://art/placeholders/orange.svg")
@export var soda_art: Texture2D = preload("res://art/placeholders/soda.svg")
@export var cherry_art: Texture2D = preload("res://art/placeholders/cherry.svg")

@onready var hit_zone: ColorRect = $Track/HitZone
@onready var ingredient_container: Node2D = $Track/Clip/Ingredients
@onready var liquid: ColorRect = $Cup/Contents/Liquid
@onready var fruit_container: Control = $Cup/Contents/Fruits
@onready var timer_label: Label = $TimeRemaining
@onready var result_panel: Panel = $Result
@onready var result_title: Label = $Result/Title

var hit_center: float = 484.0
var hit_zone_speed: float = 110.0
var hit_zone_direction: float = 1.0
var rules = Rules.new()
var textures: Dictionary = {}
var bag: Array[StringName] = []
var spawn_elapsed: float = 0.0
var elapsed: float = 0.0
var restart_delay: float = 0.0
# Test scripts intercept exit_requested; normal gameplay closes immediately.
var quit_on_game_over: bool = true

func _ready() -> void:
	$CustomerWindow/Customer.texture = customer_art
	textures = {&"orange": orange_art, &"soda": soda_art, &"cherry": cherry_art}
	hit_zone_speed = randf_range(140.0, 300.0)
	hit_zone_direction = 1.0 if randf() < 0.5 else -1.0
	hit_zone.position = Vector2(hit_center - hit_width * 0.5, 198.0)
	hit_zone.size = Vector2(hit_width, 56.0)
	start_round()

func start_round() -> void:
	if rules.game_over:
		return
	_clear_ingredients()
	for child in fruit_container.get_children():
		fruit_container.remove_child(child)
		child.queue_free()
	rules.start_cup()
	bag.clear()
	spawn_elapsed = 0.0
	elapsed = 0.0
	restart_delay = 0.0
	liquid.visible = false
	result_panel.visible = false
	timer_label.text = "%ds" % ceili(round_duration)
	_spawn_ingredient(&"orange")

func _process(delta: float) -> void:
	if rules.finished:
		restart_delay = maxf(0.0, restart_delay - delta)
		return
	_moving_hit_zone(delta)
	elapsed += delta
	timer_label.text = "%ds" % maxi(0, ceili(round_duration - elapsed))
	if elapsed >= round_duration:
		rules.expire()
		_show_result()
		return
	spawn_elapsed += delta
	while spawn_elapsed >= spawn_interval:
		spawn_elapsed -= spawn_interval
		_spawn_ingredient(_next_kind())
	for item in ingredient_container.get_children():
		item.advance(delta)
		if item.position.x > 660.0:
			ingredient_container.remove_child(item)
			item.queue_free()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"add_ingredient") or rules.game_over:
		return
	if event is InputEventKey and event.echo:
		return
	if rules.finished:
		if restart_delay == 0.0:
			start_round()
		return
	select_ingredient()

func _next_kind() -> StringName:
	if bag.is_empty():
		bag.assign([&"orange", &"soda", &"orange", &"soda"])
		if distractors_enabled:
			bag.append(&"cherry")
			bag.append(&"cherry")
		bag.shuffle()
	return bag.pop_back()

func _spawn_ingredient(kind: StringName) -> Node2D:
	var item: Node2D = INGREDIENT_SCENE.instantiate()
	ingredient_container.add_child(item)
	item.configure(kind, textures[kind], ingredient_speed)
	item.position = Vector2(12.0, TRACK_Y)
	return item

func select_ingredient() -> void:
	if rules.finished:
		return
	var candidate: Node2D = null
	var nearest: float = INF
	for item in ingredient_container.get_children():
		var distance: float = absf(item.position.x - hit_center)
		if distance <= hit_width * 0.5 and distance < nearest:
			candidate = item
			nearest = distance
	if candidate == null:
		return
	var kind: StringName = candidate.kind
	var outcome: int = rules.select(kind)
	ingredient_container.remove_child(candidate)
	candidate.queue_free()
	if outcome == Rules.Selection.GAME_OVER:
		_clear_ingredients()
		print("ALPHA_GAME_OVER: selected two wrong ingredients; quitting")
		exit_requested.emit()
		if quit_on_game_over:
			get_tree().quit()
		return
	if outcome == Rules.Selection.MISTAKE:
		# Anger expression is intentionally left for the next design discussion.
		return
	if outcome != Rules.Selection.CORRECT:
		return
	_show_in_cup(kind)
	if rules.finished:
		_show_result()

func _show_in_cup(kind: StringName) -> void:
	if kind == &"soda":
		liquid.visible = true
		liquid.color = Color("9ecde0")
		if rules.selected.has(&"orange"):
			liquid.color = Color("f6b34a")
		return
	if rules.selected.has(&"soda"):
		liquid.color = Color("f6b34a")
	var fruit := TextureRect.new()
	fruit.name = "Orange"
	fruit.texture = textures[kind]
	fruit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fruit.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fruit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fruit.position = Vector2(14.0, 53.0)
	fruit.size = Vector2(24.0, 24.0)
	fruit_container.add_child(fruit)

func _show_result() -> void:
	_clear_ingredients()
	result_panel.visible = true
	restart_delay = 0.4
	result_title.text = "Order ready!" if rules.is_success() else "Time's up!"
	print("ALPHA_CUP selected=%s mistakes=%d success=%s" % [rules.selected, rules.mistakes, rules.is_success()])

func _moving_hit_zone(delta: float) -> void:
	var min_center := TRACK_LEFT + hit_width * 0.5
	var max_center := TRACK_RIGHT - hit_width * 0.5

	hit_center += hit_zone_direction * hit_zone_speed * delta
	
	if hit_center <= min_center:
		hit_center = min_center
		hit_zone_direction = 1.0
		hit_zone_speed = randf_range(140.0, 300.0)
	elif hit_center >= max_center:
		hit_center = max_center
		hit_zone_direction = -1.0
		hit_zone_speed = randf_range(140.0, 300.0)
		
	hit_zone.position = Vector2(hit_center - hit_width * 0.5, 198.0)

func _clear_ingredients() -> void:
	for item in ingredient_container.get_children():
		ingredient_container.remove_child(item)
		item.queue_free()
