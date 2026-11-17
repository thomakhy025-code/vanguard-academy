extends Control

var joystick: Control
var knob := Vector2.ZERO
var dragging := false
var finger := -1

var cut_btn: Button
var spark_btn: Button
var step_btn: Button
var place_btn: Button
var rank_btn: Button
var action_btn: Button
var year_btn: Button
var toast_label: Label
var banner_label: Label
var banner_back: ColorRect
var hp_fill: ColorRect
var sheet: Control
var join_field: LineEdit
var story_layer: CanvasLayer
var story: Control
var story_plate: Panel
var story_page: Label
var story_title: Label
var story_body: Label
var story_back: Button
var story_next: Button
var story_begin: Button
var story_index := 0
var pan_pointer := -2
var pan_touch := false

const SCHOOL_STORY: Array[String] = [
	"The First Bell is silent.\nYou enter Vanguard Academy already holding a sword and a spark.\nHere, the two are one art.",
	"Professor Hen teaches from two desks in one room.\nThe lesson is cut, guard, spark, and the moment they meet.\nThat stamp is Spellcut and Guardcast.",
	"Captain Ross at the Iron Desk wants the school to split sword and magic.\nThe vote is still coming.",
	"Archivist Quill keeps new books shut until today's lesson is stamped.\nThe Wooden Sparrow is the first book, and it teaches Hop Cut.",
	"Mira Vale's name is on the stair just above yours.\nThe grounds are open.\nEast Gate is closed today.",
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick = Control.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(joystick)
	joystick.draw.connect(_draw_stick)
	joystick.gui_input.connect(_stick_input)
	cut_btn = _round_button("Cut", Color("3a3328"), Color("e2c56a"))
	spark_btn = _round_button("Spark", Color("243846"), Color("8ec8f0"))
	step_btn = _round_button("Step", Color("2e4048"), Color("f4efe4"))
	place_btn = _plate("Yard")
	rank_btn = _plate("Rank 1")
	action_btn = _plate("Act")
	year_btn = _round_button("Year", Color("2e4048"), Color("e2c56a"))
	cut_btn.pressed.connect(func() -> void: _student_call("cut"))
	spark_btn.pressed.connect(func() -> void: _student_call("cast_spark"))
	step_btn.pressed.connect(func() -> void: _student_call("step_aside"))
	place_btn.pressed.connect(_open_places)
	rank_btn.pressed.connect(_open_rank)
	action_btn.pressed.connect(_open_action)
	year_btn.pressed.connect(_open_yearbook)
	var hp_back := ColorRect.new()
	hp_back.color = Color(0.12, 0.16, 0.18, 0.7)
	hp_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_back.name = "HpBack"
	add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("57af70")
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_back.add_child(hp_fill)
	banner_back = ColorRect.new()
	banner_back.color = Color(0.18, 0.25, 0.28, 0.72)
	banner_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_back)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.add_theme_font_size_override("font_size", 24)
	banner_label.add_theme_color_override("font_color", Color("f7f1e4"))
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_label)
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 24)
	toast_label.add_theme_color_override("font_color", Color("2e4048"))
	toast_label.add_theme_color_override("font_shadow_color", Color("f7f1e4"))
	toast_label.add_theme_constant_override("shadow_offset_x", 2)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	Game.changed.connect(_refresh)
	Game.traveled.connect(func(_id) -> void:
		_close_sheet()
		_refresh()
	)
	Game.toast.connect(_show_toast)
	Game.ask_forge.connect(_open_rank)
	Online.status.connect(_show_toast)
	resized.connect(_layout)
	if Game.boot_lines.size() > 0:
		_show_toast("\n".join(Game.boot_lines))
		Game.boot_lines.clear()
	_refresh()
	call_deferred("_layout")
	_open_story()

func _student_call(method_name: String) -> void:
	var student := _local_student()
	if student and student.has_method(method_name):
		student.call(method_name)

func _local_student() -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_meta("local", false):
			return node
	return null

func _round_button(text: String, fill: Color, edge: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.add_theme_stylebox_override("normal", _box(fill, edge))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), edge))
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("f7f1e4"))
	add_child(button)
	return button

func _plate(text: String) -> Button:
	return _round_button(text, Color("2e4048"), Color("e2c56a"))

