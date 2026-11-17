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
	{"title": "Entrance Week", "body": "The First Bell is silent. Land one cut and one spark on the Yard practice post. The grounds stay open."},
	{"title": "The Two Desks", "body": "Hen keeps a soldier desk and a caster desk. Choose either. Neither puts an art down. Then cut while the spark rides the blade."},
	{"title": "The Library That Remembers", "body": "Quill opens a book only after its stamp. Read The Wooden Sparrow. Glass Needle, Choir Hammer, Lantern Saber, Answer, and Night Ink wait on their own stamps."},
	{"title": "Names on the Stair", "body": "Clear a Proving Hall course. Your best time is the name on the stair. Extra attempts do not buy a higher score."},
	{"title": "The Vote", "body": "Captain Ross calls the vote to split the school. Win a duel, Even or Open. The vote keeps sword and spell together. The fields stay open."},
	{"title": "Ring the Bell", "body": "Win an Open Match. The banner shows your hunt rank and weapon. The bell rings in the Yard. The East Gate stays shut."},
]

const STAMP_IDS := ["cut", "guard", "spark", "spellcut", "guardcast"]
const BOOKS := [
	{"id": "sparrow", "title": "The Wooden Sparrow", "stamp": "spellcut", "kind": "skill", "line": "Hop Cut. Your step carries the blade."},
	{"id": "needle", "title": "Glass Needle", "stamp": "guard", "kind": "weapon", "line": "A long piercing blade. Hunt rank still sets the hit."},
	{"id": "hammer", "title": "Choir Hammer", "stamp": "cut", "kind": "weapon", "line": "A wide, heavy forge hammer."},
	{"id": "lantern", "title": "Lantern Saber", "stamp": "spark", "kind": "weapon", "line": "A bright saber. The spark rides wider."},
	{"id": "answer", "title": "Answer", "stamp": "guardcast", "kind": "skill", "line": "After a guard, the next cut reaches farther."},
	{"id": "ink", "title": "Night Ink", "stamp": "all", "kind": "weapon", "line": "A dark blade. The cut leaves a second gold edge."},
]
const HALL_TITLES := ["First Landing", "The Pairing", "Outer Landing"]
const HALL_BLURBS := [
	"Three constructs. Your best time is the score.",
	"Three constructs. Bring the cut and the spark together.",
	"Four constructs. A longer run for a long visit.",
]

var place: Place = Place.YARD
var hunt_rank := 1
var ore := 0
var shards := 0
var spellcut := false
var hop_cut := false
var best_hall_time := -1.0
var best_hall: Array = [-1.0, -1.0, -1.0]
var hall_attempts: Array = [0, 0, 0]
var hall_course := 0
var court_mode := "even"
var court_live := false
var chapters_done: Array = [false, false, false, false, false, false]
var stick := Vector2.ZERO
var hit_dummy_sword := false
var hit_dummy_spell := false
var stamps := {
	"cut": false,
	"guard": false,
	"spark": false,
	"spellcut": false,
	"guardcast": false,
}
var books := {
	"sparrow": false,
	"needle": false,
	"hammer": false,
	"lantern": false,
	"answer": false,
	"ink": false,
}
var weapon := "academy"
var bias := ""
var paired := false
var even_wins := 0
var open_wins := 0
var even_title := ""
var open_title := ""
var hall_title := ""
var title := ""
var ribbon := ""
var pose := "ready"
var spirit_line := ""
var hint := ""
var bell_pending := false
var bell_rung_once := false
var last_mode := ""
var last_rank := 1
var last_weapon := ""
var rested := 0
var last_day := 0
var season_id := -1
var season_number := 1
var skip_left := 1
var intro_seen := false
var circuit_flags: Array = []
var circuit_clears := 0
var boot_lines: PackedStringArray = PackedStringArray()

signal changed
signal traveled(id)
signal toast(message: String)
signal ask_forge

func _ready() -> void:
	_bind_keys()
	_load()
	_boot()

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

