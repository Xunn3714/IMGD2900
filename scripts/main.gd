extends Control
## Space is the only gameplay key.
signal exit_requested
const Rules = preload("res://scripts/round_rules.gd")
const INGREDIENT_SCENE: PackedScene = preload("res://scenes/ingredient.tscn")
const TRACK_LEFT: float = 32.0
const TRACK_RIGHT: float = 608.0
const TRACK_Y: float = 226.0
const SELECTION_SLOT_START := Vector2(426.0, 270.0)
const SELECTION_SLOT_SIZE := Vector2(44.0, 66.0)
const SELECTION_SLOT_GAP: float = 6.0

@export_group("Playtest tuning")
@export_range(60.0, 240.0, 5.0) var ingredient_speed: float = 120.0
@export_range(0.0, 40.0, 1.0) var speed_increase_per_round: float = 12.0
@export_range(120.0, 300.0, 6.0) var max_ingredient_speed: float = 216.0
@export_range(0.8, 3.0, 0.1) var spawn_interval: float = 1.5
@export_range(32.0, 120.0, 8.0) var hit_width: float = 64.0
@export_range(0.0, 16.0, 1.0) var hit_tolerance: float = 4.0
@export_range(15.0, 120.0, 5.0) var round_duration: float = 45.0
@export var distractors_enabled: bool = true

@export_group("Replaceable artwork")
@export var customer_art: Texture2D = preload("res://icon.svg")
@export var empty_cup_art: Texture2D = preload("res://art/drinks/empty_cup.png")
@export var orange_art: Texture2D = preload("res://art/drinks/orange.png")
@export var soda_art: Texture2D = preload("res://art/drinks/soda_base.png")
@export var cherry_art: Texture2D = preload("res://art/drinks/cherry.png")
@export var blueberry_art: Texture2D = preload("res://art/drinks/blueberry.png")
@export var strawberry_art: Texture2D = preload("res://art/drinks/strawberry.png")
@export var grape_art: Texture2D = preload("res://art/drinks/grape.png")
@export var soda_liquid_art: Texture2D = preload("res://art/drinks/soda_liquid.png")
@export var orange_soda_art: Texture2D = preload("res://art/drinks/orange_soda.png")
@export var blueberry_soda_art: Texture2D = preload("res://art/drinks/blueberry_soda.png")
@export var strawberry_soda_art: Texture2D = preload("res://art/drinks/strawberry_soda.png")
@export var grape_soda_art: Texture2D = preload("res://art/drinks/grape_soda.png")
@export var orange_syrup_art: Texture2D = preload("res://art/drinks/orange_syrup.png")
@export var blueberry_syrup_art: Texture2D = preload("res://art/drinks/blueberry_syrup.png")
@export var strawberry_syrup_art: Texture2D = preload("res://art/drinks/strawberry_syrup.png")
@export var grape_syrup_art: Texture2D = preload("res://art/drinks/grape_syrup.png")
@export var cherry_syrup_art: Texture2D = preload("res://art/drinks/cherry_syrup.png")

@onready var hit_zone: ColorRect = $Track/HitZone
@onready var ingredient_container: Node2D = $Track/Clip/Ingredients
@onready var drink: TextureRect = $Cup/Drink
@onready var fruit_container: Control = $Cup/Fruits
@onready var order_image: TextureRect = $CustomerWindow/OrderBubble/DrinkImage
@onready var selection_slots: Array[TextureRect] = [$SelectedIngredients/Slot1, $SelectedIngredients/Slot2, $SelectedIngredients/Slot3]
@onready var timer_label: Label = $TimeRemaining
@onready var result_panel: Panel = $Result
@onready var result_title: Label = $Result/Title

var hit_center: float = 484.0
var hit_zone_speed: float = 110.0
var hit_zone_direction: float = 1.0
var rules = Rules.new()
var textures: Dictionary = {}
var finished_drinks: Dictionary = {}
var selection_icons: Dictionary = {}
var order_fruits: Array[StringName] = [&"orange", &"blueberry", &"strawberry", &"grape"]
var current_fruit: StringName = &""
var displayed_choice_count: int = 0
var bag: Array[StringName] = []
var rounds_started: int = 0
var current_ingredient_speed: float = 120.0
var non_soda_spawn_streak: int = 0
var spawn_elapsed: float = 0.0
var elapsed: float = 0.0
var restart_delay: float = 0.0
# Test scripts intercept exit_requested; normal gameplay closes immediately.
var quit_on_game_over: bool = true

