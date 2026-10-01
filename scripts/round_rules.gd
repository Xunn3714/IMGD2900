extends RefCounted
## Mistakes last for the entire session, even after serving a drink.
enum Selection { IGNORED, CORRECT, MISTAKE, GAME_OVER }
const CAPACITY: int = 2
const MAX_MISTAKES: int = 2
const FRUIT_KINDS: Array[StringName] = [&"orange", &"blueberry", &"strawberry", &"grape"]
const VALID_KINDS: Array[StringName] = [&"orange", &"blueberry", &"strawberry", &"grape", &"soda", &"cherry"]
var selected: Array[StringName] = []
var target_fruit: StringName = &"orange"
var mistakes: int = 0
var finished: bool = false
var timed_out: bool = false
var game_over: bool = false

func start_cup(next_target: StringName = &"orange") -> void:
	if game_over:
		return
	if FRUIT_KINDS.has(next_target):
		target_fruit = next_target
	selected.clear()
	finished = false
	timed_out = false

func select(kind: StringName) -> Selection:
	if finished or game_over or not VALID_KINDS.has(kind):
		return Selection.IGNORED
	if (kind != target_fruit and kind != &"soda") or selected.has(kind):
		mistakes += 1
		if mistakes >= MAX_MISTAKES:
			game_over = true
			finished = true
			return Selection.GAME_OVER
		return Selection.MISTAKE
	selected.append(kind)
	finished = selected.size() == CAPACITY
	return Selection.CORRECT

func expire() -> void:
	if not finished:
		timed_out = true
		finished = true

func is_success() -> bool:
	return finished and not timed_out and not game_over \
		and selected.has(target_fruit) and selected.has(&"soda")
