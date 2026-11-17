extends Node

enum Place {
	YARD,
	GARDEN,
	UNDERCROFT,
	WASTES,
	COURT,
	HALL,
	CLASSROOM,
	LIBRARY,
	GATE,
}

const CHAPTERS := [
	{"title": "Entrance Week", "body": "Land one cut and one spark on the practice post in the Yard."},
	{"title": "The Two Desks", "body": "Take the lesson, then cut while the spark still rides the blade."},
	{"title": "The Library That Remembers", "body": "With the lesson stamped, read The Wooden Sparrow."},
	{"title": "Names on the Stair", "body": "Clear the three constructs in the Proving Hall."},
	{"title": "The Vote", "body": "Win a duel in the Court. Even or Open, your choice."},
	{"title": "Ring the Bell", "body": "Win an Open Match, with your real hunt rank on the blade."},
]

var place: Place = Place.YARD
var hunt_rank := 1
var ore := 0
var spellcut := false
var hop_cut := false
var best_hall_time := -1.0
var court_mode := "even"
var chapters_done: Array = [false, false, false, false, false, false]
var stick := Vector2.ZERO
var hit_dummy_sword := false
var hit_dummy_spell := false

signal changed
signal traveled(id)
signal toast(message: String)

func _ready() -> void:
	_bind_keys()
	_load()

func _bind_keys() -> void:
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("move_forward", KEY_UP)
	_key("move_back", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_key("cut", KEY_J)
	_key("spark", KEY_K)
	_key("step", KEY_SPACE)

func _key(action: String, code: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = code
	InputMap.action_add_event(action, event)

func place_name(id: Place) -> String:
	match id:
		Place.YARD: return "Yard"
		Place.GARDEN: return "Wild Garden"
		Place.UNDERCROFT: return "Undercroft"
		Place.WASTES: return "Training Wastes"
		Place.COURT: return "Dueling Court"
		Place.HALL: return "Proving Hall"
		Place.CLASSROOM: return "Classroom"
		Place.LIBRARY: return "Library"
		Place.GATE: return "East Gate"
	return "Yard"

func place_blurb(id: Place) -> String:
	match id:
		Place.YARD: return "Forge bench and practice"
		Place.GARDEN: return "Fight and gather"
		Place.UNDERCROFT: return "Elites and better ore"
		Place.WASTES: return "Long hunts and a boss"
		Place.COURT: return "Even or open duels"
		Place.HALL: return "Timed skill course"
		Place.CLASSROOM: return "Today's lesson"
		Place.LIBRARY: return "A new skill from a book"
		Place.GATE: return "Special event only"
	return ""

func is_locked(id: Place) -> bool:
	return id == Place.GATE

func lock_reason(_id: Place) -> String:
	return "East Gate is closed today"

func is_battle_music(id: Place) -> bool:
	return id == Place.COURT or id == Place.HALL

func hunt_damage() -> float:
	return 8.0 + float(hunt_rank - 1) * 4.0

func even_damage() -> float:
	return 12.0

func outgoing(heavy: bool) -> float:
	var use_even := false
	if place == Place.HALL:
		use_even = true
	elif place == Place.COURT or Online.active:
		use_even = court_mode != "open"
	var amount := even_damage() if use_even else hunt_damage()
	if not heavy:
		amount *= 0.9
	return amount

func upgrade_cost() -> int:
	return 4 + hunt_rank * 2

func try_upgrade() -> bool:
	var cost := upgrade_cost()
	if ore < cost:
		toast.emit("Need %d ore. The grounds drop it." % cost)
		return false
	ore -= cost
	hunt_rank += 1
	toast.emit("Hunt rank %d. The blade takes more ornament." % hunt_rank)
	changed.emit()
	_save()
	return true

func grant_ore(amount: int, announce: bool) -> void:
	ore += amount
	changed.emit()
	_save()
	if announce:
		toast.emit("Ore +%d" % amount)

func travel(id: Place) -> void:
	if is_locked(id):
		toast.emit(lock_reason(id))
		return
	if Online.active and id != Place.COURT:
		toast.emit("Finish the online match before leaving the court.")
		return
	place = id
	traveled.emit(id)
	changed.emit()

func stamp_lesson() -> void:
	spellcut = true
	toast.emit("Spellcut is stamped. Spark, then cut.")
	changed.emit()
	_save()

func read_book() -> void:
	if not spellcut:
		toast.emit("Quill keeps the book shut until the lesson is stamped.")
		return
	if hop_cut:
		toast.emit("The Wooden Sparrow is already yours. Step through a foe.")
		return
	hop_cut = true
	toast.emit("Hop Cut learned. Your step now carries the blade.")
	mark_chapter(2)
	changed.emit()
	_save()

func note_dummy_hit(kind: String) -> void:
	if kind == "sword" or kind == "empower":
		hit_dummy_sword = true
	if kind == "spell" or kind == "empower":
		hit_dummy_spell = true
	if hit_dummy_sword and hit_dummy_spell:
		mark_chapter(0)

func note_empower() -> void:
	if spellcut:
		mark_chapter(1)

func note_hall(time: float) -> void:
	var fresh := best_hall_time < 0.0 or time < best_hall_time
	if fresh:
		best_hall_time = time
	mark_chapter(3)
	if fresh:
		toast.emit("Best run %.1fs. Your name is cut into the stair." % time)
	else:
		toast.emit("Cleared in %.1fs. Best remains %.1fs." % [time, best_hall_time])
	changed.emit()
	_save()

func note_court(open_mode: bool) -> void:
	mark_chapter(4)
	if open_mode:
		mark_chapter(5)
		toast.emit("The bell answers. Open Match is yours.")
	else:
		toast.emit("The Court records the win.")
	changed.emit()
	_save()

func mark_chapter(index: int) -> void:
	if index < 0 or index >= chapters_done.size():
		return
	if chapters_done[index]:
		return
	chapters_done[index] = true
	toast.emit("Yearbook: %s" % str(CHAPTERS[index]["title"]))
	changed.emit()
	_save()

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "hunt_rank", hunt_rank)
	cfg.set_value("p", "ore", ore)
	cfg.set_value("p", "spellcut", spellcut)
	cfg.set_value("p", "hop_cut", hop_cut)
	cfg.set_value("p", "best_hall_time", best_hall_time)
	cfg.set_value("p", "chapters", chapters_done)
	cfg.set_value("p", "sword", hit_dummy_sword)
	cfg.set_value("p", "spark", hit_dummy_spell)
	cfg.save("user://academy.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://academy.cfg") != OK:
		return
	hunt_rank = int(cfg.get_value("p", "hunt_rank", 1))
	ore = int(cfg.get_value("p", "ore", 0))
	spellcut = bool(cfg.get_value("p", "spellcut", false))
	hop_cut = bool(cfg.get_value("p", "hop_cut", false))
	best_hall_time = float(cfg.get_value("p", "best_hall_time", -1.0))
	hit_dummy_sword = bool(cfg.get_value("p", "sword", false))
	hit_dummy_spell = bool(cfg.get_value("p", "spark", false))
	var stored = cfg.get_value("p", "chapters", chapters_done)
	if stored is Array and stored.size() == 6:
		chapters_done = []
		for entry in stored:
			chapters_done.append(bool(entry))
