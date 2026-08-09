class_name ArenaFighter
extends CharacterBody3D

signal health_changed(fighter_id: int, ratio: float, current: float, maximum: float)
signal defeated(fighter_id: int)
signal combat_event(message: String, color: Color)

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")

var fighter_id := 0
var build := {}
var stats := {}
var hp := 1.0
var max_hp := 1.0
var opponent: ArenaFighter
var model: RobotModel
var active := false
var attack_cooldown := 0.0
var think_offset := 0.0
var attack_count := 0
var arena_radius := 6.15
var team_color := Color.WHITE
var display_name := "ROBOT"
var _rng := RandomNumberGenerator.new()
var _strafe_direction := 1.0

func setup_robot(new_build: Dictionary, tint: Color, stat_multiplier: float, new_id: int, robot_name: String) -> void:
	fighter_id = new_id
	build = new_build.duplicate(true)
	team_color = tint
	display_name = robot_name
	stats = Catalog.build_stats(build)
	stats.health *= stat_multiplier
	stats.power *= stat_multiplier
	stats.armor *= sqrt(stat_multiplier)
	stats.energy *= stat_multiplier
	max_hp = float(stats.health)
	hp = max_hp
	_rng.seed = int(Time.get_ticks_usec()) + new_id * 7919 + int(max_hp)
	think_offset = _rng.randf_range(0.0, 0.45)
	_strafe_direction = -1.0 if _rng.randi() % 2 == 0 else 1.0
	model = RobotModelScript.new()
	add_child(model)
	model.build_robot(build, tint)
	model.remember_floor_height()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.82
	capsule.height = 4.8
	collision.shape = capsule
	collision.position.y = 2.25
	add_child(collision)
	health_changed.emit(fighter_id, 1.0, hp, max_hp)

func set_opponent(value: ArenaFighter) -> void:
	opponent = value

func begin_fight() -> void:
	active = true
	attack_cooldown = 0.65 + think_offset
	model.set_moving(false)

func stop_fight() -> void:
	active = false
	velocity = Vector3.ZERO
	if model:
		model.set_moving(false)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(opponent) or opponent.hp <= 0.0:
		velocity = Vector3.ZERO
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var difference := opponent.global_position - global_position
	difference.y = 0.0
	var distance := difference.length()
	if distance > 0.05:
		look_at(opponent.global_position, Vector3.UP)
	var preferred_range := clampf(float(stats.range) * 0.70, 1.75, 5.4)
	var move_direction := Vector3.ZERO
	if distance > preferred_range:
		move_direction = difference.normalized()
	elif distance < preferred_range * 0.58:
		move_direction = -difference.normalized() * 0.72
	else:
		move_direction = difference.normalized().cross(Vector3.UP) * _strafe_direction * 0.45
	var movement_speed := float(stats.speed) * (0.72 if distance < preferred_range else 1.0)
	velocity = move_direction * movement_speed
	move_and_slide()
	_keep_inside_ring()
	model.set_moving(velocity.length() > 0.35)
	if attack_cooldown <= 0.0 and distance <= float(stats.range):
		_perform_attack(distance)

func _perform_attack(distance: float) -> void:
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		return
	attack_count += 1
	var use_left := attack_count % 2 == 0
	var special_every := maxi(3, 7 - int(float(stats.energy) / 55.0))
	var special := attack_count % special_every == 0
	var damage := float(stats.power) * _rng.randf_range(0.82, 1.16)
	if special:
		damage *= 1.58
		combat_event.emit("¡%s activa SOBRECARGA!" % display_name, team_color)
	if _rng.randf() < 0.11:
		damage *= 1.45
		combat_event.emit("¡GOLPE CRÍTICO!", Color("fff173"))
	model.play_attack(use_left, special)
	var is_ranged := float(stats.range) >= 4.35 and distance > 2.3
	if is_ranged:
		_launch_energy_orb(opponent, damage, special)
	else:
		opponent.take_damage(damage, global_position, special)
	var speed_factor := clampf((float(stats.speed) - 3.0) * 0.055, 0.0, 0.38)
	attack_cooldown = maxf(0.38, 1.18 - speed_factor)
	if special:
		attack_cooldown += 0.28

func take_damage(raw_damage: float, source_position: Vector3, heavy: bool) -> void:
	if not active or hp <= 0.0:
		return
	var reduction := 100.0 / (100.0 + float(stats.armor) * 2.35)
	var final_damage := maxf(2.0, raw_damage * reduction)
	hp = maxf(0.0, hp - final_damage)
	model.play_hit()
	var away := global_position - source_position
	away.y = 0.0
	if away.length() > 0.05:
		velocity += away.normalized() * (4.8 if heavy else 2.3)
	health_changed.emit(fighter_id, hp / max_hp, hp, max_hp)
	if hp <= 0.0:
		active = false
		velocity = Vector3.ZERO
		model.play_defeat()
		combat_event.emit("%s queda fuera de combate" % display_name, team_color.lightened(0.2))
		defeated.emit(fighter_id)

func force_defeat() -> void:
	if hp <= 0.0:
		return
	hp = 0.0
	active = false
	health_changed.emit(fighter_id, 0.0, hp, max_hp)
	model.play_defeat()
	defeated.emit(fighter_id)

func _launch_energy_orb(victim: ArenaFighter, damage: float, heavy: bool) -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18 if not heavy else 0.30
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = team_color
	material.emission_enabled = true
	material.emission = team_color * 1.8
	material.emission_energy_multiplier = 1.8
	sphere.material = material
	orb.mesh = sphere
	get_parent().add_child(orb)
	orb.global_position = global_position + Vector3(0.0, 2.7, 0.0)
	var destination := victim.global_position + Vector3(0.0, 2.4, 0.0)
	var travel_time := clampf(global_position.distance_to(victim.global_position) / 15.0, 0.12, 0.42)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "global_position", destination, travel_time)
	tween.tween_callback(func() -> void:
		if is_instance_valid(victim):
			victim.take_damage(damage, global_position, heavy)
		if is_instance_valid(orb):
			orb.queue_free()
	)

func _keep_inside_ring() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() <= arena_radius:
		return
	flat = flat.normalized() * arena_radius
	global_position.x = flat.x
	global_position.z = flat.y
	velocity *= 0.35
