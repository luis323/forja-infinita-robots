class_name ArenaFighter
extends CharacterBody3D

signal health_changed(fighter_id: int, ratio: float, current: float, maximum: float)
signal defeated(fighter_id: int)
signal combat_event(message: String, color: Color)
signal sfx_requested(kind: String, pitch: float)
signal impact(strength: float, impact_position: Vector3)

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")

var fighter_id := 0
var build := {}
var stats := {}
var hp := 1.0
var max_hp := 1.0
var opponent: ArenaFighter
var opponents: Array[ArenaFighter] = []
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
var _impulse_velocity := Vector3.ZERO
var _step_timer := 0.0
var _maneuver_timer := 1.0
var _motion_time := 0.0
var _target_timer := 0.0
var heavy_cooldown := 0.0
var _manual_heavy_requested := false

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
	var deterministic_seed := 1171 + new_id * 7919
	for slot in Catalog.SLOTS:
		deterministic_seed = deterministic_seed * 31 + int(build.get(slot, 0)) * 97
	_rng.seed = deterministic_seed
	think_offset = float(abs(deterministic_seed) % 40) / 100.0
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
	opponents.clear()
	if is_instance_valid(value):
		opponents.append(value)

func set_opponents(values: Array[ArenaFighter]) -> void:
	opponents = values.duplicate()
	_choose_target()

func request_heavy_attack() -> bool:
	if not active or hp <= 0.0 or heavy_cooldown > 0.0:
		return false
	_manual_heavy_requested = true
	heavy_cooldown = clampf(6.8 - float(stats.energy) * 0.012, 4.6, 6.0)
	combat_event.emit("%s PREPARA GOLPE FUERTE" % display_name, team_color)
	return true

func begin_fight() -> void:
	active = true
	attack_cooldown = 0.65 + think_offset
	heavy_cooldown = 0.0
	_manual_heavy_requested = false
	_maneuver_timer = 0.8 + think_offset
	model.set_moving(false)

func stop_fight() -> void:
	active = false
	velocity = Vector3.ZERO
	_impulse_velocity = Vector3.ZERO
	if model:
		model.set_moving(false)

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	heavy_cooldown = maxf(0.0, heavy_cooldown - delta)
	_target_timer = maxf(0.0, _target_timer - delta)
	if _target_timer <= 0.0 or not is_instance_valid(opponent) or opponent.hp <= 0.0:
		_choose_target()
		_target_timer = 0.30
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		velocity = Vector3.ZERO
		return
	_step_timer = maxf(0.0, _step_timer - delta)
	_maneuver_timer = maxf(0.0, _maneuver_timer - delta)
	_motion_time += delta
	_impulse_velocity = _impulse_velocity.move_toward(Vector3.ZERO, delta * 9.5)
	var difference := opponent.global_position - global_position
	difference.y = 0.0
	var distance := difference.length()
	if distance > 0.05:
		look_at(opponent.global_position, Vector3.UP, true)
	var preferred_range := clampf(float(stats.range) * 0.70, 1.75, 5.4)
	var move_direction := Vector3.ZERO
	if _manual_heavy_requested and distance > float(stats.range) * 1.22:
		move_direction = difference.normalized() * 1.42
	elif distance > preferred_range:
		move_direction = difference.normalized()
	elif distance < preferred_range * 0.58:
		move_direction = -difference.normalized() * 0.72
	else:
		var weave := 0.46 + sin(_motion_time * 2.8 + float(fighter_id) * 1.7) * 0.20
		move_direction = difference.normalized().cross(Vector3.UP) * _strafe_direction * weave
		move_direction += difference.normalized() * sin(_motion_time * 1.9) * 0.16
	if _maneuver_timer <= 0.0 and distance < preferred_range * 1.35:
		var dodge_direction := difference.normalized().cross(Vector3.UP) * _strafe_direction
		_impulse_velocity += dodge_direction * _rng.randf_range(2.4, 4.0)
		_strafe_direction *= -1.0
		_maneuver_timer = _rng.randf_range(1.25, 2.35)
	var movement_speed := float(stats.speed) * (0.72 if distance < preferred_range else 1.0)
	velocity = move_direction * movement_speed + _impulse_velocity
	move_and_slide()
	_keep_inside_ring()
	var walking := velocity.length() > 0.35
	model.set_moving(walking)
	if walking and _step_timer <= 0.0:
		sfx_requested.emit("step", 0.88 + float(fighter_id) * 0.10 + _rng.randf_range(-0.04, 0.04))
		_step_timer = clampf(0.48 - float(stats.speed) * 0.025, 0.24, 0.40)
	if _manual_heavy_requested and distance <= float(stats.range) * 1.22:
		_perform_manual_heavy()
	elif attack_cooldown <= 0.0 and distance <= float(stats.range):
		_perform_attack(distance)

func _choose_target() -> void:
	var nearest: ArenaFighter
	var nearest_distance := INF
	for candidate in opponents:
		if not is_instance_valid(candidate) or candidate == self or candidate.hp <= 0.0:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	opponent = nearest

