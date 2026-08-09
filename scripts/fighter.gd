class_name ArenaFighter
extends CharacterBody3D

signal health_changed(fighter_id: int, ratio: float, current: float, maximum: float)
signal defeated(fighter_id: int)
signal combat_event(message: String, color: Color)
signal sfx_requested(kind: String, pitch: float)
signal impact(strength: float, impact_position: Vector3)

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")
const CUTTING_WEAPONS := [1, 2, 4, 5, 8, 13, 16]
const FORCE_WEAPONS := [0, 7, 9, 10, 14, 19]
const PART_LABELS := {
	"head": "CABEZA",
	"left_arm": "BRAZO IZQUIERDO",
	"right_arm": "BRAZO DERECHO",
	"left_weapon": "ARMA IZQUIERDA",
	"right_weapon": "ARMA DERECHA",
}
const PERSONALITY_NAMES := ["AGRESIVO", "TÁCTICO", "PESO PESADO", "ACROBÁTICO"]

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
var _manual_use_left := true
var _next_manual_left := true
var detached_parts := {}
var joint_integrity := {}
var joint_maximum := {}
var personality_id := 0
var personality_name := "AGRESIVO"
var auto_tool_enabled := false
var _auto_tool_timer := 4.0
var _personality_timer := 1.8
var _personality_actions := 0
var _stagger_time := 0.0
var _brace_time := 0.0
var _received_hits := 0

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
	detached_parts.clear()
	var joint_strength := 68.0 + float(stats.armor) * 1.15 + float(stats.stability) * 0.42
	joint_maximum = {
		"left_weapon": joint_strength * 0.62,
		"right_weapon": joint_strength * 0.62,
		"left_arm": joint_strength,
		"right_arm": joint_strength,
		"head": joint_strength * 1.18,
	}
	joint_integrity = joint_maximum.duplicate(true)
	var deterministic_seed := 1171 + new_id * 7919
	for slot in Catalog.SLOTS:
		deterministic_seed = deterministic_seed * 31 + int(build.get(slot, 0)) * 97
	_rng.seed = deterministic_seed
	think_offset = float(abs(deterministic_seed) % 40) / 100.0
	_strafe_direction = -1.0 if _rng.randi() % 2 == 0 else 1.0
	personality_id = _personality_from_stats(stats, deterministic_seed)
	personality_name = PERSONALITY_NAMES[personality_id]
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

static func _personality_from_stats(robot_stats: Dictionary, seed_value: int) -> int:
	if float(robot_stats.speed) >= 5.8 or float(robot_stats.attack_speed) >= 1.55:
		return 3
	if float(robot_stats.armor) >= 48.0 or float(robot_stats.stability) >= 62.0:
		return 2
	if float(robot_stats.range) >= 4.55 or float(robot_stats.accuracy) >= 82.0:
		return 1
	return abs(seed_value) % 2

func request_heavy_attack() -> bool:
	if not active or hp <= 0.0 or heavy_cooldown > 0.0 or not has_manual_weapon():
		return false
	_manual_use_left = _choose_attack_side(_next_manual_left)
	_next_manual_left = not _manual_use_left
	_manual_heavy_requested = true
	heavy_cooldown = clampf(6.8 - float(stats.energy) * 0.012, 4.6, 6.0)
	combat_event.emit("%s PREPARA %s" % [display_name, _action_label_for_side(_manual_use_left)], team_color)
	return true

func has_manual_weapon() -> bool:
	if not is_instance_valid(model):
		return false
	return _side_available(true) or _side_available(false)

func manual_action_label() -> String:
	if not has_manual_weapon():
		return "SIN ARMA"
	var use_left := _choose_attack_side(_next_manual_left)
	return _action_label_for_side(use_left)

func _action_label_for_side(use_left: bool) -> String:
	var slot := "left_weapon" if use_left else "right_weapon"
	var names := Catalog.names_for(slot)
	var weapon_name := str(names[int(build.get(slot, 0))]).to_upper()
	if weapon_name.length() > 15:
		weapon_name = weapon_name.substr(0, 15)
	return "USAR " + weapon_name

