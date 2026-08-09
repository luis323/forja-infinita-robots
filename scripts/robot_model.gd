class_name RobotModel
extends Node3D

const Catalog = preload("res://scripts/robot_catalog.gd")

const ARM_UPPER := [0.70, 1.05, 0.82, 0.92, 0.66, 1.30, 0.88, 1.02, 0.72, 0.86, 1.05, 0.62, 1.10, 0.84, 1.32, 0.76, 0.90, 1.18, 0.64, 1.00]
const ARM_LOWER := [0.64, 0.82, 0.86, 0.74, 0.62, 1.18, 0.78, 0.92, 0.58, 0.96, 0.88, 0.58, 0.90, 0.80, 1.26, 0.74, 0.84, 1.08, 0.60, 0.94]
const ARM_WIDTH := [0.42, 0.26, 0.34, 0.48, 0.61, 0.22, 0.40, 0.28, 0.32, 0.46, 0.55, 0.52, 0.38, 0.44, 0.20, 0.36, 0.50, 0.24, 0.66, 0.34]
const LEG_UPPER := [0.82, 1.12, 0.62, 0.66, 1.02, 0.72, 0.92, 1.20, 1.08, 0.78, 0.86, 1.25, 0.70, 0.94, 0.80, 0.68, 1.04, 0.88, 0.96, 1.10]
const LEG_LOWER := [0.78, 1.04, 0.55, 0.58, 0.94, 0.70, 0.88, 1.06, 1.02, 0.72, 0.82, 1.18, 0.62, 0.90, 0.76, 0.66, 0.98, 0.84, 0.92, 1.02]
const LEG_WIDTH := [0.44, 0.27, 0.62, 0.58, 0.25, 0.48, 0.40, 0.32, 0.30, 0.45, 0.38, 0.52, 0.56, 0.34, 0.60, 0.46, 0.28, 0.50, 0.36, 0.31]
const TORSO_WIDTH := [1.72, 1.82, 2.24, 1.38, 1.64, 1.90, 2.18, 1.32, 1.76, 2.02, 1.88, 1.66, 2.10, 1.72, 1.42, 2.14, 1.80, 1.94, 1.62, 1.86]
const TORSO_HEIGHT := [1.42, 1.48, 1.34, 1.70, 1.52, 1.58, 1.28, 1.82, 1.50, 1.40, 1.62, 1.46, 1.36, 1.66, 1.76, 1.30, 1.58, 1.48, 1.72, 1.54]
const TORSO_DEPTH := [0.94, 1.02, 1.18, 0.72, 1.10, 0.96, 1.24, 0.68, 1.08, 1.14, 1.00, 1.22, 1.08, 0.92, 0.78, 1.30, 1.04, 0.88, 1.16, 0.98]

var part_roots := {}
var motion_joints := {}
var weapon_mounts := {}
var team_tint := Color("48d8ff")
var moving := false
var defeated := false
var celebrating := false
var _time := 0.0
var _base_y := 0.0
var _attack_time := 0.0
var _attack_duration := 0.42
var _attack_left := true
var _attack_heavy := false

func build_robot(build: Dictionary, tint: Color, animate_slot: String = "") -> void:
	team_tint = tint
	defeated = false
	celebrating = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	part_roots.clear()
	motion_joints.clear()
	weapon_mounts.clear()
	for slot in Catalog.SLOTS:
		var index := int(build.get(slot, 0))
		var root := _build_part(slot, index)
		root.name = slot
		if slot == "left_weapon" and weapon_mounts.has("left"):
			weapon_mounts.left.add_child(root)
		elif slot == "right_weapon" and weapon_mounts.has("right"):
			weapon_mounts.right.add_child(root)
		else:
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
	_attack_left = use_left
	_attack_heavy = heavy
	_attack_duration = 0.54 if heavy else 0.38
	_attack_time = _attack_duration

func play_hit() -> void:
	if defeated:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.12, 0.88, 1.12), 0.065)
	tween.tween_property(self, "scale", Vector3.ONE, 0.16)

func play_victory() -> void:
	if defeated:
		return
	celebrating = true
	moving = false
	var ground_y := position.y
	var left_upper: Node3D = motion_joints.get("left_arm_upper")
	var right_upper: Node3D = motion_joints.get("right_arm_upper")
	if left_upper:
		create_tween().tween_property(left_upper, "rotation:x", -2.35, 0.32)
	if right_upper:
		create_tween().tween_property(right_upper, "rotation:x", -2.35, 0.32)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", ground_y + 0.82, 0.22)
	tween.parallel().tween_property(self, "rotation:y", rotation.y + TAU, 0.64)
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", ground_y, 0.34)

