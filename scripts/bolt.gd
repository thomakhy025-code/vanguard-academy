extends Node3D

var direction := Vector3.FORWARD
var life := 1.15
var speed := 16.0
var owner_path: NodePath

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	mesh.mesh = ball
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9fd6ff")
	material.emission_enabled = true
	material.emission = Color("b9e4ff")
	material.emission_energy_multiplier = 1.4
	material.roughness = 0.35
	mesh.material_override = material
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color("9fd6ff")
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.shadow_enabled = false
	add_child(light)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("foe"):
		if node.global_position.distance_to(global_position) < 1.2:
			node.take_hit(Game.outgoing(false), "spell")
			queue_free()
			return
	if Online.active:
		var link := get_node_or_null("/root/Main/Net")
		if link:
			for node in get_tree().get_nodes_in_group("player"):
				if str(node.get_path()) == str(owner_path):
					continue
				if node.global_position.distance_to(global_position) < 1.15:
					link.send_hit(str(node.name), Game.outgoing(false))
					queue_free()
					return
