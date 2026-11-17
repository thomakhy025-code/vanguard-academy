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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var edge := 22.0
	var home := 30.0
	var window := DisplayServer.window_get_size()
	if window.x < 40 or window.y < 40 or size.x < 40.0 or size.y < 40.0:
		return Vector4(edge, edge, edge, home)
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x < 32 or safe.size.y < 32:
		return Vector4(edge, edge, edge, home)
	var sx := size.x / float(window.x)
	var sy := size.y / float(window.y)
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
	match Game.place:
		Game.Place.GARDEN: return "Garden circuit"
		Game.Place.UNDERCROFT: return "Shards and ore"
		Game.Place.WASTES: return "Hunt rings"
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
	if Game.try_upgrade():
		_close_sheet()

func _equip(id: String) -> void:
	Game.equip(id)
	_close_sheet()

func _open_action() -> void:
	match Game.place:
		Game.Place.GARDEN:
			_open_sheet("Wild Garden", [], [Game.circuit_line(), "Packs and ore share the path. A short visit can finish the stones and leave."])
		Game.Place.UNDERCROFT:
			_open_sheet("Undercroft", [], ["Elites drop shards. The nodes here are richer. The bench spends ore and shards. Hunt rank is what the beasts feel."])
		Game.Place.WASTES:
			_open_sheet("Training Wastes", [], ["Inner ring: any hunt rank. Middle ring: made for rank 3. Outer ring and the Wastes Warden: made for rank 6. You can walk every ring. The field does not close."])
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
	for id in [
		Game.Place.YARD, Game.Place.GARDEN, Game.Place.UNDERCROFT, Game.Place.WASTES,
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

func _go_place(id: int) -> void:
	Game.travel(id)
	_close_sheet()

func _open_yearbook() -> void:
	var notes: Array = [
		Game.handbook_line(),
		Game.rested_line(),
		Game.titles_line(),
		Game.looks_line(),
		Game.season_line(),
		"Chapters do not close the fields.",
		"Garden circuits finished: %d." % Game.circuit_clears,
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
