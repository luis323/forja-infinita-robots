class_name RobotModel
extends Node3D

const Catalog = preload("res://scripts/robot_catalog.gd")

var part_roots := {}
var team_tint := Color("48d8ff")
var moving := false
var defeated := false
var celebrating := false
var _time := 0.0
var _base_y := 0.0

func build_robot(build: Dictionary, tint: Color, animate_slot: String = "") -> void:
	team_tint = tint
	for child in get_children():
		child.queue_free()
	part_roots.clear()
	for slot in Catalog.SLOTS:
		var index := int(build.get(slot, 0))
		var root := _build_part(slot, index)
		root.name = slot
		add_child(root)
		part_roots[slot] = root
		if animate_slot == slot:
			_animate_join(root, Catalog.SLOTS.find(slot))
	_add_joint_lights()

func set_moving(value: bool) -> void:
	moving = value

func play_attack(use_left: bool, heavy: bool = false) -> void:
	if defeated:
		return
	var arm_key := "left_arm" if use_left else "right_arm"
	var weapon_key := "left_weapon" if use_left else "right_weapon"
	var direction := -1.0 if use_left else 1.0
	for key in [arm_key, weapon_key]:
		var pivot: Node3D = part_roots.get(key)
		if not pivot:
			continue
		var start_rotation := pivot.rotation
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(pivot, "rotation:x", start_rotation.x - 1.25, 0.11 if not heavy else 0.18)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(pivot, "rotation:x", start_rotation.x, 0.20)
		if key == weapon_key:
			pivot.rotation.z = 0.08 * direction

func play_hit() -> void:
	if defeated:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.10, 0.90, 1.10), 0.07)
	tween.tween_property(self, "scale", Vector3.ONE, 0.16)

func play_victory() -> void:
	if defeated:
		return
	celebrating = true
	moving = false
	var ground_y := position.y
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", ground_y + 0.75, 0.22)
	tween.parallel().tween_property(self, "rotation:y", rotation.y + TAU, 0.62)
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", ground_y, 0.34)

func play_defeat() -> void:
	defeated = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:z", deg_to_rad(82.0), 0.72)
	tween.parallel().tween_property(self, "position:y", position.y - 0.45, 0.72)

func _process(delta: float) -> void:
	_time += delta
	if defeated or celebrating:
		return
	var target_y := _base_y
	if moving:
		target_y += abs(sin(_time * 8.0)) * 0.12
		rotation.z = sin(_time * 7.0) * 0.025
	else:
		target_y += sin(_time * 2.1) * 0.025
		rotation.z = lerpf(rotation.z, 0.0, delta * 5.0)
	position.y = lerpf(position.y, target_y, minf(1.0, delta * 10.0))

func remember_floor_height() -> void:
	_base_y = position.y

func _build_part(slot: String, index: int) -> Node3D:
	var root := Node3D.new()
	var data := Catalog.get_option(slot, index)
	var metal: Color = data.color.lerp(team_tint, 0.28)
	var accent: Color = team_tint.lightened(0.18)
	var shape := int(data.shape)
	match slot:
		"torso":
			root.position = Vector3(0.0, 2.75, 0.0)
			_add_shape(root, shape, Vector3(1.9, 1.55, 1.05), metal, false)
			_add_shape(root, 0, Vector3(0.86, 0.50, 1.13), accent, true, Vector3(0.0, 0.08, -0.02))
			_add_shape(root, 2, Vector3(0.38, 0.38, 0.22), Color("fff173"), true, Vector3(0.0, 0.10, -0.62))
			if index % 4 == 2:
				_add_shape(root, 1, Vector3(2.30, 0.25, 0.35), metal.darkened(0.18), false, Vector3(0.0, 0.52, 0.0))
		"head":
			root.position = Vector3(0.0, 4.18, 0.0)
			_add_shape(root, shape, Vector3(1.22, 0.92, 0.92), metal, false)
			_add_shape(root, 0, Vector3(0.82, 0.18, 0.12), accent, true, Vector3(0.0, 0.06, -0.50))
			if index % 3 == 0:
				_add_shape(root, 1, Vector3(0.12, 0.52, 0.12), metal, false, Vector3(0.0, 0.68, 0.0))
				_add_shape(root, 2, Vector3(0.20, 0.20, 0.20), accent, true, Vector3(0.0, 0.98, 0.0))
			elif index % 3 == 1:
				_add_shape(root, 4, Vector3(1.58, 0.18, 0.28), accent, true, Vector3(0.0, 0.25, 0.0))
		"left_arm", "right_arm":
			var side := -1.0 if slot == "left_arm" else 1.0
			root.position = Vector3(side * 1.30, 3.30, 0.0)
			_add_shape(root, 2, Vector3(0.54, 0.54, 0.54), accent, true)
			_add_shape(root, shape, Vector3(0.68, 1.42, 0.72), metal, false, Vector3(0.0, -0.72, 0.0))
			_add_shape(root, 4, Vector3(0.78, 0.30, 0.80), accent, true, Vector3(0.0, -1.45, 0.0))
		"left_leg", "right_leg":
			var side := -1.0 if slot == "left_leg" else 1.0
			root.position = Vector3(side * 0.58, 2.05, 0.0)
			_add_shape(root, 2, Vector3(0.50, 0.50, 0.50), accent, true)
			_add_shape(root, shape, Vector3(0.76, 1.50, 0.86), metal, false, Vector3(0.0, -0.75, 0.0))
			_add_shape(root, 0, Vector3(0.90, 0.38, 1.28), accent.darkened(0.15), false, Vector3(0.0, -1.58, -0.14))
		"left_weapon", "right_weapon":
			var side := -1.0 if slot == "left_weapon" else 1.0
			root.position = Vector3(side * 1.33, 1.65, -0.18)
			_build_weapon(root, index, metal, accent, side)
	return root