func _side_available(use_left: bool) -> bool:
	var side := "left" if use_left else "right"
	return model.has_part(side + "_arm") and model.has_part(side + "_weapon")

func _arm_available(use_left: bool) -> bool:
	var side := "left" if use_left else "right"
	return model.has_part(side + "_arm")

func _choose_attack_side(prefer_left: bool) -> bool:
	if _side_available(prefer_left):
		return prefer_left
	if _side_available(not prefer_left):
		return not prefer_left
	return prefer_left

func _choose_arm_side(prefer_left: bool) -> bool:
	if _arm_available(prefer_left):
		return prefer_left
	if _arm_available(not prefer_left):
		return not prefer_left
	return prefer_left

func begin_fight() -> void:
	active = true
	attack_cooldown = 0.65 + think_offset
	heavy_cooldown = 0.0
	_manual_heavy_requested = false
	_maneuver_timer = 0.8 + think_offset
	_personality_timer = 1.15 + think_offset
	_auto_tool_timer = 3.6 + think_offset + float(personality_id) * 0.28
	_stagger_time = 0.0
	_brace_time = 0.0
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
	_auto_tool_timer = maxf(0.0, _auto_tool_timer - delta)
	_personality_timer = maxf(0.0, _personality_timer - delta)
	_stagger_time = maxf(0.0, _stagger_time - delta)
	_brace_time = maxf(0.0, _brace_time - delta)
	_target_timer = maxf(0.0, _target_timer - delta)
	if _target_timer <= 0.0 or not is_instance_valid(opponent) or opponent.hp <= 0.0:
		_choose_target()
		_target_timer = 0.30
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		velocity = Vector3.ZERO
		return
	if auto_tool_enabled and _auto_tool_timer <= 0.0 and heavy_cooldown <= 0.0 and has_manual_weapon():
		request_heavy_attack()
		_auto_tool_timer = 7.2 - float(personality_id) * 0.35 + think_offset
	_step_timer = maxf(0.0, _step_timer - delta)
	_maneuver_timer = maxf(0.0, _maneuver_timer - delta)
	_motion_time += delta
	_impulse_velocity = _impulse_velocity.move_toward(Vector3.ZERO, delta * 9.5)
	if _stagger_time > 0.0:
		velocity = _impulse_velocity
		move_and_slide()
		_keep_inside_ring()
		model.set_moving(false)
		return
	var difference := opponent.global_position - global_position
	difference.y = 0.0
	var distance := difference.length()
	if distance > 0.05:
		look_at(opponent.global_position, Vector3.UP, true)
	var preferred_range := clampf(float(stats.range) * 0.70, 1.75, 5.4)
	match personality_id:
		0:
			preferred_range *= 0.76
		1:
			preferred_range *= 1.18
		2:
			preferred_range *= 0.88
		3:
			preferred_range *= 1.04
	var move_direction := Vector3.ZERO
	var contact_range := _melee_contact_range()
	if _manual_heavy_requested and distance > contact_range:
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
	if _personality_timer <= 0.0 and distance < preferred_range * 1.65:
		_perform_personality_action(difference)
		_personality_timer = 1.65 + float((_personality_actions + fighter_id) % 4) * 0.34
	var personality_speed: float = [1.08, 0.94, 0.78, 1.14][personality_id]
	var movement_speed := float(stats.speed) * 0.82 * personality_speed * (0.72 if distance < preferred_range else 1.0)
	velocity = move_direction * movement_speed + _impulse_velocity
	move_and_slide()
	_keep_inside_ring()
	var walking := velocity.length() > 0.35
	model.set_moving(walking)
	if walking and _step_timer <= 0.0:
		sfx_requested.emit("step", 0.88 + float(fighter_id) * 0.10 + _rng.randf_range(-0.04, 0.04))
		_step_timer = clampf(0.48 - float(stats.speed) * 0.025, 0.24, 0.40)
	if _manual_heavy_requested and distance <= contact_range:
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