func play_defeat() -> void:
	defeated = true
	moving = false
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:z", deg_to_rad(82.0), 0.72)
	tween.parallel().tween_property(self, "position:y", position.y - 0.45, 0.72)

func _process(delta: float) -> void:
	_time += delta
	if defeated or celebrating:
		return
	_attack_time = maxf(0.0, _attack_time - delta)
	var gait := sin(_time * 8.5)
	var walk_amount := 1.0 if moving else 0.0
	var left_arm_upper: Node3D = motion_joints.get("left_arm_upper")
	var right_arm_upper: Node3D = motion_joints.get("right_arm_upper")
	var left_elbow: Node3D = motion_joints.get("left_arm_elbow")
	var right_elbow: Node3D = motion_joints.get("right_arm_elbow")
	var left_leg_upper: Node3D = motion_joints.get("left_leg_upper")
	var right_leg_upper: Node3D = motion_joints.get("right_leg_upper")
	var left_knee: Node3D = motion_joints.get("left_leg_knee")
	var right_knee: Node3D = motion_joints.get("right_leg_knee")
	var left_arm_angle := gait * 0.42 * walk_amount
	var right_arm_angle := -gait * 0.42 * walk_amount
	var left_elbow_angle := -0.12 - maxf(0.0, -gait) * 0.25 * walk_amount
	var right_elbow_angle := -0.12 - maxf(0.0, gait) * 0.25 * walk_amount
	if _attack_time > 0.0:
		var progress := 1.0 - _attack_time / _attack_duration
		var windup := sin(progress * PI)
		var recoil := sin(progress * TAU) * 0.16
		var strike_angle := (-1.62 if not _attack_heavy else -2.02) * windup + recoil
		if _attack_left:
			left_arm_angle = strike_angle
			left_elbow_angle = -0.72 * windup
			right_arm_angle *= 0.25
		else:
			right_arm_angle = strike_angle
			right_elbow_angle = -0.72 * windup
			left_arm_angle *= 0.25
	if left_arm_upper:
		left_arm_upper.rotation.x = lerpf(left_arm_upper.rotation.x, left_arm_angle, minf(1.0, delta * 18.0))
	if right_arm_upper:
		right_arm_upper.rotation.x = lerpf(right_arm_upper.rotation.x, right_arm_angle, minf(1.0, delta * 18.0))
	if left_elbow:
		left_elbow.rotation.x = lerpf(left_elbow.rotation.x, left_elbow_angle, minf(1.0, delta * 18.0))
	if right_elbow:
		right_elbow.rotation.x = lerpf(right_elbow.rotation.x, right_elbow_angle, minf(1.0, delta * 18.0))
	if left_leg_upper:
		left_leg_upper.rotation.x = gait * 0.50 * walk_amount
	if right_leg_upper:
		right_leg_upper.rotation.x = -gait * 0.50 * walk_amount
	if left_knee:
		left_knee.rotation.x = maxf(0.0, -gait) * 0.58 * walk_amount
	if right_knee:
		right_knee.rotation.x = maxf(0.0, gait) * 0.58 * walk_amount
	var torso: Node3D = part_roots.get("torso")
	var head: Node3D = part_roots.get("head")
	if torso:
		torso.rotation.y = gait * 0.055 * walk_amount
	if head:
		head.rotation.y = -gait * 0.075 * walk_amount + sin(_time * 1.4) * 0.025
	var target_y := _base_y + sin(_time * 2.1) * 0.018
	if moving:
		target_y += abs(gait) * 0.10
	position.y = lerpf(position.y, target_y, minf(1.0, delta * 12.0))

func remember_floor_height() -> void:
	_base_y = position.y

func _build_part(slot: String, index: int) -> Node3D:
	var root := Node3D.new()
	var data := Catalog.get_option(slot, index)
	var metal: Color = data.color.lerp(team_tint, 0.22)
	var accent: Color = team_tint.lightened(0.18)
	match slot:
		"torso":
			_build_torso(root, index, metal, accent)
		"head":
			_build_head(root, index, metal, accent)
		"left_arm", "right_arm":
			_build_arm(root, slot, index, metal, accent)
		"left_leg", "right_leg":
			_build_leg(root, slot, index, metal, accent)
		"left_weapon", "right_weapon":
			_build_weapon(root, index, metal, accent, -1.0 if slot == "left_weapon" else 1.0)
	return root