func _boot() -> void:
	var season_msg := _apply_season()
	var rested_msg := _roll_rested()
	_refresh_titles(false)
	if season_msg != "":
		boot_lines.append(season_msg)
	if rested_msg != "":
		boot_lines.append(rested_msg)
	if not intro_seen:
		intro_seen = true
		boot_lines.append("The Yard is open. The First Bell is silent. Sword and spell stay together.")
	_save()

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
		Place.YARD: return "Upgrade"
		Place.GARDEN: return "Fight and gather"
		Place.UNDERCROFT: return "Elites and better ore"
		Place.WASTES: return "Long hunts and a boss"
		Place.COURT: return "Even or open duel"
		Place.HALL: return "Skill course"
		Place.CLASSROOM: return "Lesson"
		Place.LIBRARY: return "New weapons"
		Place.GATE: return "Special event only"
	return ""

func place_swatch(id: Place) -> Array:
	match id:
		Place.YARD: return [Color("85c1e0"), Color("7ec48a")]
		Place.GARDEN: return [Color("85c1e0"), Color("57af70")]
		Place.UNDERCROFT: return [Color("6f8ea3"), Color("7d8b96")]
		Place.WASTES: return [Color("f0b27a"), Color("d2a15a")]
		Place.COURT: return [Color("6e5848"), Color("8d6a45")]
		Place.HALL: return [Color("cbbfa8"), Color("b7aa96")]
		Place.CLASSROOM: return [Color("d5eef8"), Color("f0e2c4")]
		Place.LIBRARY: return [Color("e7d3a8"), Color("c8b48a")]
		Place.GATE: return [Color("6f8ea3"), Color("2e4048")]
	return [Color("85c1e0"), Color("cbbe9e")]

func is_locked(id: Place) -> bool:
	return id == Place.GATE

func lock_reason(_id: Place) -> String:
	return "East Gate is closed today."

func is_battle_music(id: Place) -> bool:
	return id == Place.COURT or id == Place.HALL

func normalized() -> bool:
	if place == Place.HALL:
		return true
	if place == Place.COURT or Online.active:
		return court_mode != "open"
	return false

func hunt_damage() -> float:
	# Monster power is hunt rank alone. Titles, ribbons, and poses are not in this number.
	return 8.0 + float(hunt_rank - 1) * 4.0

func even_damage() -> float:
	return 12.0

func outgoing(heavy: bool) -> float:
	var amount := even_damage() if normalized() else hunt_damage()
	if not heavy:
		amount *= 0.9
	return amount

func spirit_against_monsters(amount: float) -> float:
	if normalized():
		return amount
	return amount * (1.0 + float(hunt_rank - 1) * 0.12)

func shape_active() -> bool:
	return not normalized()

func book_active(id: String) -> bool:
	return has_book(id) and not normalized()

func weapon_label(id: String) -> String:
	match id:
		"needle": return "Glass Needle"
		"hammer": return "Choir Hammer"
		"lantern": return "Lantern Saber"
		"ink": return "Night Ink"
		_: return "Academy Blade"

func weapon_name() -> String:
	return weapon_label(weapon)

func weapon_color() -> Color:
	var blend := clampf(float(hunt_rank - 1) / 8.0, 0.0, 1.0)
	match weapon:
		"needle": return Color("d5f0ff")
		"hammer": return Color("d4a054").lerp(Color("ffe08a"), blend)
		"lantern": return Color("ffe08a")
		"ink": return Color("8aa0ad").lerp(Color("e2c56a"), 0.55)
		_: return Color("d4a054").lerp(Color("ffe08a"), blend)

func weapon_reach() -> float:
	if not shape_active():
		return 2.35
	match weapon:
		"needle": return 3.15
		"hammer": return 2.0
		"lantern": return 2.5
		"ink": return 2.45
		_: return 2.35

func weapon_arc() -> float:
	if not shape_active():
		return 0.25
	match weapon:
		"needle": return 0.55
		"hammer": return -0.2
		_: return 0.25

func owned_weapons() -> Array:
	var list: Array = ["academy"]
	for id in ["needle", "hammer", "lantern", "ink"]:
		if has_book(id):
			list.append(id)
	return list

func ore_cost() -> int:
	return 4 + hunt_rank * 2