func _build_weapon(root: Node3D, index: int, metal: Color, accent: Color, side: float) -> void:
	var style := index % 10
	match style:
		0, 10:
			_add_shape(root, 1, Vector3(0.20, 1.25, 0.20), metal, false, Vector3(0.0, 0.12, 0.0))
			_add_shape(root, 0, Vector3(1.10, 0.56, 0.52), accent, true, Vector3(0.0, -0.64, 0.0))
		1, 6:
			_add_shape(root, 1, Vector3(0.18, 0.82, 0.18), metal, false, Vector3(0.0, 0.35, 0.0))
			_add_shape(root, 0, Vector3(0.22, 1.70, 0.18), accent, true, Vector3(0.0, -0.85, 0.0))
		2, 14:
			_add_shape(root, 2, Vector3(0.78, 0.78, 0.78), metal, false, Vector3(0.0, -0.30, -0.10))
			_add_shape(root, 4, Vector3(0.62, 0.24, 0.62), accent, true, Vector3(0.0, -0.56, -0.22))
		3, 11, 15:
			_add_shape(root, 1, Vector3(0.62, 1.36, 0.62), metal, false, Vector3(0.0, -0.25, 0.0))
			_add_shape(root, 1, Vector3(0.26, 0.56, 0.26), accent, true, Vector3(0.0, -1.10, 0.0))
		4, 8:
			_add_shape(root, 1, Vector3(0.48, 1.48, 0.48), metal, false, Vector3(0.0, -0.42, 0.0))
			_add_shape(root, 1, Vector3(0.12, 0.72, 0.12), accent, true, Vector3(0.0, -1.38, 0.0))
		5, 12, 16:
			_add_shape(root, 1, Vector3(0.16, 2.10, 0.16), metal, false, Vector3(0.0, -0.72, 0.0))
			_add_shape(root, 2, Vector3(0.34, 0.34, 0.34), accent, true, Vector3(0.0, -1.84, 0.0))
		7, 9, 17:
			_add_shape(root, 1, Vector3(1.20, 0.22, 1.20), metal, false, Vector3(0.0, -0.54, -0.10), Vector3(90.0, 0.0, 0.0))
			_add_shape(root, 2, Vector3(0.44, 0.44, 0.44), accent, true, Vector3(0.0, -0.54, -0.20))
		_:
			_add_shape(root, 2, Vector3(0.92, 0.92, 0.92), accent, true, Vector3(0.0, -0.72, 0.0))
			_add_shape(root, 1, Vector3(0.12, 0.92, 0.12), metal, false, Vector3(0.0, 0.05, 0.0))
	root.rotation.z = side * 0.08

func _add_joint_lights() -> void:
	for point in [Vector3(-0.58, 2.05, -0.46), Vector3(0.58, 2.05, -0.46), Vector3(0.0, 3.58, -0.56)]:
		_add_shape(self, 2, Vector3(0.14, 0.14, 0.14), Color("fff173"), true, point)

func _add_shape(parent: Node3D, shape: int, size: Vector3, color: Color, glow: bool, offset := Vector3.ZERO, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match shape % 5:
		0:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		1:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = maxf(0.04, minf(size.x, size.z) * 0.5)
			cylinder.bottom_radius = cylinder.top_radius * (0.72 if shape % 2 == 1 else 1.0)
			cylinder.height = size.y
			cylinder.radial_segments = 12
			mesh = cylinder
		2:
			var sphere := SphereMesh.new()
			sphere.radius = minf(size.x, size.z) * 0.5
			sphere.height = size.y
			sphere.radial_segments = 12
			sphere.rings = 6
			mesh = sphere
		3:
			var capsule := CapsuleMesh.new()
			capsule.radius = minf(size.x, size.z) * 0.5
			capsule.height = maxf(size.y, capsule.radius * 2.05)
			capsule.radial_segments = 12
			capsule.rings = 4
			mesh = capsule
		_:
			var bevel := CylinderMesh.new()
			bevel.top_radius = minf(size.x, size.z) * 0.35
			bevel.bottom_radius = minf(size.x, size.z) * 0.52
			bevel.height = size.y
			bevel.radial_segments = 6
			mesh = bevel
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72
	material.roughness = 0.24 if glow else 0.42
	if glow:
		material.emission_enabled = true
		material.emission = color * 1.45
		material.emission_energy_multiplier = 1.35
	mesh.material = material
	instance.mesh = mesh
	instance.position = offset
	instance.rotation_degrees = rotation_degrees
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

func _animate_join(root: Node3D, order: int) -> void:
	var destination := root.position
	var angle := float(order) * 0.91
	root.position = destination + Vector3(cos(angle) * 6.5, 2.5 + order * 0.15, sin(angle) * 5.0)
	root.scale = Vector3.ONE * 0.18
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position", destination, 0.42)
	tween.parallel().tween_property(root, "scale", Vector3.ONE, 0.42)