func _build_torso(root: Node3D, index: int, metal: Color, accent: Color) -> void:
	root.position = Vector3(0.0, 2.76, 0.0)
	var size := Vector3(float(TORSO_WIDTH[index]), float(TORSO_HEIGHT[index]), float(TORSO_DEPTH[index]))
	_add_shape(root, index % 5, size, metal, false)
	_add_shape(root, 0, Vector3(size.x * 0.46, size.y * 0.31, 0.16), accent, true, Vector3(0.0, 0.04, size.z * 0.54))
	_add_shape(root, 2, Vector3(0.34, 0.34, 0.22), Color("fff173"), true, Vector3(0.0, 0.05, size.z * 0.65))
	match index:
		0:
			for x in [-0.52, 0.52]:
				_add_shape(root, 2, Vector3(0.28, 0.28, 0.22), accent, true, Vector3(x, 0.45, size.z * 0.55))
		1:
			_add_shape(root, 1, Vector3(1.20, 0.14, 1.20), Color("ffd85d"), true, Vector3(0.0, 0.62, 0.0), Vector3(90.0, 0.0, 0.0))
		2:
			_add_shape(root, 0, Vector3(size.x + 0.52, 0.34, size.z + 0.16), metal.darkened(0.18), false, Vector3(0.0, 0.54, 0.0))
		3:
			for x in [-0.86, 0.86]:
				_add_shape(root, 0, Vector3(0.18, 1.12, 0.62), accent, true, Vector3(x, 0.0, 0.0), Vector3(0.0, 0.0, x * 20.0))
		4:
			_add_shape(root, 3, Vector3(0.94, 1.46, 0.94), Color("87d9ff"), true, Vector3(0.0, 0.0, 0.12), Vector3.ZERO, true)
		5:
			for y in [-0.44, 0.0, 0.44]:
				_add_shape(root, 1, Vector3(size.x + 0.16, 0.12, size.z + 0.10), accent, true, Vector3(0.0, y, 0.0), Vector3(0.0, 0.0, 90.0))
		6:
			_add_shape(root, 2, Vector3(2.16, 1.08, 1.30), metal.darkened(0.14), false)
		7:
			_add_shape(root, 0, Vector3(0.34, 1.72, 0.34), accent, true, Vector3(0.0, 0.0, 0.55))
		8:
			for angle in range(0, 360, 60):
				_add_shape(root, 0, Vector3(0.18, 0.78, 0.22), accent, true, Vector3(cos(deg_to_rad(angle)) * 0.72, sin(deg_to_rad(angle)) * 0.58, 0.48), Vector3(0.0, 0.0, -float(angle)))
		9:
			_add_shape(root, 0, Vector3(2.30, 0.22, 1.34), Color("ff905e"), true, Vector3(0.0, -0.48, 0.0))
		10:
			_add_shape(root, 1, Vector3(1.16, 0.24, 1.16), accent, true, Vector3(0.0, 0.60, 0.0))
		11:
			_add_shape(root, 3, Vector3(1.18, 1.54, 1.18), Color("579ed7"), true, Vector3(0.0, 0.0, 0.08), Vector3.ZERO, true)
		12:
			_add_shape(root, 0, Vector3(2.42, 0.20, 0.40), Color("f4f7ff"), false, Vector3(0.0, 0.18, 0.64))
		13:
			_add_shape(root, 2, Vector3(1.20, 1.20, 1.20), Color("ff5df0"), true, Vector3(0.0, 0.0, 0.18))
		14:
			for x in [-0.72, 0.72]:
				_add_shape(root, 0, Vector3(0.58, 1.42, 0.12), Color("d9f7ff"), true, Vector3(x, 0.0, -0.36), Vector3(0.0, 0.0, x * 24.0))
		15:
			_add_shape(root, 0, Vector3(2.22, 0.42, 1.38), metal.darkened(0.22), false, Vector3(0.0, -0.38, 0.0))
		16:
			for x in [-0.56, 0.0, 0.56]:
				_add_shape(root, 2, Vector3(0.32, 0.32, 0.24), Color("78ff81"), true, Vector3(x, 0.38, size.z * 0.55))
		17:
			_add_shape(root, 4, Vector3(size.x + 0.22, size.y * 0.58, size.z + 0.20), Color("b46cff"), true, Vector3(0.0, 0.22, 0.0))
		18:
			for x in [-0.86, 0.86]:
				_add_cone(root, 0.20, 0.68, metal, Vector3(x, 0.60, 0.0), Vector3(0.0, 0.0, -x * 55.0))
		19:
			for x in [-0.72, 0.72]:
				_add_shape(root, 0, Vector3(0.28, 0.70, 0.18), accent, true, Vector3(x, 0.10, size.z * 0.72))