func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(5)
	style.set_corner_radius_all(26)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _margins() -> Vector4:
	return _view_margins(size)

func _view_margins(view: Vector2) -> Vector4:
	var edge := 22.0
	var home := 30.0
	var window := DisplayServer.window_get_size()
	if window.x < 40 or window.y < 40 or view.x < 40.0 or view.y < 40.0:
		return Vector4(edge, edge, edge, home)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x < 32 or safe.size.y < 32:
		return Vector4(edge, edge, edge, home)
	var sx := view.x / float(window.x)
	var sy := view.y / float(window.y)
	var left := maxf(edge, float(safe.position.x) * sx)
	var top := maxf(edge, float(safe.position.y) * sy)
	var right := maxf(edge, float(window.x - safe.position.x - safe.size.x) * sx)
	var bottom := maxf(home, float(window.y - safe.position.y - safe.size.y) * sy)
	return Vector4(left, top, right, bottom)

func _layout() -> void:
	var view := size
	if view.x < 20.0:
		return
	var margin := _margins()
	var left := margin.x
	var top := margin.y
	var right := margin.z
	var bottom := margin.w
	var short := minf(view.x, view.y)
	var stick_d := clampf(short * 0.34, 170.0, 300.0)
	joystick.size = Vector2(stick_d, stick_d)
	joystick.position = Vector2(left, view.y - stick_d - bottom)
	joystick.queue_redraw()
	var cut := clampf(short * 0.23, 116.0, 176.0)
	var small := cut * 0.78
	var font := int(clampf(short * 0.04, 20, 32))
	cut_btn.size = Vector2(cut, cut)
	cut_btn.position = Vector2(view.x - cut - right, view.y - cut - bottom)
	spark_btn.size = Vector2(small, small)
	spark_btn.position = Vector2(cut_btn.position.x + (cut - small) * 0.5, cut_btn.position.y - small - 14)
	step_btn.size = Vector2(small, small)
	step_btn.position = Vector2(cut_btn.position.x - small - 14, cut_btn.position.y + (cut - small) * 0.45)
	for button in [cut_btn, spark_btn, step_btn, place_btn, action_btn, year_btn]:
		button.add_theme_font_size_override("font_size", font)
	rank_btn.add_theme_font_size_override("font_size", maxi(18, font - 2))
	var gap := 12.0
	var max_plate := (view.x - left - right - gap) * 0.48
	var plate_w := clampf(minf(view.x * 0.36, max_plate), 150.0, 340.0)
	var plate_h := clampf(short * 0.11, 72.0, 104.0)
	place_btn.size = Vector2(plate_w, plate_h)
	place_btn.position = Vector2(view.x - plate_w - right, top)
	rank_btn.size = Vector2(plate_w, plate_h)
	rank_btn.position = Vector2(left, top)
	var hp_back: ColorRect = get_node("HpBack")
	hp_back.size = Vector2(plate_w, 18)
	hp_back.position = Vector2(left, rank_btn.position.y + plate_h + 8)
	_paint_hp()
	year_btn.size = Vector2(plate_h, plate_h)
	year_btn.position = Vector2(left, hp_back.position.y + hp_back.size.y + 8)
	action_btn.size = Vector2(minf(plate_w * 1.25, view.x * 0.46), plate_h)
	action_btn.position = Vector2(left, year_btn.position.y + plate_h + 8)
	var banner_w := minf(view.x * 0.42, view.x - left - right - plate_w * 2.0 - 24.0)
	banner_w = maxf(banner_w, 120.0)
	banner_back.size = Vector2(banner_w, 96)
	banner_back.position = Vector2((view.x - banner_w) * 0.5, top + plate_h + 8)
	banner_label.size = banner_back.size
	banner_label.position = banner_back.position
	toast_label.size = Vector2(minf(view.x - 48.0, 720.0), 120)
	toast_label.position = Vector2((view.x - toast_label.size.x) * 0.5, banner_back.position.y + 102)
	if sheet and is_instance_valid(sheet) and not sheet.get_meta("sliding", false):
		sheet.position = Vector2(16, 16)
		sheet.size = view - Vector2(32, 32)
	_layout_story()