func shard_cost() -> int:
	return 1 + int((hunt_rank - 1) / 2)

func upgrade_cost() -> int:
	return ore_cost()

func try_upgrade() -> bool:
	var ore_need := ore_cost()
	var shard_need := shard_cost()
	if ore < ore_need or shards < shard_need:
		toast.emit("Need %d ore and %d shards. You have %d ore and %d shards." % [ore_need, shard_need, ore, shards])
		return false
	ore -= ore_need
	shards -= shard_need
	hunt_rank += 1
	toast.emit("Hunt rank %d. The blade takes more ornament. Monsters feel it. Even Match does not." % hunt_rank)
	changed.emit()
	_save()
	return true

func grant_ore(amount: int, announce: bool) -> void:
	ore += amount
	changed.emit()
	_save()
	if announce:
		toast.emit("Ore +%d" % amount)

func grant_shard(amount: int, announce: bool) -> void:
	shards += amount
	changed.emit()
	_save()
	if announce:
		toast.emit("Shards +%d" % amount)

func grant_loot(ore_n: int, shard_n: int) -> void:
	ore += ore_n
	shards += shard_n
	changed.emit()
	_save()
	var parts: PackedStringArray = PackedStringArray()
	if ore_n > 0:
		parts.append("Ore +%d" % ore_n)
	if shard_n > 0:
		parts.append("Shards +%d" % shard_n)
	if parts.size() > 0:
		toast.emit(" ".join(parts))

func travel(id: Place) -> void:
	if is_locked(id):
		toast.emit(lock_reason(id))
		return
	if Online.active and id != Place.COURT:
		toast.emit("Finish the online match before leaving the court.")
		return
	court_live = false
	place = id
	traveled.emit(id)
	changed.emit()

func has_stamp(id: String) -> bool:
	return bool(stamps.get(id, false))

func stamp_name(id: String) -> String:
	match id:
		"cut": return "Cut"
		"guard": return "Guard"
		"spark": return "Spark"
		"spellcut": return "Spellcut"
		"guardcast": return "Guardcast"
		_: return id

func stamp(id: String, quiet := false) -> void:
	if not stamps.has(id):
		return
	if bool(stamps[id]):
		if not quiet:
			toast.emit("%s is already in the handbook. The fields stay open." % stamp_name(id))
		return
	stamps[id] = true
	_sync_flags()
	toast.emit("Handbook: %s stamped." % stamp_name(id))
	changed.emit()
	_save()

func stamp_lesson() -> void:
	stamp("spellcut")

func next_lesson() -> String:
	for id in STAMP_IDS:
		if not has_stamp(id):
			return id
	return ""

func handbook_line() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id in STAMP_IDS:
		parts.append("%s %s" % [stamp_name(id), "stamped" if has_stamp(id) else "open"])
	return "Handbook: " + ", ".join(parts)

func _book_def(id: String) -> Dictionary:
	for info in BOOKS:
		if str(info["id"]) == id:
			return info
	return {}

func book_ready(id: String) -> bool:
	var info := _book_def(id)
	if info.is_empty():
		return false
	return _stamp_opens(info) or has_book(id)

func _stamp_opens(info: Dictionary) -> bool:
	if str(info["stamp"]) == "all":
		for id in STAMP_IDS:
			if not has_stamp(id):
				return false
		return true
	return has_stamp(str(info["stamp"]))

func book_lock_line(info: Dictionary) -> String:
	if str(info["stamp"]) == "all":
		return "Opens after Cut, Guard, Spark, Spellcut, and Guardcast are stamped."
	return "Opens after the %s stamp." % stamp_name(str(info["stamp"]))

func has_book(id: String) -> bool:
	return bool(books.get(id, false))

func read_book(id := "sparrow") -> void:
	var info := _book_def(id)
	if info.is_empty():
		return
	if not _stamp_opens(info):
		toast.emit("%s is shut. %s" % [str(info["title"]), book_lock_line(info)])
		return
	if has_book(id):
		if str(info["kind"]) == "weapon":
			equip(id)
		else:
			toast.emit("%s is already yours. %s" % [str(info["title"]), str(info["line"])])
		return
	books[id] = true
	if str(info["kind"]) == "weapon":
		weapon = id
	_sync_flags()
	toast.emit("Learned %s. %s" % [str(info["title"]), str(info["line"])])
	if id == "sparrow":
		mark_chapter(2)
	changed.emit()
	_save()