func _build_head(root: Node3D, index: int, metal: Color, accent: Color) -> void:
	root.position = Vector3(0.0, 4.18, 0.0)
	var width: float = [1.18, 1.04, 1.10, 1.26, 1.12, 1.34, 1.22, 0.98, 1.08, 1.38, 0.92, 1.16, 1.28, 1.02, 1.36, 1.20, 1.24, 1.06, 0.96, 1.30][index]
	var height: float = [0.78, 1.02, 1.08, 0.72, 1.04, 0.68, 0.82, 1.12, 0.92, 0.86, 1.18, 0.80, 0.70, 1.12, 0.74, 0.90, 1.00, 0.82, 1.20, 0.76][index]
	var depth: float = [0.84, 0.82, 1.02, 0.76, 0.92, 0.88, 0.78, 0.86, 0.90, 1.02, 0.76, 0.84, 0.96, 0.80, 0.88, 1.08, 0.94, 0.82, 0.78, 0.90][index]
	_add_shape(root, index % 5, Vector3(width, height, depth), metal, false)
	match index:
		0:
			_add_shape(root, 0, Vector3(0.86, 0.15, 0.12), accent, true, Vector3(0.0, 0.02, depth * 0.54))
		1:
			_add_shape(root, 4, Vector3(0.64, 0.54, 0.14), accent, true, Vector3(0.0, 0.0, depth * 0.55))
		2:
			_add_shape(root, 2, Vector3(0.44, 0.44, 0.22), Color("ff4d74"), true, Vector3(0.0, 0.04, depth * 0.58))
		3:
			for x in [-0.42, 0.42]:
				_add_cone(root, 0.12, 0.58, accent, Vector3(x, 0.58, 0.0), Vector3.ZERO)
		4:
			for x in [-0.30, 0.30]:
				_add_shape(root, 0, Vector3(0.18, 0.18, 0.10), accent, true, Vector3(x, 0.10, depth * 0.55))
		5:
			_add_shape(root, 1, Vector3(1.30, 0.12, 1.30), accent, true, Vector3(0.0, 0.58, 0.0))
			_add_shape(root, 0, Vector3(0.08, 0.68, 0.08), metal, false, Vector3(0.0, 0.82, 0.0))
		6:
			for x in [-0.34, 0.34]:
				_add_shape(root, 2, Vector3(0.30, 0.30, 0.15), Color("fff173"), true, Vector3(x, 0.05, depth * 0.58))
		7:
			_add_shape(root, 0, Vector3(0.72, 0.72, 0.12), accent, true, Vector3(0.0, 0.0, depth * 0.57), Vector3(0.0, 0.0, 45.0))
		8:
			_add_shape(root, 2, Vector3(0.26, 0.26, 0.18), accent, true, Vector3(0.0, 0.0, depth * 0.60))
			for x in [-0.42, 0.42]:
				_add_shape(root, 1, Vector3(0.08, 0.64, 0.08), metal, false, Vector3(x, 0.62, 0.0), Vector3(0.0, 0.0, x * 28.0))
		9:
			_add_shape(root, 4, Vector3(1.52, 0.34, 1.04), Color("ff815d"), false, Vector3(0.0, 0.12, 0.0))
		10:
			_add_cone(root, 0.34, 0.92, metal, Vector3(0.0, 0.0, depth * 0.92), Vector3(90.0, 0.0, 0.0))
		11:
			for x in [-0.48, -0.24, 0.0, 0.24, 0.48]:
				_add_shape(root, 1, Vector3(0.05, 0.62 + abs(x) * 0.30, 0.05), accent, true, Vector3(x, 0.58, 0.0))
		12:
			_add_shape(root, 0, Vector3(1.12, 0.30, 0.16), Color("d8e2ea"), false, Vector3(0.0, -0.28, depth * 0.58))
			for x in [-0.34, 0.34]:
				_add_cone(root, 0.10, 0.32, Color("f4f7ff"), Vector3(x, -0.28, depth * 0.75), Vector3(90.0, 0.0, 0.0))
		13:
			_add_shape(root, 4, Vector3(0.78, 0.78, 0.18), Color("d66cff"), true, Vector3(0.0, 0.02, depth * 0.58), Vector3(0.0, 0.0, 45.0))
		14:
			_add_shape(root, 0, Vector3(1.18, 0.18, 0.12), accent, true, Vector3(0.0, 0.05, depth * 0.56))
		15:
			_add_shape(root, 0, Vector3(1.46, 0.12, 0.56), metal, false, Vector3(0.0, 0.52, -0.04))
		16:
			_add_shape(root, 2, Vector3(0.72, 0.72, 0.18), Color("ffd54e"), true, Vector3(0.0, 0.04, depth * 0.58))
		17:
			for x in [-0.46, 0.46]:
				_add_cone(root, 0.10, 0.72, accent, Vector3(x, 0.52, 0.0), Vector3(0.0, 0.0, -x * 36.0))
		18:
			_add_shape(root, 2, Vector3(0.52, 0.52, 0.20), Color("58beff"), true, Vector3(0.0, 0.08, depth * 0.57))
			_add_shape(root, 1, Vector3(0.06, 0.88, 0.06), metal, false, Vector3(0.0, 0.74, 0.0))
		19:
			for x in [-0.52, 0.0, 0.52]:
				_add_cone(root, 0.12, 0.62 + (0.16 if x == 0.0 else 0.0), accent, Vector3(x, 0.54, 0.0), Vector3(0.0, 0.0, -x * 35.0))