func _paint_hp() -> void:
	var student := _local_student()
	var ratio := 1.0
	if student:
		ratio = clampf(student.hp / student.max_hp, 0.0, 1.0)
	var back: ColorRect = get_node("HpBack")
	hp_fill.size = Vector2(back.size.x * ratio, back.size.y)
	hp_fill.color = Color("57af70") if ratio > 0.35 else Color("c5764b")

func _process(_delta: float) -> void:
	_paint_hp()

func _refresh() -> void:
	place_btn.text = Game.place_name(Game.place)
	rank_btn.text = "Rank %d\nOre %d · %d shards" % [Game.hunt_rank, Game.ore, Game.shards]
	var edge := Game.weapon_color()
	rank_btn.add_theme_stylebox_override("normal", _box(Color("2e4048"), edge))
	rank_btn.add_theme_stylebox_override("hover", _box(Color("3d5560"), edge))
	rank_btn.add_theme_stylebox_override("pressed", _box(Color("24343b"), edge))
	cut_btn.add_theme_stylebox_override("normal", _box(Color("3a3328"), edge))
	cut_btn.add_theme_stylebox_override("hover", _box(Color("4a4336"), edge))
	cut_btn.add_theme_stylebox_override("pressed", _box(Color("2a241c"), edge))
	action_btn.visible = _action_label() != ""
	action_btn.text = _action_label()
	var banner := Game.banner_text()
	banner_label.text = banner
	banner_label.visible = banner != ""
	banner_back.visible = banner != ""

func _action_label() -> String:
	var pupil := _local_student()
	if pupil != null and str(pupil.get("door_prompt")) != "":
		return str(pupil.get("door_prompt"))
	if Game.is_trial(Game.place):
		var pattern := 0
		var host := get_tree().current_scene
		if host != null and "trial_pattern" in host:
			pattern = int(host.trial_pattern)
		return "Begin · %s" % Game.pattern_label(Game.place, pattern)
	match Game.place:
		Game.Place.GARDEN: return "Forest circuit"
		Game.Place.UNDERCROFT: return "Shards and ore"
		Game.Place.WASTES: return "Deep Wood rings"
		Game.Place.CLASSROOM: return "Today's lesson"
		Game.Place.LIBRARY: return "Open a book"
		Game.Place.HALL: return "Start a course"
		Game.Place.COURT: return "Choose a match"
		_: return ""

func _show_toast(message: String) -> void:
	if toast_label.text == "" or toast_label.text == message:
		toast_label.text = message
	else:
		var previous := toast_label.text.split("\n")[0]
		toast_label.text = message + "\n" + previous

func _open_rank() -> void:
	if Game.place != Game.Place.YARD:
		_show_toast("The forge bench is in the Yard.")
		return
	var notes: Array = [
		"Four strikes on the glowing anvil, in time. A broken rhythm spends nothing.",
		"Hunt rank raises the blade against monsters. Ribbons do not.",
		Game.exhibit_line().replace("\n", " · "),
		"Cost: %d ore and %d shards. You have %d ore and %d shards." % [Game.ore_cost(), Game.shard_cost(), Game.ore, Game.shards],
	]
	var rows: Array = [["Raise hunt rank", _upgrade]]
	for id in Game.owned_weapons():
		var label := "Equip %s" % Game.weapon_label(str(id))
		if str(id) == Game.weapon:
			label = "%s  (in hand)" % Game.weapon_label(str(id))
		rows.append([label, _equip.bind(str(id))])
	_open_sheet("Forge bench", rows, notes)

func _upgrade() -> void:
	Game.arm_anvil()
	_close_sheet()

func _equip(id: String) -> void:
	Game.equip(id)
	_close_sheet()

func _open_action() -> void:
	var pupil := _local_student()
	if pupil != null and str(pupil.get("door_prompt")) != "":
		var spot: Vector3 = pupil.get("prompt_arrive")
		Game.enter_place(int(pupil.get("prompt_to")), spot)
		return
	if Game.is_trial(Game.place):
		var host := get_tree().current_scene
		if host != null and host.has_method("begin_shown_trial"):
			host.begin_shown_trial()
		return
	match Game.place:
		Game.Place.GARDEN:
			_open_sheet("School Forest", [], [Game.circuit_line(), "Packs and ore share the path. A short visit can finish the stones and leave."])
		Game.Place.UNDERCROFT:
			_open_sheet("Undercroft", [], ["Elites drop shards. The nodes here are richer. The bench spends ore and shards. Hunt rank is what the beasts feel."])
		Game.Place.WASTES:
			_open_sheet("Deep Wood", [], ["Inner ring: any hunt rank. Middle ring: made for rank 3. Outer ring and the Warden: made for rank 6. You can walk every ring. The wood does not close."])
		Game.Place.CLASSROOM:
			_open_lesson()
		Game.Place.LIBRARY:
			_open_library()
		Game.Place.HALL:
			_open_hall()
		Game.Place.COURT:
			_open_match_sheet()