func equip(id: String) -> void:
	if id != "academy" and not has_book(id):
		toast.emit("That weapon is still in the library.")
		return
	weapon = id
	toast.emit("%s is in your hand. Hunt rank still sets the power." % weapon_name())
	changed.emit()
	_save()

func choose_bias(which: String) -> void:
	if which != "soldier" and which != "caster":
		return
	bias = which
	if which == "soldier":
		toast.emit("Soldier desk. Guard lingers a little longer. The spark stays in your hand.")
	else:
		toast.emit("Caster desk. The spark lingers a little longer. The cut stays in your hand.")
	_try_desks()
	changed.emit()
	_save()

func next_book_hint() -> String:
	for info in BOOKS:
		if has_book(str(info["id"])):
			continue
		if _stamp_opens(info):
			return "Quill can open %s." % str(info["title"])
		return "%s %s" % [str(info["title"]), book_lock_line(info)]
	return "The practice post still takes a cut and a spark."

func note_dummy_hit(kind_name: String) -> void:
	_note_kinds(kind_name)
	if kind_name == "sword" or kind_name == "empower" or kind_name == "guardcast" or kind_name == "ink":
		hit_dummy_sword = true
	if kind_name == "spell" or kind_name == "empower" or kind_name == "guardcast":
		hit_dummy_spell = true
	if hit_dummy_sword and hit_dummy_spell:
		mark_chapter(0)
	_save()

func note_fight(kind_name: String) -> void:
	_note_kinds(kind_name)

func _note_kinds(kind_name: String) -> void:
	if kind_name == "sword" or kind_name == "empower" or kind_name == "guardcast" or kind_name == "ink":
		stamp("cut", true)
	if kind_name == "spell" or kind_name == "empower" or kind_name == "guardcast":
		stamp("spark", true)
	if kind_name == "guardcast":
		stamp("guardcast", true)
	if kind_name == "empower":
		note_empower()

func note_guard() -> void:
	stamp("guard", true)

func note_empower() -> void:
	var already := paired
	paired = true
	if _try_desks():
		_save()
		return
	if not already and bias == "":
		toast.emit("Spellcut landed. Pick either desk. Both arts stay.")
		_save()

func _try_desks() -> bool:
	if chapters_done[1]:
		return false
	if paired and bias != "" and has_stamp("spellcut"):
		mark_chapter(1)
		return true
	return false

func note_attempt(course: int) -> void:
	course = clampi(course, 0, 2)
	hall_attempts[course] = int(hall_attempts[course]) + 1
	changed.emit()
	_save()

func note_hall(time: float) -> void:
	var course := clampi(hall_course, 0, 2)
	var prior := float(best_hall[course])
	var fresh := prior < 0.0 or time < prior
	if fresh:
		best_hall[course] = time
	if course == 0:
		best_hall_time = float(best_hall[0])
	mark_chapter(3, false)
	var cheer := _refresh_titles(true)
	var best_now := float(best_hall[course])
	var line := ""
	if fresh:
		line = "Best run %.1fs on %s. Your name is cut into the stair." % [time, HALL_TITLES[course]]
	else:
		line = "Cleared in %.1fs. Best remains %.1fs." % [time, best_now]
	line += " Attempts: %d. Extra attempts do not buy the score. %s" % [int(hall_attempts[course]), rival_line("hall", course)]
	if cheer != "":
		line += " " + cheer
	toast.emit(line)
	changed.emit()
	_save()

func hall_line(course: int) -> String:
	course = clampi(course, 0, 2)
	var best := float(best_hall[course])
	var best_text := "no best yet" if best < 0.0 else "%.1fs" % best
	return "Best %s. Attempts %d. Extra attempts do not buy a higher score." % [best_text, int(hall_attempts[course])]