func _melee_contact_range() -> float:
	return clampf(2.30 + float(stats.range) * 0.18, 2.45, 3.55)

func _perform_personality_action(difference: Vector3) -> void:
	if difference.length() < 0.05:
		return
	_personality_actions += 1
	var forward := difference.normalized()
	var side := forward.cross(Vector3.UP) * _strafe_direction
	match personality_id:
		0:
			_impulse_velocity += forward * 4.2
			if _personality_actions % 3 == 1:
				combat_event.emit("%s PRESIONA SIN RETROCEDER" % display_name, team_color)
		1:
			_impulse_velocity += side * 3.6 - forward * 1.25
			_strafe_direction *= -1.0
			if _personality_actions % 3 == 1:
				combat_event.emit("%s CAMBIA EL ÁNGULO" % display_name, team_color)
		2:
			_brace_time = 0.85
			_impulse_velocity *= 0.35
			_impulse_velocity += forward * 1.7
			if _personality_actions % 3 == 1:
				combat_event.emit("%s SE AFIRMA EN EL RING" % display_name, team_color)
		3:
			_impulse_velocity += side * 5.2 + forward * 1.1
			_strafe_direction *= -1.0
			if _personality_actions % 3 == 1:
				combat_event.emit("%s ENTRA CON UNA FINTA" % display_name, team_color)

func _perform_attack(distance: float) -> void:
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		return
	attack_count += 1
	var use_left := _choose_arm_side(attack_count % 2 == 0)
	var has_arm := _arm_available(use_left)
	var has_weapon := _side_available(use_left)
	var special_every := maxi(3, 7 - int(float(stats.energy) / 55.0))
	var special := attack_count % special_every == 0
	var damage_variation := 0.96 + float((attack_count * 13 + fighter_id * 5) % 9) * 0.01
	var damage := float(stats.power) * damage_variation
	if not has_weapon:
		damage *= 0.72 if has_arm else 0.42
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
		attack_cooldown = maxf(0.42, 1.46 / float(stats.attack_speed))
		return
	var attack_affinity := Catalog.weapon_affinity(build, use_left) if has_weapon else Catalog.dominant_affinity(build)
	var defend_affinity := Catalog.dominant_affinity(opponent.build)
	var affinity_bonus := Catalog.affinity_multiplier(attack_affinity, defend_affinity)
	damage *= affinity_bonus
	if affinity_bonus > 1.2:
		combat_event.emit("¡VENTAJA %s!" % Catalog.AFFINITY_NAMES[attack_affinity], Catalog.AFFINITY_COLORS[attack_affinity])
	elif affinity_bonus < 0.8:
		combat_event.emit("ATAQUE POCO EFECTIVO", Color("b9c5d7"))
	if has_arm:
		model.play_attack(use_left, special)
	else:
		model.play_hit()
	var is_ranged := has_weapon and float(stats.range) >= 4.35 and distance > 2.3
	if is_ranged:
		sfx_requested.emit("shot", 0.90 + _rng.randf_range(-0.06, 0.10))
		_launch_energy_orb(opponent, damage, special)
	else:
		sfx_requested.emit("swing", 0.86 if special else 1.0 + _rng.randf_range(-0.08, 0.10))
		var rush := opponent.global_position - global_position
		rush.y = 0.0
		if rush.length() > 0.05:
			_impulse_velocity += rush.normalized() * (7.2 if special else 5.1)
		var contact_delay := 0.38 if special else 0.25
		var combo_ready := attack_count % 5 == 0 and not special and has_arm
		get_tree().create_timer(contact_delay).timeout.connect(_resolve_melee_hit.bind(opponent, damage, special, use_left, combo_ready))
	attack_cooldown = maxf(0.42, 1.46 / float(stats.attack_speed))
	if special:
		attack_cooldown += 0.28