func _perform_attack(distance: float) -> void:
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		return
	attack_count += 1
	var use_left := attack_count % 2 == 0
	var special_every := maxi(3, 7 - int(float(stats.energy) / 55.0))
	var special := attack_count % special_every == 0
	var damage_variation := 0.96 + float((attack_count * 13 + fighter_id * 5) % 9) * 0.01
	var damage := float(stats.power) * damage_variation
	if special:
		damage *= 1.58
		combat_event.emit("¡%s activa SOBRECARGA!" % display_name, team_color)
	if attack_count % 8 == 0:
		damage *= 1.45
		combat_event.emit("¡GOLPE CRÍTICO!", Color("fff173"))
	var accuracy_roll := float((attack_count * 37 + fighter_id * 19) % 100)
	if not special and accuracy_roll > float(stats.accuracy):
		combat_event.emit("%s FALLA EL ATAQUE" % display_name, Color("d7e1ef"))
		model.play_attack(use_left, false)
		attack_cooldown = maxf(0.28, 1.12 / float(stats.attack_speed))
		return
	var attack_affinity := Catalog.weapon_affinity(build, use_left)
	var defend_affinity := Catalog.dominant_affinity(opponent.build)
	var affinity_bonus := Catalog.affinity_multiplier(attack_affinity, defend_affinity)
	damage *= affinity_bonus
	if affinity_bonus > 1.2:
		combat_event.emit("¡VENTAJA %s!" % Catalog.AFFINITY_NAMES[attack_affinity], Catalog.AFFINITY_COLORS[attack_affinity])
	elif affinity_bonus < 0.8:
		combat_event.emit("ATAQUE POCO EFECTIVO", Color("b9c5d7"))
	model.play_attack(use_left, special)
	var is_ranged := float(stats.range) >= 4.35 and distance > 2.3
	if is_ranged:
		sfx_requested.emit("shot", 0.90 + _rng.randf_range(-0.06, 0.10))
		_launch_energy_orb(opponent, damage, special)
	else:
		sfx_requested.emit("swing", 0.86 if special else 1.0 + _rng.randf_range(-0.08, 0.10))
		var rush := opponent.global_position - global_position
		rush.y = 0.0
		if rush.length() > 0.05:
			_impulse_velocity += rush.normalized() * (5.8 if special else 3.4)
		opponent.take_damage(damage, global_position, special)
		if attack_count % 4 == 0 and not special:
			get_tree().create_timer(0.14).timeout.connect(_combo_strike.bind(opponent, damage * 0.34, global_position))
	attack_cooldown = maxf(0.28, 1.12 / float(stats.attack_speed))
	if special:
		attack_cooldown += 0.28

func _perform_manual_heavy() -> void:
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		_manual_heavy_requested = false
		return
	_manual_heavy_requested = false
	attack_count += 1
	var use_left := attack_count % 2 == 0
	var attack_affinity := Catalog.weapon_affinity(build, use_left)
	var defend_affinity := Catalog.dominant_affinity(opponent.build)
	var damage := float(stats.power) * 2.05 * Catalog.affinity_multiplier(attack_affinity, defend_affinity)
	model.play_attack(use_left, true)
	sfx_requested.emit("heavy", 0.82)
	var rush := opponent.global_position - global_position
	rush.y = 0.0
	if rush.length() > 0.05:
		_impulse_velocity += rush.normalized() * 8.5
	opponent.take_damage(damage, global_position, true)
	combat_event.emit("¡GOLPE FUERTE DE %s!" % display_name, team_color)
	attack_cooldown = 0.82

func _combo_strike(victim: ArenaFighter, damage: float, source_position: Vector3) -> void:
	if not active or not is_instance_valid(victim) or victim.hp <= 0.0:
		return
	sfx_requested.emit("swing", 1.18)
	model.play_attack(attack_count % 2 != 0, false)
	victim.take_damage(damage, source_position, false)

func take_damage(raw_damage: float, source_position: Vector3, heavy: bool) -> void:
	if not active or hp <= 0.0:
		return
	var reduction := 100.0 / (100.0 + float(stats.armor) * 2.35)
	var final_damage := maxf(2.0, raw_damage * reduction)
	hp = maxf(0.0, hp - final_damage)
	model.play_hit()
	sfx_requested.emit("heavy" if heavy else "hit", 0.92 + _rng.randf_range(-0.07, 0.08))
	impact.emit(0.38 if heavy else 0.18, global_position + Vector3(0.0, 2.2, 0.0))
	_spawn_impact_sparks(heavy)
	var away := global_position - source_position
	away.y = 0.0
	if away.length() > 0.05:
		var stability_factor := clampf(1.18 - float(stats.stability) / 105.0, 0.32, 1.0)
		_impulse_velocity += away.normalized() * (7.2 if heavy else 3.5) * stability_factor
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
	tween.parallel().tween_property(orb, "scale", Vector3.ONE * (1.8 if heavy else 1.35), travel_time)
	tween.tween_callback(func() -> void:
		if is_instance_valid(victim):
			victim.take_damage(damage, global_position, heavy)
		if is_instance_valid(orb):
			orb.queue_free()
	)

func _spawn_impact_sparks(heavy: bool) -> void:
	var spark_count := 9 if heavy else 5
	for index in range(spark_count):
		var spark := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.055 if not heavy else 0.075
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 6
		sphere.rings = 3
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("fff27a")
		material.emission_enabled = true
		material.emission = Color("ff9d45") * 2.0
		sphere.material = material
		spark.mesh = sphere
		get_parent().add_child(spark)
		spark.global_position = global_position + Vector3(0.0, 2.2, 0.0)
		var angle := TAU * float(index) / float(spark_count) + _rng.randf_range(-0.28, 0.28)
		var destination := spark.global_position + Vector3(cos(angle), _rng.randf_range(-0.15, 0.85), sin(angle)) * (1.2 if heavy else 0.72)
		var spark_tween := spark.create_tween()
		spark_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "global_position", destination, 0.25)
		spark_tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.28)
		spark_tween.tween_callback(spark.queue_free)

func _keep_inside_ring() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() <= arena_radius:
		return
	flat = flat.normalized() * arena_radius
	global_position.x = flat.x
	global_position.z = flat.y
	velocity *= 0.35