func note_court(open_mode: bool) -> void:
	var vote_new: bool = not bool(chapters_done[4])
	var bell_new: bool = open_mode and not bool(chapters_done[5])
	if open_mode:
		open_wins += 1
		last_mode = "open"
		last_rank = hunt_rank
		last_weapon = weapon_name()
		mark_chapter(4, false)
		mark_chapter(5, false)
	else:
		even_wins += 1
		last_mode = "even"
		last_rank = 0
		last_weapon = ""
		mark_chapter(4, false)
	var cheer := _refresh_titles(true)
	var board := "open" if open_mode else "even"
	var line := ""
	if open_mode:
		line = "Open Match. Rank %d · %s. %s" % [hunt_rank, weapon_name(), rival_line(board)]
	else:
		line = "Even Match. Crest only. %s" % rival_line(board)
	if vote_new:
		line = "Yearbook: The Vote. Captain Ross keeps the school paired. " + line
	if bell_new:
		line = "Yearbook: Ring the Bell. " + line
	line += " The fields stay open."
	if cheer != "":
		line += " " + cheer
	toast.emit(line)
	changed.emit()
	_save()

func mark_chapter(index: int, announce := true) -> void:
	if index < 0 or index >= chapters_done.size():
		return
	if chapters_done[index]:
		return
	chapters_done[index] = true
	if announce:
		toast.emit("Yearbook: %s" % str(CHAPTERS[index]["title"]))
	changed.emit()
	_save()

func exhibit_line() -> String:
	if last_mode == "open":
		return "Open Match\nRank %d · %s" % [last_rank, last_weapon]
	if last_mode == "even":
		return "Even Match replay\nCrest"
	return "The crystal is quiet"

func address() -> String:
	if title != "":
		return title
	return "student"

func herald_line() -> String:
	if spirit_line != "":
		return spirit_line
	return "The fields are open."

func bell_caption() -> String:
	if bell_rung_once or bell_pending:
		return "The bell rings for the %s." % address()
	return "The First Bell is silent."

func banner_text() -> String:
	if place == Place.HALL:
		return "The Stair\nCrest\n%s" % rival_line("hall", hall_course)
	if place != Place.COURT:
		return ""
	if Online.active or court_live:
		if court_mode == "open":
			return "Open Match\nRank %d · %s\n%s" % [hunt_rank, weapon_name(), rival_line("open")]
		return "Even Match\nCrest\n%s" % rival_line("even")
	return "Even or Open\nGear is not the boast"

func board_rows(board: String, course := 0) -> Array:
	var rows: Array = []
	if board == "open":
		rows.append({"who": "Mira Vale", "score": 3, "detail": "Rank 4 · Academy Blade", "you": false})
		rows.append({"who": "Captain Ross", "score": 2, "detail": "Rank 3 · Academy Blade", "you": false})
		rows.append({"who": "Lute Fenn", "score": 1, "detail": "Rank 2 · Choir Hammer", "you": false})
		rows.append({"who": "You", "score": open_wins, "detail": "Rank %d · %s" % [hunt_rank, weapon_name()], "you": true})
		rows.sort_custom(_sort_high)
	elif board == "hall":
		course = clampi(course, 0, 2)
		var pools := [
			[{"who": "Mira Vale", "score": 22.0}, {"who": "Professor Hen", "score": 27.5}, {"who": "Nia Pell", "score": 33.0}],
			[{"who": "Ivo Brant", "score": 24.0}, {"who": "Archivist Quill", "score": 30.0}, {"who": "Lute Fenn", "score": 36.0}],
			[{"who": "Captain Ross", "score": 26.0}, {"who": "Mira Vale", "score": 31.0}, {"who": "Professor Hen", "score": 37.0}],
		]
		for entry in pools[course]:
			rows.append({"who": entry["who"], "score": entry["score"], "detail": "Crest", "you": false})
		rows.append({"who": "You", "score": float(best_hall[course]), "detail": "Crest", "you": true})
		rows.sort_custom(_sort_time)
	else:
		rows.append({"who": "Ivo Brant", "score": 4, "detail": "Crest", "you": false})
		rows.append({"who": "Mira Vale", "score": 2, "detail": "Crest", "you": false})
		rows.append({"who": "Nia Pell", "score": 1, "detail": "Crest", "you": false})
		rows.append({"who": "You", "score": even_wins, "detail": "Crest", "you": true})
		rows.sort_custom(_sort_high)
	return rows