func _ready() -> void:
	$CustomerWindow/Customer.texture = customer_art
	_setup_cup_art()
	_setup_selection_slots()
	textures = {
		&"orange": orange_art, &"blueberry": blueberry_art,
		&"strawberry": strawberry_art, &"grape": grape_art,
		&"soda": soda_art, &"cherry": cherry_art,
	}
	finished_drinks = {
		&"orange": orange_soda_art, &"blueberry": blueberry_soda_art,
		&"strawberry": strawberry_soda_art, &"grape": grape_soda_art,
	}
	selection_icons = {
		&"orange": orange_syrup_art, &"blueberry": blueberry_syrup_art,
		&"strawberry": strawberry_syrup_art, &"grape": grape_syrup_art,
		&"cherry": cherry_syrup_art, &"soda": soda_art,
	}
	_randomize_hit_zone_speed()
	hit_zone_direction = 1.0 if randf() < 0.5 else -1.0
	hit_zone.position = Vector2(hit_center - hit_width * 0.5, 198.0)
	hit_zone.size = Vector2(hit_width, 56.0)
	start_round()

func _setup_cup_art() -> void:
	var cup: Control = $Cup
	if cup is Panel:
		cup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var empty_cup: TextureRect = cup.get_node_or_null("EmptyCup") as TextureRect
	if empty_cup == null:
		empty_cup = TextureRect.new()
		empty_cup.name = "EmptyCup"
		cup.add_child(empty_cup)
		cup.move_child(empty_cup, 0)
	empty_cup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	empty_cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_cup.texture = empty_cup_art
	empty_cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	empty_cup.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	empty_cup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_selection_slots() -> void:
	for index in selection_slots.size():
		selection_slots[index].position = Vector2(
			SELECTION_SLOT_START.x + index * (SELECTION_SLOT_SIZE.x + SELECTION_SLOT_GAP),
			SELECTION_SLOT_START.y
		)
		selection_slots[index].size = SELECTION_SLOT_SIZE

func start_round() -> void:
	if rules.game_over:
		return
	current_ingredient_speed = _ingredient_speed_for_round(rounds_started)
	rounds_started += 1
	_clear_ingredients()
	for child in fruit_container.get_children():
		fruit_container.remove_child(child)
		child.queue_free()
	var available_orders: Array[StringName] = order_fruits.duplicate()
	available_orders.erase(current_fruit)
	current_fruit = available_orders.pick_random()
	rules.start_cup(current_fruit)
	order_image.texture = finished_drinks[current_fruit]
	for slot in selection_slots:
		slot.texture = null
		slot.visible = false
	displayed_choice_count = 0
	bag.clear()
	non_soda_spawn_streak = 0
	spawn_elapsed = 0.0
	elapsed = 0.0
	hit_width = 64.0
	restart_delay = 0.0
	drink.visible = false
	result_panel.visible = false
	timer_label.text = "%ds" % ceili(round_duration)
	_spawn_ingredient(_next_kind())

func _ingredient_speed_for_round(round_index: int) -> float:
	return minf(ingredient_speed + round_index * speed_increase_per_round, max_ingredient_speed)

func _process(delta: float) -> void:
	if rules.finished:
		restart_delay = maxf(0.0, restart_delay - delta)
		return
	elapsed += delta

	# 0 is the start of the round 1 is the end 
	var round_length: float = clampf(elapsed / round_duration, 0.0, 1.0)
	
	var shrinking: float = clampf(round_length / 0.25, 0.0, 1.0)
	var bounce: float = absf(sin(elapsed * 8.0)) * 4.0

	hit_width = lerpf(64.0, 32.0, shrinking) + bounce
	hit_zone.size.x = hit_width
	_moving_hit_zone(delta)

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
	if not event.is_action_pressed(&"add_ingredient"):
		return
	if event is InputEventKey and event.echo:
		return
	if rules.game_over:
		if restart_delay == 0.0:
			rules.game_over = false
			start_round()
		return
	if rules.finished:
		if restart_delay == 0.0:
			start_round()
		return
	select_ingredient()

func _next_kind() -> StringName:
	if bag.is_empty():
		bag.assign([current_fruit, current_fruit, &"soda", &"soda", &"soda", &"soda"])
		if distractors_enabled:
			for fruit in order_fruits:
				if fruit != current_fruit:
					bag.append(fruit)
			bag.append(&"cherry")
		bag.shuffle()
	var kind: StringName
	if non_soda_spawn_streak >= 2:
		var soda_index: int = bag.find(&"soda")
		kind = bag.pop_at(soda_index) if soda_index >= 0 else &"soda"
	else:
		kind = bag.pop_back()
	if kind == &"soda":
		non_soda_spawn_streak = 0
	else:
		non_soda_spawn_streak += 1
	return kind