func _perform_manual_heavy() -> void:
	if not is_instance_valid(opponent) or opponent.hp <= 0.0:
		_manual_heavy_requested = false
		return
	_manual_heavy_requested = false
	attack_count += 1
	var use_left := _manual_use_left
	if not _side_available(use_left):
		combat_event.emit("EL ARMA DE %s YA NO ESTÁ DISPONIBLE" % display_name, Color("c4cfdd"))
		return
	var attack_affinity := Catalog.weapon_affinity(build, use_left)
	var defend_affinity := Catalog.dominant_affinity(opponent.build)
	var damage := float(stats.power) * 1.82 * Catalog.affinity_multiplier(attack_affinity, defend_affinity)
	var weapon_slot := "left_weapon" if use_left else "right_weapon"
	var weapon_index := int(build.get(weapon_slot, 0))
	model.play_attack(use_left, true)
	sfx_requested.emit("heavy", 0.82)
	var rush := opponent.global_position - global_position
	rush.y = 0.0
	if rush.length() > 0.05:
		_impulse_velocity += rush.normalized() * 10.5
	combat_event.emit("¡%s USA SU HERRAMIENTA!" % display_name, team_color)
	get_tree().create_timer(0.42).timeout.connect(_resolve_tool_hit.bind(opponent, damage, weapon_index, use_left))
	attack_cooldown = 1.05

func _resolve_melee_hit(victim: ArenaFighter, damage: float, special: bool, use_left: bool, combo_ready: bool) -> void:
	if not active or not is_instance_valid(victim) or victim.hp <= 0.0:
		return
	var distance := global_position.distance_to(victim.global_position)
	if distance > _melee_contact_range() + 0.70:
		combat_event.emit("%s ESQUIVA POR POCO" % victim.display_name, victim.team_color)
		return
	var impact_position := victim.model.get_part_world_position("torso")
	impact_position += Vector3((-0.32 if use_left else 0.32), 0.10, 0.36)
	victim.take_damage(damage, global_position, special, impact_position)
	var recoil := global_position - victim.global_position
	recoil.y = 0.0
	if recoil.length() > 0.05:
		_impulse_velocity += recoil.normalized() * 1.8
	if combo_ready and victim.hp > 0.0:
		get_tree().create_timer(0.24).timeout.connect(_combo_strike.bind(victim, damage * 0.28, global_position))

func _resolve_tool_hit(victim: ArenaFighter, damage: float, weapon_index: int, use_left: bool) -> void:
	if not active or not is_instance_valid(victim) or victim.hp <= 0.0:
		return
	if global_position.distance_to(victim.global_position) > _melee_contact_range() + 0.85:
		combat_event.emit("LA HERRAMIENTA DE %s NO ALCANZA" % display_name, Color("c4cfdd"))
		return
	victim.take_tool_hit(damage, global_position, weapon_index, use_left)

func _combo_strike(victim: ArenaFighter, damage: float, source_position: Vector3) -> void:
	if not active or not is_instance_valid(victim) or victim.hp <= 0.0:
		return
	sfx_requested.emit("swing", 1.18)
	var use_left := _choose_arm_side(attack_count % 2 != 0)
	model.play_attack(use_left, false)
	var rush := victim.global_position - global_position
	rush.y = 0.0
	if rush.length() > 0.05:
		_impulse_velocity += rush.normalized() * 4.2
	get_tree().create_timer(0.23).timeout.connect(_resolve_combo_hit.bind(victim, damage, source_position, use_left))

func _resolve_combo_hit(victim: ArenaFighter, damage: float, source_position: Vector3, use_left: bool) -> void:
	if not active or not is_instance_valid(victim) or victim.hp <= 0.0:
		return
	if global_position.distance_to(victim.global_position) > _melee_contact_range() + 0.55:
		return
	var impact_position := victim.model.get_part_world_position("torso") + Vector3(0.26 if use_left else -0.26, -0.18, 0.30)
	victim.take_damage(damage, source_position, false, impact_position)

