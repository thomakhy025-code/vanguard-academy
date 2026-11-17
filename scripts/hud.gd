extends Control

var joystick: Control
var knob := Vector2.ZERO
var dragging := false
var finger := -1
var stick_origin := Vector2.ZERO

var cut_btn: Button
var spark_btn: Button
var step_btn: Button
var place_btn: Button
var rank_btn: Button
var action_btn: Button
var year_btn: Button
var toast_label: Label
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
	year_btn = _round_button("Book", Color("2e4048"), Color("e2c56a"))
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
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 26)
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
	Online.status.connect(_show_toast)
	resized.connect(_layout)
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

func _layout() -> void:
	var view := size
	if view.x < 20.0:
		return
	var short := minf(view.x, view.y)
	var margin := 22.0
	var stick_d := clampf(short * 0.34, 170.0, 300.0)
	joystick.size = Vector2(stick_d, stick_d)
	joystick.position = Vector2(margin, view.y - stick_d - margin)
	joystick.queue_redraw()
	var cut := clampf(short * 0.2, 108.0, 164.0)
	var small := cut * 0.82
	var font := int(clampf(short * 0.04, 20, 32))
	cut_btn.size = Vector2(cut, cut)
	cut_btn.position = Vector2(view.x - cut - margin, view.y - cut - margin)
	spark_btn.size = Vector2(small, small)
	spark_btn.position = Vector2(cut_btn.position.x + (cut - small) * 0.5, cut_btn.position.y - small - 14)
	step_btn.size = Vector2(small, small)
	step_btn.position = Vector2(cut_btn.position.x - small - 14, cut_btn.position.y + (cut - small) * 0.45)
	for button in [cut_btn, spark_btn, step_btn, place_btn, rank_btn, action_btn, year_btn]:
		button.add_theme_font_size_override("font_size", font)
	var plate_w := clampf(view.x * 0.36, 190.0, 340.0)
	var plate_h := clampf(short * 0.1, 68.0, 96.0)
	place_btn.size = Vector2(plate_w, plate_h)
	place_btn.position = Vector2(view.x - plate_w - margin, margin)
	rank_btn.size = Vector2(plate_w, plate_h)
	rank_btn.position = Vector2(margin, margin)
	action_btn.size = Vector2(minf(plate_w * 1.15, view.x - margin * 2.0), plate_h)
	action_btn.position = Vector2((view.x - action_btn.size.x) * 0.5, margin + plate_h + 10)
	year_btn.size = Vector2(plate_h, plate_h)
	year_btn.position = Vector2(margin, rank_btn.position.y + plate_h + 12)
	var hp_back := get_node("HpBack")
	hp_back.size = Vector2(clampf(view.x * 0.36, 180, 360), 22)
	hp_back.position = Vector2((view.x - hp_back.size.x) * 0.5, cut_btn.position.y - 40)
	_paint_hp()
	toast_label.size = Vector2(view.x - 80, 90)
	toast_label.position = Vector2(40, action_btn.position.y + plate_h + 8)
	if sheet:
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
	rank_btn.text = "Rank %d\nOre %d" % [Game.hunt_rank, Game.ore]
	action_btn.visible = _action_label() != ""
	action_btn.text = _action_label()

func _action_label() -> String:
	match Game.place:
		Game.Place.CLASSROOM: return "Take today's lesson"
		Game.Place.LIBRARY: return "Open the book"
		Game.Place.HALL: return "Start the course"
		Game.Place.COURT: return "Choose a match"
		_: return ""

func _show_toast(message: String) -> void:
	toast_label.text = message

func _open_rank() -> void:
	if Game.place != Game.Place.YARD:
		_show_toast("The forge bench is in the Yard.")
		return
	var cost := Game.upgrade_cost()
	_open_sheet("Forge bench", [
		["Raise hunt rank  (%d ore)" % cost, _upgrade],
	])

func _upgrade() -> void:
	if Game.try_upgrade():
		_close_sheet()

func _open_action() -> void:
	match Game.place:
		Game.Place.CLASSROOM:
			_open_sheet("Professor Hen", [
				["Stamp Spellcut", func() -> void:
					Game.stamp_lesson()
					_close_sheet()],
			])
		Game.Place.LIBRARY:
			var line := "Read The Wooden Sparrow" if not Game.hop_cut else "The sparrow is already learned"
			_open_sheet("Archivist Quill", [
				[line, func() -> void:
					Game.read_book()
					_close_sheet()],
			])
		Game.Place.HALL:
			var best := "No named run yet"
			if Game.best_hall_time >= 0.0:
				best = "Best run %.1fs" % Game.best_hall_time
			_open_sheet("Proving Hall\n%s" % best, [
				["Start the three constructs", func() -> void:
					get_tree().current_scene.start_hall()
					_close_sheet()],
			])
		Game.Place.COURT:
			_open_match_sheet()

func _open_match_sheet() -> void:
	_close_sheet()
	sheet = _sheet_root("Dueling Court")
	var box := _sheet_box(sheet)
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

func _open_places() -> void:
	_close_sheet()
	sheet = _sheet_root("Places")
	var box := _sheet_box(sheet)
	for id in [
		Game.Place.YARD, Game.Place.GARDEN, Game.Place.UNDERCROFT, Game.Place.WASTES,
		Game.Place.COURT, Game.Place.HALL, Game.Place.CLASSROOM, Game.Place.LIBRARY, Game.Place.GATE,
	]:
		var title := Game.place_name(id)
		var detail := Game.place_blurb(id)
		if Game.is_locked(id):
			detail = Game.lock_reason(id)
		elif id == Game.place:
			detail = "You are here"
		_add_row(box, "%s\n%s" % [title, detail], _go_place.bind(id))

func _go_place(id: int) -> void:
	Game.travel(id)
	_close_sheet()

func _open_yearbook() -> void:
	_close_sheet()
	sheet = _sheet_root("Yearbook")
	var box := _sheet_box(sheet)
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

func _open_sheet(title: String, rows: Array) -> void:
	_close_sheet()
	sheet = _sheet_root(title)
	var box := _sheet_box(sheet)
	for row in rows:
		_add_row(box, row[0], row[1])

func _sheet_root(title: String) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _box(Color("f4efe4"), Color("2e4048")))
	add_child(panel)
	panel.position = Vector2(16, 16)
	panel.size = size - Vector2(32, 32)
	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("2e4048"))
	title_label.name = "Title"
	panel.add_child(title_label)
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
			stick_origin = event.position
			_move_knob(event.position, radius)
		else:
			_release_stick()
	elif event is InputEventMouseMotion and dragging:
		_move_knob(event.position, radius)
	elif event is InputEventScreenTouch:
		if event.pressed and finger == -1:
			finger = event.index
			stick_origin = event.position
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