func _spawn_ingredient(kind: StringName) -> Node2D:
	var item: Node2D = INGREDIENT_SCENE.instantiate()
	ingredient_container.add_child(item)
	item.configure(kind, textures[kind], current_ingredient_speed)
	item.position = Vector2(12.0, TRACK_Y)
	return item

func select_ingredient() -> void:
	if rules.finished:
		return
	var candidate: Node2D = null
	var nearest: float = INF
	for item in ingredient_container.get_children():
		var distance: float = absf(item.position.x - hit_center)
		if _ingredient_overlaps_hit_zone(item) and distance < nearest:
			candidate = item
			nearest = distance
	if candidate == null:
		return
	var kind: StringName = candidate.kind
	var outcome: int = rules.select(kind)
	ingredient_container.remove_child(candidate)
	candidate.queue_free()
	_show_selected_icon(kind)
	if outcome == Rules.Selection.GAME_OVER:
		_clear_ingredients()
		result_panel.visible = true
		result_title.text = "Too many mistakes! Restart?"
		text_fit_result_panel()
		restart_delay = 0.5
		return
	if outcome == Rules.Selection.MISTAKE:
		# Anger expression is intentionally left for the next design discussion.
		return
	if outcome != Rules.Selection.CORRECT:
		return
	_show_in_cup(kind)
	if rules.finished:
		_show_result()

func _ingredient_overlaps_hit_zone(item: Node2D) -> bool:
	var visual: Sprite2D = item.get_node_or_null("Visual") as Sprite2D
	var ingredient_half_width: float = 0.0
	if visual != null and visual.texture != null:
		ingredient_half_width = visual.texture.get_width() * absf(visual.scale.x) * 0.5
	var zone_left: float = hit_center - hit_width * 0.5 - hit_tolerance
	var zone_right: float = hit_center + hit_width * 0.5 + hit_tolerance
	var ingredient_left: float = item.position.x - ingredient_half_width
	var ingredient_right: float = item.position.x + ingredient_half_width
	return ingredient_right >= zone_left and ingredient_left <= zone_right

func _show_in_cup(kind: StringName) -> void:
	if kind == &"soda":
		drink.texture = finished_drinks[current_fruit] if rules.selected.has(current_fruit) else soda_liquid_art
		drink.visible = true
		return
	if rules.selected.has(&"soda"):
		drink.texture = finished_drinks[current_fruit]
		drink.visible = true

func _show_selected_icon(kind: StringName) -> void:
	if displayed_choice_count >= selection_slots.size() or not selection_icons.has(kind):
		return
	selection_slots[displayed_choice_count].texture = selection_icons[kind]
	selection_slots[displayed_choice_count].visible = true
	displayed_choice_count += 1

func _show_result() -> void:
	_clear_ingredients()
	result_panel.visible = true
	restart_delay = 0.4
	result_title.text = "Order ready!" if rules.is_success() else "Time's up!"
	text_fit_result_panel()
	print("ALPHA_CUP selected=%s mistakes=%d success=%s" % [rules.selected, rules.mistakes, rules.is_success()])

func _moving_hit_zone(delta: float) -> void:
	var min_center := TRACK_LEFT + hit_width * 0.5
	var max_center := TRACK_RIGHT - hit_width * 0.5

	hit_center += hit_zone_direction * hit_zone_speed * delta
	
	if hit_center <= min_center:
		hit_center = min_center
		hit_zone_direction = 1.0
		_randomize_hit_zone_speed()
	elif hit_center >= max_center:
		hit_center = max_center
		hit_zone_direction = -1.0
		_randomize_hit_zone_speed()
		
	hit_zone.position = Vector2(hit_center - hit_width * 0.5, 198.0)

func _randomize_hit_zone_speed() -> void:
	var round_length: float = clampf(elapsed / round_duration, 0.0, 1.0)
	var min_speed: float = lerpf(220.0, 360.0, round_length)
	var max_speed: float = lerpf(320.0, 460.0, round_length)
	hit_zone_speed = randf_range(min_speed, max_speed)

func text_fit_result_panel() -> void:
	result_title.reset_size()
	var title_width: float = result_title.get_minimum_size().x
	result_panel.size.x = title_width + 20.0
	result_panel.position.x = 32

func _clear_ingredients() -> void:
	for item in ingredient_container.get_children():
		ingredient_container.remove_child(item)
		item.queue_free()