func _build_arm(root: Node3D, slot: String, index: int, metal: Color, accent: Color) -> void:
	var side := -1.0 if slot == "left_arm" else 1.0
	var side_name := "left" if side < 0.0 else "right"
	var upper_length := float(ARM_UPPER[index])
	var lower_length := float(ARM_LOWER[index])
	var width := float(ARM_WIDTH[index])
	root.position = Vector3(side * (1.22 + width * 0.25), 3.38, 0.0)
	_add_shape(root, 2, Vector3(width * 1.35, width * 1.35, width * 1.35), accent, true)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_add_shape(upper, index % 5, Vector3(width, upper_length, width * 1.05), metal, false, Vector3(0.0, -upper_length * 0.5, 0.0))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position.y = -upper_length
	upper.add_child(elbow)
	_add_shape(elbow, 2, Vector3(width * 1.10, width * 1.10, width * 1.10), accent, true)
	_add_shape(elbow, (index + 2) % 5, Vector3(width * 0.88, lower_length, width * 0.92), metal.darkened(0.06), false, Vector3(0.0, -lower_length * 0.5, 0.0))
	var hand := Node3D.new()
	hand.name = "WeaponMount"
	hand.position = Vector3(0.0, -lower_length, 0.0)
	elbow.add_child(hand)
	_add_shape(hand, 4, Vector3(width * 1.20, width * 0.62, width * 1.18), accent, true)
	motion_joints[slot + "_upper"] = upper
	motion_joints[slot + "_elbow"] = elbow
	weapon_mounts[side_name] = hand
	match index:
		0, 11, 16:
			for claw_side in [-1.0, 1.0]:
				_add_cone(hand, width * 0.22, 0.46, accent, Vector3(claw_side * width * 0.48, -0.30, 0.10), Vector3(0.0, 0.0, claw_side * 18.0))
		2:
			for y in range(4):
				_add_shape(upper, 1, Vector3(width * 1.25, 0.07, width * 1.25), accent, true, Vector3(0.0, -0.14 - y * upper_length / 4.5, 0.0))
		3:
			_add_shape(elbow, 1, Vector3(1.28, 0.16, 1.28), metal, false, Vector3(side * 0.42, -lower_length * 0.42, 0.0), Vector3(0.0, 0.0, 90.0))
		4, 10, 18:
			_add_shape(hand, 2, Vector3(width * 1.85, width * 1.55, width * 1.85), metal, false, Vector3(0.0, -width * 0.62, 0.0))
		5:
			for y in range(3):
				_add_shape(elbow, 1, Vector3(width * 0.78, lower_length * 0.22, width * 0.78), accent, true, Vector3(0.0, -0.18 - y * lower_length * 0.29, 0.0))
		6:
			_add_shape(upper, 1, Vector3(width * 1.55, 0.12, width * 1.55), accent, true, Vector3(0.0, -upper_length * 0.42, 0.0))
		7:
			for spike in [-1.0, 0.0, 1.0]:
				_add_cone(upper, 0.08, 0.48, accent, Vector3(spike * width * 0.70, -upper_length * 0.44, -0.10), Vector3(90.0, 0.0, 0.0))
		8:
			_add_shape(upper, 0, Vector3(0.12, 0.74, 1.28), accent, true, Vector3(side * width * 0.62, -upper_length * 0.48, -0.14), Vector3(20.0, 0.0, side * 18.0))
		9:
			_add_cone(hand, width * 0.42, 0.90, metal, Vector3(0.0, -0.54, 0.0))
		12:
			for y in range(3):
				_add_shape(upper, 1, Vector3(width * 1.12, 0.08, width * 1.12), Color("d6f1ff"), false, Vector3(0.0, -0.18 - y * 0.28, 0.0))
		13:
			_add_shape(elbow, 4, Vector3(width * 1.26, lower_length * 0.72, width * 1.26), accent, true, Vector3(0.0, -lower_length * 0.48, 0.0))
		14:
			for y in range(6):
				_add_shape(elbow, 2, Vector3(width * 0.70, width * 0.70, width * 0.70), accent, true, Vector3(0.0, -0.16 - y * lower_length / 6.0, 0.0))
		15:
			_add_shape(upper, 1, Vector3(width * 1.10, 0.62, width * 1.10), Color("ff805d"), true, Vector3(0.0, -upper_length * 0.38, -width * 0.82))
		17:
			_add_shape(elbow, 3, Vector3(width * 1.18, lower_length * 0.86, width * 1.18), Color(metal, 0.46), true, Vector3(0.0, -lower_length * 0.48, 0.0), Vector3.ZERO, true)
		19:
			for y in [-0.18, -0.48, -0.78]:
				_add_shape(elbow, 0, Vector3(width * 1.38, 0.08, width * 1.38), accent, true, Vector3(0.0, y * lower_length, 0.0), Vector3(0.0, float(y) * 80.0, 0.0))