func rival_name(board: String, course := 0) -> String:
	var rows := board_rows(board, course)
	var you := -1
	for i in rows.size():
		if bool(rows[i]["you"]):
			you = i
			break
	if you <= 0:
		return ""
	return str(rows[you - 1]["who"])

func rival_line(board: String, course := 0) -> String:
	var who := rival_name(board, course)
	if who == "":
		return "You lead this board."
	return "Just above you: %s." % who

func _sort_high(a, b) -> bool:
	if int(a["score"]) == int(b["score"]):
		return bool(b["you"]) and not bool(a["you"])
	return int(a["score"]) > int(b["score"])

func _sort_time(a, b) -> bool:
	var a_score := float(a["score"])
	var b_score := float(b["score"])
	if a_score < 0.0 and b_score < 0.0:
		return false
	if a_score < 0.0:
		return false
	if b_score < 0.0:
		return true
	if is_equal_approx(a_score, b_score):
		return bool(b["you"]) and not bool(a["you"])
	return a_score < b_score

func titles_line() -> String:
	var even_t := even_title if even_title != "" else "none"
	var open_t := open_title if open_title != "" else "none"
	var hall_t := hall_title if hall_title != "" else "none"
	return "Titles. Even: %s. Open: %s. Stair: %s. The yard calls you %s." % [even_t, open_t, hall_t, address()]

func looks_line() -> String:
	return "Ribbon and pose are looks, not damage. Pose: %s. %s" % [pose, next_book_hint() if hint == "" else hint]

func rested_line() -> String:
	return "Rested bank: %d. Missed lesson days wait here. The fields do not punish a missed day, and they do not require one." % rested

func season_line() -> String:
	return "Open season %d. Seasonal skips left: %d. One missed week can keep the Open title. Hunt rank stays." % [season_number, skip_left]

func circuit_line() -> String:
	var found := 0
	for flag in circuit_flags:
		if flag:
			found += 1
	var total := circuit_flags.size() if circuit_flags.size() > 0 else 8
	return "Garden circuit %d/%d. The marked stones are the short visit, a ten-minute walk when you take the fights slowly." % [found, total]

func begin_circuit() -> void:
	circuit_flags = []
	for _i in 8:
		circuit_flags.append(false)

func touch_circuit(index: int) -> void:
	if index < 0 or index >= circuit_flags.size():
		return
	if circuit_flags[index]:
		return
	circuit_flags[index] = true
	var found := 0
	for flag in circuit_flags:
		if flag:
			found += 1
	if found >= circuit_flags.size():
		circuit_clears += 1
		toast.emit("Garden circuit complete. A short visit can end here.")
		_save()
	else:
		toast.emit("Circuit stone %d of %d." % [found, circuit_flags.size()])
	changed.emit()

func spend_rested() -> void:
	if rested <= 0:
		toast.emit("The rested bank is empty. The fields are open either way.")
		return
	rested -= 1
	toast.emit("Hen repeats a drill. %s No extra damage." % next_book_hint())
	changed.emit()
	_save()

func _refresh_titles(celebrate: bool) -> String:
	var old_even := even_title
	var old_open := open_title
	var old_hall := hall_title
	even_title = _even_title_for(even_wins)
	open_title = _open_title_for(open_wins)
	hall_title = _hall_title_for()
	var cheer := ""
	if celebrate and even_title != old_even and even_title != "":
		cheer = _celebrate(even_title, "even")
	if celebrate and open_title != old_open and open_title != "":
		cheer = _celebrate(open_title, "open")
	if celebrate and hall_title != old_hall and hall_title != "":
		cheer = _celebrate(hall_title, "hall")
	_sync_address()
	return cheer

func _even_title_for(wins: int) -> String:
	if wins >= 5:
		return "Silver Ring"
	if wins >= 3:
		return "Even Crest"
	if wins >= 1:
		return "Court Hand"
	return ""

