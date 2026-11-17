extends Node3D

var order := 0
var live := false
var mesh: MeshInstance3D
var base := Color("cbbe9e")

func setup(index: int, at: Vector3, color: Color) -> void:
	order = index
	base = color
	position = at
	add_to_group("mark")
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 1.35, 0.42)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.7, 0)
	add_child(mesh)
	light(false)

func light(on: bool) -> void:
	live = on
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e2c56a") if on else base
	material.roughness = 0.7
	if on:
		material.emission_enabled = true
		material.emission = Color("ffe08a")
		material.emission_energy_multiplier = 1.3
	mesh.material_override = material

func take_hit(_amount: float, kind_name: String) -> void:
	var host := get_tree().current_scene
	if host and host.has_method("trial_hit"):
		host.trial_hit(order, kind_name, live)