func _build_leg(root: Node3D, slot: String, index: int, metal: Color, accent: Color) -> void:
	var side := -1.0 if slot == "left_leg" else 1.0
	var upper_length := float(LEG_UPPER[index])
	var lower_length := float(LEG_LOWER[index])
	var width := float(LEG_WIDTH[index])
	root.position = Vector3(side * 0.56, 2.12, 0.0)
	_add_shape(root, 2, Vector3(width * 1.14, width * 1.14, width * 1.14), accent, true)
	var upper := Node3D.new()
	upper.name = "Upper"
	root.add_child(upper)
	_add_shape(upper, index % 5, Vector3(width, upper_length, width * 1.12), metal, false, Vector3(0.0, -upper_length * 0.5, 0.0))
	var knee := Node3D.new()
	knee.name = "Knee"
	knee.position.y = -upper_length
	upper.add_child(knee)
	_add_shape(knee, 2, Vector3(width * 1.08, width * 1.08, width * 1.08), accent, true, Vector3(0.0, 0.0, width * 0.22))
	if index in [2, 3, 12]:
		_add_shape(knee, 1, Vector3(width * 1.65, lower_length * 1.16, width * 1.65), metal, false, Vector3(0.0, -lower_length * 0.48, 0.0), Vector3(90.0, 0.0, 0.0))
	else:
		_add_shape(knee, (index + 1) % 5, Vector3(width * 0.90, lower_length, width), metal.darkened(0.06), false, Vector3(0.0, -lower_length * 0.5, 0.0))
	var foot_y := -lower_length
	var foot_size := Vector3(width * 1.42, width * 0.56, width * (2.25 if index in [1, 8, 13, 16] else 1.72))
	_add_shape(knee, 0, foot_size, accent.darkened(0.12), false, Vector3(0.0, foot_y, foot_size.z * 0.20))
	motion_joints[slot + "_upper"] = upper
	motion_joints[slot + "_knee"] = knee
	match index:
		1, 7:
			_add_shape(knee, 1, Vector3(width * 1.20, 0.12, width * 1.20), accent, true, Vector3(0.0, -lower_length * 0.44, 0.0))
		4:
			for leg_side in [-1.0, 1.0]:
				_add_cone(upper, 0.08, 0.58, accent, Vector3(leg_side * width * 0.72, -upper_length * 0.40, 0.0), Vector3(0.0, 0.0, leg_side * 30.0))
		5, 9, 15:
			for x in [-0.22, 0.22]:
				_add_shape(knee, 1, Vector3(width * 0.46, 0.58, width * 0.46), Color("ff8a5b"), true, Vector3(x, -lower_length * 0.60, -width * 0.68))
		6:
			_add_shape(knee, 0, Vector3(width * 1.34, 0.12, width * 1.42), accent, true, Vector3(0.0, foot_y + 0.12, 0.10))
		10:
			for claw_x in [-0.32, 0.0, 0.32]:
				_add_cone(knee, 0.08, 0.44, accent, Vector3(claw_x, foot_y - 0.05, foot_size.z * 0.72), Vector3(90.0, 0.0, 0.0))
		11:
			for y in range(3):
				_add_shape(knee, 1, Vector3(width * 1.14, 0.08, width * 1.14), accent, true, Vector3(0.0, -0.18 - y * 0.30, 0.0))
		14:
			_add_shape(upper, 0, Vector3(width * 1.45, upper_length * 0.36, width * 1.35), metal.darkened(0.18), false, Vector3(0.0, -upper_length * 0.28, 0.0))
		16:
			_add_shape(upper, 2, Vector3(width * 1.25, width * 1.25, width * 1.25), accent, true, Vector3(0.0, -upper_length * 0.35, 0.0))
		17:
			_add_cone(knee, width * 0.34, 0.64, metal, Vector3(0.0, -lower_length * 0.44, width * 0.70), Vector3(90.0, 0.0, 0.0))
		18:
			_add_shape(knee, 4, Vector3(width * 1.16, lower_length * 0.74, width * 1.16), accent, true, Vector3(0.0, -lower_length * 0.45, 0.0))
		19:
			for y in [-0.22, -0.52, -0.82]:
				_add_shape(knee, 0, Vector3(width * 1.36, 0.07, width * 1.36), accent, true, Vector3(0.0, y * lower_length, 0.0))