func _open_title_for(wins: int) -> String:
	if wins >= 5:
		return "Gold Ring"
	if wins >= 3:
		return "Hunt Banner"
	if wins >= 1:
		return "Open Blade"
	return ""

func _hall_title_for() -> String:
	var best := -1.0
	for entry in best_hall:
		var time := float(entry)
		if time >= 0.0 and (best < 0.0 or time < best):
			best = time
	if best < 0.0:
		return ""
	if best <= 20.0:
		return "Stair Light"
	return "Named on the Stair"

func _celebrate(title_name: String, source: String) -> String:
	title = title_name
	bell_pending = true
	pose = "low" if source == "hall" else "raised"
	if source == "open":
		ribbon = "e2c56a"
		spirit_line = "The courtyard praises the hunt rank on the banner."
	elif source == "hall":
		ribbon = "8ec8f0"
		spirit_line = "The stair names you. The crest is the boast."
	else:
		ribbon = "d9dde3"
		spirit_line = "The courtyard praises a clean crest."
	hint = next_book_hint()
	return "The yard will ring the bell for the %s. %s %s" % [title_name, spirit_line, hint]

func _sync_address() -> void:
	if title == even_title or title == open_title or title == hall_title:
		return
	if hall_title != "":
		title = hall_title
	elif even_title != "":
		title = even_title
	elif open_title != "":
		title = open_title
	else:
		title = ""

func _apply_season() -> String:
	var now := _week()
	if season_id < 0:
		season_id = now
		return ""
	var gap := now - season_id
	if gap <= 0:
		return ""
	var had_open := open_wins > 0 or open_title != ""
	if gap == 1 and skip_left > 0 and had_open:
		skip_left -= 1
		season_id = now
		season_number += 1
		return "A missed Open week. One seasonal skip keeps your title. Hunt rank is untouched."
	season_id = now
	season_number += maxi(gap, 1)
	if not had_open:
		return ""
	var lost := open_title
	open_wins = 0
	open_title = ""
	if title == lost:
		title = ""
	return "A new Open season. The title resets. Your hunt rank stays on the blade."

func _roll_rested() -> String:
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	if last_day <= 0:
		last_day = today
		return ""
	var missed := today - last_day - 1
	last_day = today
	if missed <= 0:
		return ""
	rested = mini(6, rested + missed)
	return "Rested bank: %d. Missed lesson days wait here. The fields are unchanged." % rested

func _week() -> int:
	return int(Time.get_unix_time_from_system() / (7.0 * 86400.0))