func take_tool_hit(raw_damage: float, source_position: Vector3, weapon_index: int, attacker_used_left: bool) -> void:
	if not active or hp <= 0.0:
		return
	var target_slot := _choose_joint_target(weapon_index, attacker_used_left)
	var impact_position := model.get_part_world_position(target_slot) if not target_slot.is_empty() else model.get_part_world_position("torso")
	take_damage(raw_damage, source_position, true, impact_position)
	if hp <= 0.0 or target_slot.is_empty():
		return
	var tool_factor := 1.42 if weapon_index in CUTTING_WEAPONS else (1.16 if weapon_index in FORCE_WEAPONS else 1.04)
	var armor_factor := 100.0 / (100.0 + float(stats.armor) * 0.62 + float(stats.stability) * 0.22)
	var joint_damage := maxf(22.0, raw_damage * tool_factor * armor_factor)
	joint_integrity[target_slot] = float(joint_integrity.get(target_slot, 1.0)) - joint_damage
	_spawn_joint_burst(impact_position, joint_damage >= float(joint_maximum.get(target_slot, 1.0)) * 0.70)
	if float(joint_integrity[target_slot]) <= 0.0:
		_detach_combat_part(target_slot, source_position, impact_position)
	else:
		var damage_ratio := 1.0 - float(joint_integrity[target_slot]) / float(joint_maximum.get(target_slot, 1.0))
		combat_event.emit("UNIÓN %s DAÑADA · %.0f%%" % [PART_LABELS[target_slot], damage_ratio * 100.0], Color("ffb45f"))
		sfx_requested.emit("joint", 1.04)

func _choose_joint_target(weapon_index: int, attacker_used_left: bool) -> String:
	var first_side := "right" if attacker_used_left else "left"
	var second_side := "left" if first_side == "right" else "right"
	var candidates: Array[String] = []
	if weapon_index in CUTTING_WEAPONS:
		candidates = [first_side + "_arm", second_side + "_arm", first_side + "_weapon", second_side + "_weapon", "head"]
	elif weapon_index in FORCE_WEAPONS:
		candidates = [first_side + "_weapon", second_side + "_weapon", first_side + "_arm", second_side + "_arm", "head"]
	else:
		candidates = [first_side + "_weapon", "head", second_side + "_weapon", first_side + "_arm", second_side + "_arm"]
	for candidate in candidates:
		if not bool(detached_parts.get(candidate, false)) and model.has_part(candidate):
			return candidate
	return ""

func _detach_combat_part(slot: String, source_position: Vector3, impact_position: Vector3) -> void:
	var away := global_position - source_position
	away.y = 0.35
	if away.length() < 0.05:
		away = Vector3(1.0, 0.35, 0.0)
	if not model.detach_part(slot, away):
		return
	detached_parts[slot] = true
	if slot.ends_with("_arm"):
		var side := "left" if slot.begins_with("left") else "right"
		detached_parts[side + "_weapon"] = true
	_apply_detach_penalty(slot)
	_spawn_joint_burst(impact_position, true)
	_spawn_joint_burst(impact_position + Vector3(0.0, 0.18, 0.0), true)
	sfx_requested.emit("detach", 0.88)
	impact.emit(0.46, impact_position)
	combat_event.emit("¡DESARME! %s PIERDE %s" % [display_name, PART_LABELS[slot]], Color("fff173"))

func _apply_detach_penalty(slot: String) -> void:
	match slot:
		"left_weapon", "right_weapon":
			stats.power = float(stats.power) * 0.86
			stats.range = maxf(1.55, float(stats.range) - 0.55)
		"left_arm", "right_arm":
			stats.power = float(stats.power) * 0.72
			stats.attack_speed = maxf(0.45, float(stats.attack_speed) * 0.84)
			stats.accuracy = maxf(20.0, float(stats.accuracy) * 0.90)
			stats.stability = maxf(10.0, float(stats.stability) * 0.92)
		"head":
			stats.accuracy = maxf(18.0, float(stats.accuracy) * 0.48)
			stats.attack_speed = maxf(0.42, float(stats.attack_speed) * 0.78)
			stats.speed = maxf(1.4, float(stats.speed) * 0.88)
			stats.energy = float(stats.energy) * 0.75