func _open_lesson() -> void:
	var notes: Array = [
		"Hen teaches the handbook. Books come after the stamp.",
		Game.rested_line(),
		"Soldier and caster are desks, not locks. Sword and spell stay together.",
	]
	var rows: Array = []
	var today := Game.next_lesson()
	for id in Game.STAMP_IDS:
		var prefix := "Today · " if id == today else ""
		var state := "Stamped" if Game.has_stamp(id) else "Take the lesson"
		rows.append(["%s%s\n%s" % [prefix, Game.stamp_name(id), state], _stamp.bind(id)])
	var soldier := "Chosen · " if Game.bias == "soldier" else ""
	var caster := "Chosen · " if Game.bias == "caster" else ""
	rows.append(["%sSoldier desk\nGuard lingers. The spark stays." % soldier, _bias.bind("soldier")])
	rows.append(["%sCaster desk\nSpark lingers. The cut stays." % caster, _bias.bind("caster")])
	if Game.rested > 0:
		rows.append(["Spend one rested day\nA drill and a hint. No extra damage.", _spend_rested])
	_open_sheet("Professor Hen", rows, notes)

func _stamp(id: String) -> void:
	Game.stamp(id)
	_close_sheet()

func _bias(which: String) -> void:
	Game.choose_bias(which)
	_close_sheet()

func _spend_rested() -> void:
	Game.spend_rested()
	_close_sheet()

func _open_library() -> void:
	var notes: Array = [
		"Archivist Quill to the %s." % Game.address(),
		"A book stays shut until its stamp is in the handbook.",
	]
	var rows: Array = []
	for info in Game.BOOKS:
		var title := str(info["title"])
		var line := ""
		if Game.has_book(str(info["id"])):
			line = "Yours. %s" % str(info["line"])
		elif Game.book_ready(str(info["id"])):
			line = "Open. %s" % str(info["line"])
		else:
			line = Game.book_lock_line(info)
		rows.append(["%s\n%s" % [title, line], _read.bind(str(info["id"]))])
	_open_sheet("Library", rows, notes)

func _read(id: String) -> void:
	Game.read_book(id)
	_close_sheet()

func _open_hall() -> void:
	var notes: Array = [
		Game.rival_line("hall", Game.hall_course),
		"The stair shows a crest, not your gear.",
		"Your best run is the score. Extra attempts do not buy a higher one.",
	]
	var rows: Array = []
	for i in Game.HALL_TITLES.size():
		rows.append(["%s\n%s\n%s" % [Game.HALL_TITLES[i], Game.HALL_BLURBS[i], Game.hall_line(i)], _start_course.bind(i)])
	for row in Game.board_rows("hall", Game.hall_course):
		notes.append(_board_text(row, "hall", Game.board_rows("hall", Game.hall_course)))
	_open_sheet("Proving Hall", rows, notes)

func _start_course(index: int) -> void:
	get_tree().current_scene.start_hall(index)
	_close_sheet()