func _build_weapon(root: Node3D, index: int, metal: Color, accent: Color, side: float) -> void:
	root.position = Vector3(0.0, -0.22, 0.10)
	match index:
		0:
			_add_shape(root, 1, Vector3(0.16, 1.18, 0.16), metal, false, Vector3(0.0, -0.18, 0.0))
			_add_shape(root, 0, Vector3(1.08, 0.56, 0.48), accent, true, Vector3(0.0, -0.88, 0.0))
		1:
			_add_shape(root, 1, Vector3(0.14, 0.54, 0.14), metal, false, Vector3(0.0, -0.12, 0.0))
			_add_shape(root, 0, Vector3(0.18, 1.56, 0.12), accent, true, Vector3(0.0, -1.10, 0.0))
		2:
			_add_shape(root, 2, Vector3(0.72, 0.66, 0.72), metal, false, Vector3(0.0, -0.38, 0.12))
			for x in [-0.24, 0.0, 0.24]:
				_add_cone(root, 0.06, 0.36, accent, Vector3(x, -0.64, 0.22), Vector3(90.0, 0.0, 0.0))
		3:
			_add_shape(root, 1, Vector3(0.52, 1.10, 0.52), metal, false, Vector3(0.0, -0.36, 0.0))
			_add_shape(root, 2, Vector3(0.48, 0.48, 0.48), Color("74e8ff"), true, Vector3(0.0, -0.95, 0.0), Vector3.ZERO, true)
		4:
			_add_shape(root, 1, Vector3(1.08, 0.18, 1.08), metal, false, Vector3(0.0, -0.72, 0.0), Vector3(90.0, 0.0, 0.0))
			for angle in range(0, 360, 45):
				_add_cone(root, 0.06, 0.30, accent, Vector3(cos(deg_to_rad(angle)) * 0.62, -0.72, sin(deg_to_rad(angle)) * 0.62), Vector3(90.0, 0.0, -float(angle)))
		5:
			_add_shape(root, 1, Vector3(0.12, 2.18, 0.12), metal, false, Vector3(0.0, -0.92, 0.0))
			_add_cone(root, 0.16, 0.52, accent, Vector3(0.0, -2.20, 0.0))
		6:
			_add_shape(root, 1, Vector3(0.46, 1.18, 0.46), metal, false, Vector3(0.0, -0.42, 0.0))
			_add_shape(root, 0, Vector3(0.26, 0.22, 0.92), Color("a8f6ff"), true, Vector3(0.0, -0.92, 0.44))
		7:
			_add_shape(root, 1, Vector3(0.07, 1.22, 0.07), metal, false, Vector3(0.0, -0.64, 0.0))
			_add_shape(root, 1, Vector3(0.72, 0.16, 0.72), accent, true, Vector3(0.0, -1.34, 0.0), Vector3(90.0, 0.0, 0.0))
		8:
			_add_shape(root, 1, Vector3(0.42, 0.84, 0.42), metal, false, Vector3(0.0, -0.34, 0.0))
			_add_cone(root, 0.34, 0.96, accent, Vector3(0.0, -1.22, 0.0))
		9:
			_add_shape(root, 1, Vector3(1.28, 0.14, 1.28), metal, false, Vector3(0.0, -0.62, 0.0), Vector3(90.0, 0.0, 0.0))
			_add_shape(root, 0, Vector3(0.18, 1.08, 0.18), accent, true, Vector3(side * 0.54, -0.64, 0.0), Vector3(0.0, 0.0, side * 28.0))
		10:
			_add_shape(root, 1, Vector3(0.16, 1.20, 0.16), metal, false, Vector3(0.0, -0.25, 0.0))
			_add_shape(root, 2, Vector3(0.92, 0.92, 0.92), accent, true, Vector3(0.0, -1.05, 0.0))
		11:
			_add_shape(root, 0, Vector3(0.64, 0.82, 0.54), metal, false, Vector3(0.0, -0.38, 0.0))
			for x in [-0.20, 0.20]:
				_add_shape(root, 1, Vector3(0.12, 0.86, 0.12), Color("ffd85d"), true, Vector3(x, -0.86, 0.0))
		12:
			for link in range(7):
				_add_shape(root, 2, Vector3(0.16, 0.16, 0.16), accent, true, Vector3(sin(float(link) * 0.8) * 0.18, -0.34 - link * 0.22, 0.0))
		13:
			_add_shape(root, 1, Vector3(0.14, 1.08, 0.14), metal, false, Vector3(0.0, -0.36, 0.0))
			_add_shape(root, 0, Vector3(1.18, 0.68, 0.14), accent, true, Vector3(side * 0.22, -1.00, 0.0), Vector3(0.0, 0.0, side * 26.0))
		14:
			for segment in range(4):
				_add_shape(root, 1, Vector3(0.34 - segment * 0.05, 0.28, 0.34 - segment * 0.05), metal, false, Vector3(0.0, -0.30 - segment * 0.25, 0.0))
			_add_shape(root, 2, Vector3(0.56, 0.52, 0.56), accent, true, Vector3(0.0, -1.38, 0.0))
		15:
			_add_shape(root, 1, Vector3(0.52, 1.10, 0.52), metal, false, Vector3(0.0, -0.38, 0.0))
			_add_shape(root, 0, Vector3(0.72, 0.08, 0.72), Color("d4f8ff"), true, Vector3(0.0, -1.00, 0.34), Vector3(45.0, 0.0, 0.0), true)
		16:
			_add_shape(root, 1, Vector3(0.10, 2.36, 0.10), accent, true, Vector3(0.0, -1.02, 0.0))
			_add_cone(root, 0.20, 0.62, Color("ff9d5d"), Vector3(0.0, -2.46, 0.0))
		17:
			_add_shape(root, 1, Vector3(1.14, 0.13, 1.14), Color("d477ff"), true, Vector3(0.0, -0.72, 0.0), Vector3(90.0, 0.0, 0.0))
			_add_shape(root, 4, Vector3(0.62, 0.20, 0.62), accent, true, Vector3(0.0, -0.72, 0.0))
		18:
			for pole in [-1.0, 1.0]:
				_add_shape(root, 0, Vector3(0.24, 1.18, 0.26), Color("ff5d76") if pole < 0.0 else Color("7dc9ff"), true, Vector3(pole * 0.25, -0.70, 0.0))
		19:
			_add_shape(root, 2, Vector3(0.92, 0.92, 0.92), Color("b86cff"), true, Vector3(0.0, -0.82, 0.0), Vector3.ZERO, true)
			for angle in range(0, 360, 90):
				_add_shape(root, 2, Vector3(0.18, 0.18, 0.18), accent, true, Vector3(cos(deg_to_rad(angle)) * 0.68, -0.82, sin(deg_to_rad(angle)) * 0.68))