func take_damage(raw_damage: float, source_position: Vector3, heavy: bool, contact_position := Vector3.ZERO) -> void:
	if not active or hp <= 0.0:
		return
	_received_hits += 1
	var reduction := 100.0 / (100.0 + float(stats.armor) * 2.35)
	if _brace_time > 0.0:
		reduction *= 0.84
	var final_damage := maxf(2.0, raw_damage * reduction)
	hp = maxf(0.0, hp - final_damage)
	var strong_push := heavy or _received_hits % 4 == 0
	model.play_hit(strong_push)
	var damage_ratio := 1.0 - hp / max_hp
	model.set_damage_state(3 if damage_ratio >= 0.78 else (2 if damage_ratio >= 0.52 else (1 if damage_ratio >= 0.25 else 0)))
	sfx_requested.emit("heavy" if heavy else "hit", 0.92 + _rng.randf_range(-0.07, 0.08))
	var actual_contact: Vector3 = contact_position if contact_position != Vector3.ZERO else global_position + Vector3(0.0, 2.2, 0.0)
	impact.emit(0.42 if heavy else (0.30 if strong_push else 0.20), actual_contact)
	_spawn_impact_sparks(heavy, actual_contact)
	var away := global_position - source_position
	away.y = 0.0
	if away.length() > 0.05:
		var stability_factor := clampf(1.18 - float(stats.stability) / 105.0, 0.32, 1.0)
		var push_force := 11.0 if heavy else (7.4 if strong_push else 4.0)
		if _brace_time > 0.0:
			push_force *= 0.55
		_impulse_velocity += away.normalized() * push_force * stability_factor
	_stagger_time = 0.48 if heavy else (0.28 if strong_push else 0.10)
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
	model.set_damage_state(3)
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

func _spawn_impact_sparks(heavy: bool, contact_position: Vector3) -> void:
	var spark_count := 26 if heavy else 13
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
		spark.global_position = contact_position
		var angle := TAU * float(index) / float(spark_count) + _rng.randf_range(-0.28, 0.28)
		var destination := spark.global_position + Vector3(cos(angle), _rng.randf_range(-0.15, 0.85), sin(angle)) * (1.55 if heavy else 0.86)
		var spark_tween := spark.create_tween()
		spark_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spark_tween.tween_property(spark, "global_position", destination, 0.25)
		spark_tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.28)
		spark_tween.tween_callback(spark.queue_free)

func _spawn_joint_burst(world_position: Vector3, intense: bool) -> void:
	var spark_count := 28 if intense else 14
	for index in range(spark_count):
		var spark := MeshInstance3D.new()
		var streak := BoxMesh.new()
		streak.size = Vector3(0.035, 0.035, 0.42 if intense else 0.27)
		var material := StandardMaterial3D.new()
		var spark_color := Color("fff173") if index % 3 != 0 else Color("67dfff")
		material.albedo_color = spark_color
		material.emission_enabled = true
		material.emission = spark_color * 2.4
		material.emission_energy_multiplier = 2.2
		streak.material = material
		spark.mesh = streak
		get_parent().add_child(spark)
		spark.global_position = world_position
		var angle := TAU * float(index) / float(spark_count) + _rng.randf_range(-0.20, 0.20)
		var rise := _rng.randf_range(0.30, 1.45) if intense else _rng.randf_range(0.12, 0.82)
		var distance := _rng.randf_range(1.25, 2.65) if intense else _rng.randf_range(0.65, 1.35)
		var destination := world_position + Vector3(cos(angle) * distance, rise, sin(angle) * distance)
		spark.look_at(destination, Vector3.UP)
		var tween := spark.create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "global_position", destination, 0.32 if intense else 0.22)
		tween.parallel().tween_property(spark, "scale", Vector3.ZERO, 0.38 if intense else 0.27)
		tween.tween_callback(spark.queue_free)

func _keep_inside_ring() -> void:
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() <= arena_radius:
		return
	flat = flat.normalized() * arena_radius
	global_position.x = flat.x
	global_position.z = flat.y
	velocity *= 0.35