func _open_match_sheet() -> void:
	var notes: Array = [
		Game.season_line(),
		"Even: %s" % Game.rival_line("even"),
		"Open: %s" % Game.rival_line("open"),
		"Even shows a crest. Open shows hunt rank and weapon. Rewards are looks.",
	]
	_close_sheet()
	sheet = _sheet_root("Dueling Court")
	var box := _sheet_box(sheet)
	for note in notes:
		_add_note(box, str(note))
	_add_row(box, "Even Match  (practice, same power)", func() -> void:
		get_tree().current_scene.start_court("even")
		_close_sheet())
	_add_row(box, "Open Match  (practice, hunt rank counts)", func() -> void:
		get_tree().current_scene.start_court("open")
		_close_sheet())
	_add_row(box, "Host Even Match", func() -> void:
		get_tree().current_scene.host_match("even")
		_close_sheet())
	_add_row(box, "Host Open Match", func() -> void:
		get_tree().current_scene.host_match("open")
		_close_sheet())
	join_field = LineEdit.new()
	join_field.placeholder_text = "Friend's IP address"
	join_field.custom_minimum_size = Vector2(0, 72)
	join_field.add_theme_font_size_override("font_size", 26)
	box.add_child(join_field)
	_add_row(box, "Join Even Match", func() -> void:
		get_tree().current_scene.join_match(join_field.text, "even")
		_close_sheet())
	_add_row(box, "Join Open Match", func() -> void:
		get_tree().current_scene.join_match(join_field.text, "open")
		_close_sheet())
	if Online.active:
		_add_row(box, "Leave the online court", func() -> void:
			get_tree().current_scene.leave_online()
			_close_sheet())
	_add_note(box, "Even board")
	var even_rows: Array = Game.board_rows("even")
	for row in even_rows:
		_add_note(box, _board_text(row, "even", even_rows))
	_add_note(box, "Open board")
	var open_rows: Array = Game.board_rows("open")
	for row in open_rows:
		_add_note(box, _board_text(row, "open", open_rows))

func _board_text(row: Dictionary, mode: String, rows: Array) -> String:
	var you_index := -1
	for i in rows.size():
		if bool(rows[i]["you"]):
			you_index = i
			break
	var prefix := ""
	var mine := false
	for i in rows.size():
		if rows[i] == row:
			if bool(row["you"]):
				prefix = "You · "
				mine = true
			elif i == you_index - 1:
				prefix = "Above · "
			break
	var score := ""
	if mode == "hall":
		score = "no time yet" if float(row["score"]) < 0.0 else "%.1fs" % float(row["score"])
	else:
		score = "%d wins" % int(row["score"])
	if mine:
		prefix = "You · "
	return "%s%s\n%s\n%s" % [prefix, str(row["who"]), str(row["detail"]), score]

func _open_places() -> void:
	_close_sheet()
	sheet = _sheet_root("Places")
	var box := _sheet_box(sheet)
	for i in Game.landing_count():
		_add_landing_card(box, i)
	for id in [
		Game.Place.OUTSIDE, Game.Place.YARD, Game.Place.GARDEN, Game.Place.UNDERCROFT, Game.Place.WASTES,
		Game.Place.COURT, Game.Place.HALL, Game.Place.CLASSROOM, Game.Place.LIBRARY, Game.Place.GATE,
	]:
		_add_place_card(box, id)

func _add_place_card(box: VBoxContainer, id: int) -> void:
	var title := Game.place_name(id)
	var detail := Game.place_blurb(id)
	var edge := Color("e2c56a")
	if Game.is_locked(id):
		detail = Game.lock_reason(id)
		edge = Color("c5764b")
	elif id == Game.place:
		detail = "You are here"
		edge = Color("ffe08a")
	var button := Button.new()
	button.text = "%s\n%s" % [title, detail]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 132)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color("f7f1e4"))
	var fill := Color("2e4048")
	var normal := _box(fill, edge)
	normal.content_margin_left = 118
	var hover := _box(fill.lightened(0.08), edge)
	hover.content_margin_left = 118
	var pressed := _box(fill.darkened(0.08), edge)
	pressed.content_margin_left = 118
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.pressed.connect(_go_place.bind(id))
	var swatch: Array = Game.place_swatch(id)
	var sky := ColorRect.new()
	sky.color = swatch[0]
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.position = Vector2(16, 16)
	sky.size = Vector2(86, 100)
	button.add_child(sky)
	var ground := ColorRect.new()
	ground.color = swatch[1]
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.position = Vector2(16, 74)
	ground.size = Vector2(86, 42)
	button.add_child(ground)
	box.add_child(button)

func _add_landing_card(box: VBoxContainer, index: int) -> void:
	var button := Button.new()
	button.text = "%s\nWalk this landing. The trial is through the door." % Game.landing_name(index)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 110)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color("f7f1e4"))
	var edge := Game.tier_window(String(Game.LANDING_SKILLS[index]))
	var fill := Color("2e4048")
	button.add_theme_stylebox_override("normal", _box(fill, edge))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), edge))
	button.pressed.connect(_go_landing.bind(index))
	box.add_child(button)