func _add_joint_lights() -> void:
	for point in [Vector3(-0.56, 2.08, 0.44), Vector3(0.56, 2.08, 0.44), Vector3(0.0, 3.58, 0.58)]:
		_add_shape(self, 2, Vector3(0.13, 0.13, 0.13), Color("fff173"), true, point)

func _add_cone(parent: Node3D, radius: float, height: float, color: Color, offset := Vector3.ZERO, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.025
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 10
	return _add_mesh(parent, cone, color, false, offset, rotation_degrees, false)

func _add_shape(parent: Node3D, shape: int, size: Vector3, color: Color, glow: bool, offset := Vector3.ZERO, rotation_degrees := Vector3.ZERO, transparent := false) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	match shape % 5:
		0:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		1:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = maxf(0.04, minf(size.x, size.z) * 0.5)
			cylinder.bottom_radius = cylinder.top_radius * 0.82
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
			bevel.top_radius = minf(size.x, size.z) * 0.36
			bevel.bottom_radius = minf(size.x, size.z) * 0.52
			bevel.height = size.y
			bevel.radial_segments = 6
			mesh = bevel
	return _add_mesh(parent, mesh, color, glow, offset, rotation_degrees, transparent)

func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, color: Color, glow: bool, offset: Vector3, rotation_degrees: Vector3, transparent: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72
	material.roughness = 0.22 if glow else 0.42
	if transparent or color.a < 0.98:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = minf(color.a, 0.56)
	if glow:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b) * 1.45
		material.emission_energy_multiplier = 1.35
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.rotation_degrees = rotation_degrees
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance

func _animate_join(root: Node3D, order: int) -> void:
	var destination := root.position
	var angle := float(order) * 0.91
	root.position = destination + Vector3(cos(angle) * 5.4, 2.0 + order * 0.12, sin(angle) * 3.8)
	root.scale = Vector3.ONE * 0.14
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position", destination, 0.40)
	tween.parallel().tween_property(root, "scale", Vector3.ONE, 0.40)