func _sync_flags() -> void:
	spellcut = has_stamp("spellcut")
	hop_cut = has_book("sparrow")

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "hunt_rank", hunt_rank)
	cfg.set_value("p", "ore", ore)
	cfg.set_value("p", "shards", shards)
	cfg.set_value("p", "spellcut", spellcut)
	cfg.set_value("p", "hop_cut", hop_cut)
	cfg.set_value("p", "best_hall_time", best_hall_time)
	cfg.set_value("p", "hall_times", best_hall)
	cfg.set_value("p", "hall_attempts", hall_attempts)
	cfg.set_value("p", "chapters", chapters_done)
	cfg.set_value("p", "sword", hit_dummy_sword)
	cfg.set_value("p", "spark", hit_dummy_spell)
	cfg.set_value("p", "weapon", weapon)
	cfg.set_value("p", "bias", bias)
	cfg.set_value("p", "paired", paired)
	cfg.set_value("p", "even_wins", even_wins)
	cfg.set_value("p", "open_wins", open_wins)
	cfg.set_value("p", "title", title)
	cfg.set_value("p", "ribbon", ribbon)
	cfg.set_value("p", "pose", pose)
	cfg.set_value("p", "spirit_line", spirit_line)
	cfg.set_value("p", "hint", hint)
	cfg.set_value("p", "bell_pending", bell_pending)
	cfg.set_value("p", "bell_rung_once", bell_rung_once)
	cfg.set_value("p", "last_mode", last_mode)
	cfg.set_value("p", "last_rank", last_rank)
	cfg.set_value("p", "last_weapon", last_weapon)
	cfg.set_value("p", "rested", rested)
	cfg.set_value("p", "last_day", last_day)
	cfg.set_value("p", "season_id", season_id)
	cfg.set_value("p", "season_number", season_number)
	cfg.set_value("p", "skip_left", skip_left)
	cfg.set_value("p", "intro_seen", intro_seen)
	cfg.set_value("p", "circuit_clears", circuit_clears)
	for id in STAMP_IDS:
		cfg.set_value("p", "stamp_%s" % id, has_stamp(id))
	for id in books.keys():
		cfg.set_value("p", "book_%s" % id, has_book(id))
	cfg.save("user://academy.cfg")

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://academy.cfg") != OK:
		_sync_flags()
		return
	hunt_rank = int(cfg.get_value("p", "hunt_rank", 1))
	ore = int(cfg.get_value("p", "ore", 0))
	shards = int(cfg.get_value("p", "shards", 0))
	hit_dummy_sword = bool(cfg.get_value("p", "sword", false))
	hit_dummy_spell = bool(cfg.get_value("p", "spark", false))
	weapon = str(cfg.get_value("p", "weapon", "academy"))
	bias = str(cfg.get_value("p", "bias", ""))
	paired = bool(cfg.get_value("p", "paired", false))
	even_wins = int(cfg.get_value("p", "even_wins", 0))
	open_wins = int(cfg.get_value("p", "open_wins", 0))
	title = str(cfg.get_value("p", "title", ""))
	ribbon = str(cfg.get_value("p", "ribbon", ""))
	pose = str(cfg.get_value("p", "pose", "ready"))
	spirit_line = str(cfg.get_value("p", "spirit_line", ""))
	hint = str(cfg.get_value("p", "hint", ""))
	bell_pending = bool(cfg.get_value("p", "bell_pending", false))
	bell_rung_once = bool(cfg.get_value("p", "bell_rung_once", false))
	last_mode = str(cfg.get_value("p", "last_mode", ""))
	last_rank = int(cfg.get_value("p", "last_rank", 1))
	last_weapon = str(cfg.get_value("p", "last_weapon", ""))
	rested = int(cfg.get_value("p", "rested", 0))
	last_day = int(cfg.get_value("p", "last_day", 0))
	season_id = int(cfg.get_value("p", "season_id", -1))
	season_number = int(cfg.get_value("p", "season_number", 1))
	skip_left = int(cfg.get_value("p", "skip_left", 1))
	intro_seen = bool(cfg.get_value("p", "intro_seen", false))
	circuit_clears = int(cfg.get_value("p", "circuit_clears", 0))
	for id in STAMP_IDS:
		var fallback = false
		if id == "spellcut":
			fallback = bool(cfg.get_value("p", "spellcut", false))
		stamps[id] = bool(cfg.get_value("p", "stamp_%s" % id, fallback))
	for id in books.keys():
		var fallback_book = false
		if id == "sparrow":
			fallback_book = bool(cfg.get_value("p", "hop_cut", false))
		books[id] = bool(cfg.get_value("p", "book_%s" % id, fallback_book))
	best_hall = [-1.0, -1.0, -1.0]
	hall_attempts = [0, 0, 0]
	var stored_times = cfg.get_value("p", "hall_times", [])
	if stored_times is Array and stored_times.size() >= 3:
		for i in 3:
			best_hall[i] = float(stored_times[i])
	else:
		best_hall[0] = float(cfg.get_value("p", "best_hall_time", -1.0))
	best_hall_time = float(best_hall[0])
	var stored_attempts = cfg.get_value("p", "hall_attempts", [])
	if stored_attempts is Array and stored_attempts.size() >= 3:
		for i in 3:
			hall_attempts[i] = int(stored_attempts[i])
	var stored = cfg.get_value("p", "chapters", chapters_done)
	if stored is Array and stored.size() == 6:
		chapters_done = []
		for entry in stored:
			chapters_done.append(bool(entry))
	if weapon != "academy" and weapon != "needle" and weapon != "hammer" and weapon != "lantern" and weapon != "ink":
		weapon = "academy"
	if pose != "raised" and pose != "low":
		pose = "ready"
	_sync_flags()
