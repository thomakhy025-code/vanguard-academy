extends Node

var school: AudioStreamPlayer
var battle: AudioStreamPlayer
var current := ""
var fade: Tween

func _ready() -> void:
	school = _player("res://audio/between_bells.wav")
	battle = _player("res://audio/ready_at_the_ring.wav")
	school.volume_db = -8.0
	battle.volume_db = -40.0
	if school.stream:
		school.play()
		current = "school"
	Game.traveled.connect(play_for)

func _player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	var stream = load(path)
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = stream
	elif stream:
		player.stream = stream
	else:
		push_warning("Missing music: %s" % path)
	return player

func play_for(id: int) -> void:
	var want := "battle" if Game.is_battle_music(id) else "school"
	if school.stream == null and battle.stream == null:
		return
	if want != current:
		current = want
		if want == "battle":
			if battle.stream and not battle.playing:
				battle.play()
		else:
			if school.stream and not school.playing:
				school.play()
		if fade:
			fade.kill()
		fade = create_tween()
		if want == "battle":
			fade.tween_property(battle, "volume_db", -4.0, 0.35)
			fade.parallel().tween_property(school, "volume_db", -40.0, 0.35)
		else:
			fade.tween_property(school, "volume_db", _school_db(id), 0.35)
			fade.parallel().tween_property(battle, "volume_db", -40.0, 0.35)
	elif want == "school":
		school.volume_db = _school_db(id)

func _school_db(id: int) -> float:
	if id == Game.Place.UNDERCROFT:
		return -12.0
	if id == Game.Place.WASTES:
		return -6.0
	return -8.0
