class_name Foe
extends CharacterBody3D

enum Kind { BEAST, ELITE, BOSS, CONSTRUCT, DUMMY, DUELIST }

signal died(foe: Foe)

var kind := Kind.BEAST
var hp := 30.0
var max_hp := 30.0
var attack_damage := 6.0
var speed := 3.3
var alive := true
var home := Vector3.ZERO
var attack_wait := 0.6
var bar: MeshInstance3D
var body_mat: StandardMaterial3D

func setup(next_kind: Kind, at: Vector3) -> void:
	kind = next_kind
	home = at
	global_position = at
	collision_layer = 4
	collision_mask = 1
	_stats()
	_build()
	add_to_group("foe")
	if kind == Kind.CONSTRUCT:
		add_to_group("hall")

func _stats() -> void:
	match kind:
		Kind.BEAST:
			hp = 30
			speed = 3.4
			attack_damage = 6
		Kind.ELITE:
			hp = 58
			speed = 3.1
			attack_damage = 9
		Kind.BOSS:
			hp = 130
			speed = 2.8
			attack_damage = 12
		Kind.CONSTRUCT:
			hp = 42
			speed = 3.6
			attack_damage = 8
		Kind.DUMMY:
			hp = 1
			speed = 0
			attack_damage = 0
		Kind.DUELIST:
			hp = 96
			speed = 4.4
			attack_damage = 12.0 if Game.court_mode != "open" else 16.0
	max_hp = hp

func _build() -> void:
	var color := Color("57af70")
	var radius := 0.42
	var tall := 1.35
	match kind:
		Kind.ELITE:
			color = Color("6f8fbf")
			tall = 1.55
		Kind.BOSS:
			color = Color("c5764b")
			radius = 0.7
			tall = 2.1
		Kind.CONSTRUCT:
			color = Color("cbbe9e")
			tall = 1.5
		Kind.DUMMY:
			color = Color("b08968")
			tall = 1.7
			radius = 0.34
		Kind.DUELIST:
			color = Color("d07070")
			tall = 1.55
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position = Vector3(0, tall * 0.5, 0)
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = radius
	body.height = tall
	mesh.mesh = body
	mesh.position = shape.position
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.roughness = 0.82
	mesh.material_override = body_mat
	add_child(mesh)
	var head := MeshInstance3D.new()
	var skull := SphereMesh.new()
	skull.radius = radius * 0.85
	skull.height = radius * 1.7
	head.mesh = skull
	head.position = Vector3(0, tall + radius * 0.2, 0)
	var head_mat := body_mat.duplicate()
	head_mat.albedo_color = color.lightened(0.15)
	head.material_override = head_mat
	add_child(head)
	if kind == Kind.DUELIST or kind == Kind.BOSS or kind == Kind.CONSTRUCT:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 48
		label.position = Vector3(0, tall + radius + 0.45, 0)
		label.modulate = Color("2e4048")
		label.outline_modulate = Color("f4efe4")
		label.outline_size = 8
		if kind == Kind.DUELIST:
			label.text = "Mira"
		elif kind == Kind.BOSS:
			label.text = "Warden"
		else:
			label.text = "Construct"
		add_child(label)
	bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 0.12)
	bar.mesh = quad
	bar.position = Vector3(0, tall + radius + 0.15, 0)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.albedo_color = Color("57af70")
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar.material_override = bar_mat
	add_child(bar)
	if kind == Kind.DUMMY:
		bar.visible = false

func _physics_process(delta: float) -> void:
	if not alive or kind == Kind.DUMMY:
		return
	attack_wait = max(attack_wait - delta, 0.0)
	var target := _local_student()
	var velocity_flat := Vector3.ZERO
	if target:
		var to: Vector3 = target.global_position - global_position
		to.y = 0
		var reach := 14.0 if kind != Kind.DUELIST else 40.0
		if to.length() < reach and to.length() > 1.55:
			var step: Vector3 = to.normalized() * speed
			velocity_flat = step
			look_at(global_position + step, Vector3.UP)
		elif to.length() <= 1.55:
			_try_attack(target)
	velocity.x = velocity_flat.x
	velocity.z = velocity_flat.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()

func _try_attack(target: Node3D) -> void:
	if attack_wait > 0.0:
		return
	attack_wait = 0.95 if kind != Kind.BOSS else 1.2
	if target.has_method("hurt"):
		target.hurt(attack_damage)

func take_hit(amount: float, kind_name: String) -> void:
	if not alive:
		return
	if kind == Kind.DUMMY:
		_flash()
		Game.note_dummy_hit(kind_name)
		return
	hp = max(hp - amount, 0.0)
	_flash()
	var ratio := hp / max_hp
	bar.scale = Vector3(max(ratio, 0.05), 1, 1)
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()

func _flash() -> void:
	if body_mat:
		body_mat.emission_enabled = true
		body_mat.emission = Color("fff4d2")
		body_mat.emission_energy_multiplier = 0.8
		var timer := get_tree().create_timer(0.12)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(body_mat):
				body_mat.emission_enabled = false
		)

func _local_student() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_meta("local", false):
			return node as Node3D
	return null