func _go_landing(index: int) -> void:
	Game.go_landing(index)
	_close_sheet()

func _go_place(id: int) -> void:
	if id == Game.Place.YARD:
		Game.travel(id)
	else:
		Game.open_door(id, Game.door_back(id))
	_close_sheet()

func _open_yearbook() -> void:
	var notes: Array = [
		Game.handbook_line(),
		Game.rested_line(),
		Game.titles_line(),
		Game.looks_line(),
		Game.season_line(),
		"Chapters do not close the fields.",
		"Forest circuits finished: %d." % Game.circuit_clears,
	]
	if Game.spirit_line != "":
		notes.append(Game.spirit_line)
	_close_sheet()
	sheet = _sheet_root("Yearbook")
	var box := _sheet_box(sheet)
	for note in notes:
		_add_note(box, str(note))
	for i in Game.CHAPTERS.size():
		var chapter: Dictionary = Game.CHAPTERS[i]
		var mark := "Done" if Game.chapters_done[i] else "Open"
		_add_row(box, "%s  (%s)\n%s" % [str(chapter["title"]), mark, str(chapter["body"])], _show_chapter.bind(i))
	_add_row(box, "Preview phone window", func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(420, 900)))
	_add_row(box, "Preview iPad window", func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1180, 820)))
	_add_row(box, "Preview computer window", func() -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1440, 900)))

func _show_chapter(index: int) -> void:
	var chapter: Dictionary = Game.CHAPTERS[index]
	_show_toast(str(chapter["body"]))
	_close_sheet()

func _open_sheet(title: String, rows: Array, notes: Array = []) -> void:
	_close_sheet()
	sheet = _sheet_root(title)
	var box := _sheet_box(sheet)
	for note in notes:
		_add_note(box, str(note))
	for row in rows:
		_add_row(box, row[0], row[1])

func _sheet_root(title: String) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _box(Color("f4efe4"), Color("2e4048")))
	add_child(panel)
	panel.position = Vector2(16, size.y)
	panel.size = size - Vector2(32, 32)
	panel.set_meta("sliding", true)
	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color("2e4048"))
	title_label.name = "Title"
	panel.add_child(title_label)
	var slide := create_tween()
	slide.tween_property(panel, "position", Vector2(16, 16), 0.22)
	slide.finished.connect(func() -> void:
		if is_instance_valid(panel):
			panel.set_meta("sliding", false)
	)
	panel.tree_exiting.connect(slide.kill)
	panel.gui_input.connect(_keep_press)
	return panel

func _sheet_box(panel: Panel) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 84
	scroll.offset_left = 16
	scroll.offset_right = -16
	scroll.offset_bottom = -100
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var back := Button.new()
	back.text = "Back"
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(0, 78)
	back.add_theme_font_size_override("font_size", 28)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back.offset_top = -88
	back.offset_left = 16
	back.offset_right = -16
	back.offset_bottom = -12
	back.add_theme_stylebox_override("normal", _box(Color("2e4048"), Color("e2c56a")))
	back.add_theme_color_override("font_color", Color("f7f1e4"))
	back.pressed.connect(_close_sheet)
	panel.add_child(back)
	var title: Label = panel.get_node("Title")
	title.position = Vector2(18, 12)
	title.size = Vector2(panel.size.x - 36, 70)
	return box

func _add_note(box: VBoxContainer, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("2e4048"), Color("e2c56a")))
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 72)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("f7f1e4"))
	panel.add_child(label)
	box.add_child(panel)

func _add_row(box: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(0, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color("f7f1e4"))
	button.add_theme_stylebox_override("normal", _box(Color("2e4048"), Color("e2c56a")))
	button.add_theme_stylebox_override("hover", _box(Color("3d5560"), Color("e2c56a")))
	button.add_theme_stylebox_override("pressed", _box(Color("24343b"), Color("e2c56a")))
	button.pressed.connect(callback)
	box.add_child(button)

func _close_sheet() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	sheet = null

func _draw_stick() -> void:
	var center := joystick.size * 0.5
	var radius := minf(joystick.size.x, joystick.size.y) * 0.5 - 6.0
	joystick.draw_circle(center, radius, Color(0.18, 0.22, 0.26, 0.62))
	joystick.draw_arc(center, radius - 8.0, 0, TAU, 48, Color("e2c56a"), 8.0, true)
	joystick.draw_circle(center + knob, radius * 0.38, Color("f4e3a8"))

func _stick_input(event: InputEvent) -> void:
	var radius := minf(joystick.size.x, joystick.size.y) * 0.5 - 6.0
	var pointer := event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			_move_knob(event.position, radius)
		else:
			_release_stick()
	elif event is InputEventMouseMotion and dragging:
		_move_knob(event.position, radius)
	elif event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			_move_knob(event.position, radius)
		elif not event.pressed and event.index == finger:
			finger = -1
			_release_stick()
	elif event is InputEventScreenDrag and event.index == finger:
		_move_knob(event.position, radius)
	if pointer:
		accept_event()

func _move_knob(point: Vector2, radius: float) -> void:
	var delta := point - joystick.size * 0.5
	if delta.length() > radius:
		delta = delta.normalized() * radius
	knob = delta
	var vector := delta / radius
	Game.stick = Vector2(vector.x, vector.y)
	joystick.queue_redraw()

func _release_stick() -> void:
	dragging = false
	knob = Vector2.ZERO
	Game.stick = Vector2.ZERO
	joystick.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _pan_blocked():
		_end_pan()
		return
	if event is InputEventScreenTouch:
		_pan_touch(event)
	elif event is InputEventScreenDrag:
		_pan_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pan_click(event)
	elif event is InputEventMouseMotion:
		_pan_move(event)

func _pan_blocked() -> bool:
	if Game.opening:
		return true
	return sheet != null and is_instance_valid(sheet)

func _end_pan() -> void:
	pan_pointer = -2
	pan_touch = false

func _pan_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if pan_pointer == -2:
			pan_touch = true
			pan_pointer = event.index
	elif event.index == pan_pointer:
		_end_pan()
	accept_event()

func _pan_drag(event: InputEventScreenDrag) -> void:
	if event.index != pan_pointer:
		return
	_pan_by(event.relative)
	accept_event()

func _pan_click(event: InputEventMouseButton) -> void:
	if pan_touch:
		if not event.pressed:
			_end_pan()
		accept_event()
		return
	if event.pressed:
		pan_pointer = -1
	elif pan_pointer == -1:
		pan_pointer = -2
	accept_event()

func _pan_move(event: InputEventMouseMotion) -> void:
	if pan_touch or pan_pointer != -1:
		return
	_pan_by(event.relative)
	accept_event()

func _pan_by(screen_delta: Vector2) -> void:
	var world := get_parent()
	if world:
		world = world.get_parent()
	if world and world.has_method("pan_camera"):
		world.pan_camera(screen_delta)

func _keep_press(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
		accept_event()

func _open_story() -> void:
	Game.opening = true
	var host: Node = self
	if get_parent() and get_parent().get_parent():
		host = get_parent().get_parent()
	story_layer = CanvasLayer.new()
	story_layer.name = "Opening"
	story_layer.layer = 40
	host.add_child(story_layer)
	story = Control.new()
	story.name = "Story"
	story.mouse_filter = Control.MOUSE_FILTER_STOP
	story.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story_layer.add_child(story)
	story.gui_input.connect(_keep_press)
	var veil := ColorRect.new()
	veil.color = Color(0.07, 0.09, 0.11, 0.86)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	story.add_child(veil)
	story_plate = Panel.new()
	story_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	story_plate.add_theme_stylebox_override("panel", _box(Color("2e4048"), Color("e2c56a")))
	story_plate.gui_input.connect(_keep_press)
	story.add_child(story_plate)
	story_page = _story_label(Color("e2c56a"))
	story_title = _story_label(Color("e2c56a"))
	story_title.text = "Vanguard Academy"
	story_body = _story_label(Color("f7f1e4"))
	story_plate.add_child(story_page)
	story_plate.add_child(story_title)
	story_plate.add_child(story_body)
	story_back = _story_button("Back")
	story_next = _story_button("Next")
	story_begin = _story_button("Begin")
	story.add_child(story_back)
	story.add_child(story_next)
	story.add_child(story_begin)
	story_back.pressed.connect(_story_back)
	story_next.pressed.connect(_story_next)
	story_begin.pressed.connect(_story_begin)
	story.resized.connect(_layout_story)
	story_index = 0
	_show_story_page()

func _story_label(color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", 12)
	return label

func _story_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var fill := Color("2e4048")
	var edge := Color("e2c56a")
	button.add_theme_stylebox_override("normal", _box(fill, edge))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.08), edge))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.08), edge))
	button.add_theme_color_override("font_color", Color("f7f1e4"))
	button.add_theme_font_size_override("font_size", 32)
	return button

func _show_story_page() -> void:
	if story_body == null:
		return
	var last := SCHOOL_STORY.size() - 1
	story_index = clampi(story_index, 0, last)
	story_body.text = SCHOOL_STORY[story_index]
	story_page.text = "%d / %d" % [story_index + 1, SCHOOL_STORY.size()]
	story_back.visible = story_index > 0
	story_next.visible = story_index < last
	story_begin.visible = story_index == last
	_layout_story()

func _story_back() -> void:
	if story_index <= 0:
		return
	story_index -= 1
	_show_story_page()

func _story_next() -> void:
	if story_index >= SCHOOL_STORY.size() - 1:
		return
	story_index += 1
	_show_story_page()

func _story_begin() -> void:
	if story_index != SCHOOL_STORY.size() - 1:
		return
	Game.begin_play()
	_free_story()

func _free_story() -> void:
	var layer := story_layer
	story_layer = null
	story = null
	if layer and is_instance_valid(layer):
		layer.queue_free()

func _layout_story() -> void:
	if story == null or not is_instance_valid(story) or story_plate == null:
		return
	var view := story.size
	if view.x < 20.0 or view.y < 20.0:
		view = story.get_viewport_rect().size
	if view.x < 20.0 or view.y < 20.0:
		return
	var margin := _view_margins(view)
	var left := margin.x
	var top := margin.y
	var right := margin.z
	var bottom := margin.w
	var short_side := minf(view.x, view.y)
	var gap := 16.0
	var btn_h := clampf(short_side * 0.15, 92.0, 128.0)
	var font := int(clampf(short_side * 0.055, 30, 42))
	var body_font := int(clampf(short_side * 0.05, 30, 44))
	var title_font := int(clampf(short_side * 0.07, 36, 56))
	for button in [story_back, story_next, story_begin]:
		button.add_theme_font_size_override("font_size", font)
	var shown: Array[Button] = []
	if story_back.visible:
		shown.append(story_back)
	if story_next.visible:
		shown.append(story_next)
	if story_begin.visible:
		shown.append(story_begin)
	var stack := shown.size() != 2 or story_begin.visible or view.x < 760.0
	var rows := shown.size() if stack else 1
	var block_h := btn_h * float(rows) + gap * float(maxi(rows - 1, 0))
	var available := view.y - top - bottom
	if available - block_h - gap < 160.0:
		btn_h = clampf(available * 0.18, 78.0, btn_h)
		block_h = btn_h * float(rows) + gap * float(maxi(rows - 1, 0))
	var plate_h := maxf(120.0, available - block_h - gap)
	var plate_w := view.x - left - right
	story_plate.position = Vector2(left, top)
	story_plate.size = Vector2(plate_w, plate_h)
	var inner := 28.0
	story_page.position = Vector2(inner, 20)
	story_page.size = Vector2(plate_w - inner * 2.0, font + 16)
	story_page.add_theme_font_size_override("font_size", maxi(26, font - 4))
	story_title.position = Vector2(inner, story_page.position.y + story_page.size.y + 6.0)
	story_title.size = Vector2(plate_w - inner * 2.0, title_font * 2.2)
	story_title.add_theme_font_size_override("font_size", title_font)
	var body_top := story_title.position.y + story_title.size.y + 8.0
	story_body.position = Vector2(inner, body_top)
	story_body.size = Vector2(plate_w - inner * 2.0, maxf(48.0, plate_h - body_top - inner))
	story_body.add_theme_font_size_override("font_size", body_font)
	story_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var y := top + plate_h + gap
	if stack:
		for button in shown:
			button.position = Vector2(left, y)
			button.size = Vector2(plate_w, btn_h)
			y += btn_h + gap
	elif shown.size() == 2:
		var half := (plate_w - gap) * 0.5
		shown[0].position = Vector2(left, y)
		shown[0].size = Vector2(half, btn_h)
		shown[1].position = Vector2(left + half + gap, y)
		shown[1].size = Vector2(half, btn_h)
