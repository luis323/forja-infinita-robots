extends Node

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AudioScript = preload("res://scripts/robot_audio.gd")

enum GameState { MENU, TIME_SELECT, BUILD, BATTLE, RESULT, HELP }

const BLUE := Color("43d8ff")
const RED := Color("ff537f")
const GOLD := Color("ffe36e")
const INK := Color("e9f5ff")
const PANEL := Color("d90a1230")
const PANEL_LIGHT := Color("e5172750")

var state := GameState.MENU
var game_mode := "cpu"
var build_duration := 120.0
var build_time_left := 120.0
var current_builder := 1
var selected_slot := "head"
var current_build := {}
var player_builds: Array[Dictionary] = []
var cpu_level := 1
var best_level := 1
var total_wins := 0
var battle_time_left := 75.0
var battle_started := false
var battle_finished := false
var last_winner := -1
var battle_speed := 1.0
var preview_time := 0.0
var battle_camera_time := 0.0
var camera_shake := 0.0

var camera: Camera3D
var audio: RobotAudio
var workshop_root: Node3D
var ring_root: Node3D
var preview_robot: RobotModel
var fighter_a: ArenaFighter
var fighter_b: ArenaFighter
var ui_layer: CanvasLayer
var ui_root: Control
var timer_label: Label
var stats_label: Label
var synergy_label: Label
var option_detail_label: Label
var options_grid: GridContainer
var slot_buttons := {}
var hp_bar_a: ProgressBar
var hp_bar_b: ProgressBar
var hp_text_a: Label
var hp_text_b: Label
var battle_clock: Label
var battle_message: Label
var message_tween: Tween

func _ready() -> void:
	Engine.time_scale = 1.0
	_load_progress()
	Catalog.validate_catalog()
	audio = AudioScript.new()
	add_child(audio)
	_setup_world()
	_setup_ui_layer()
	var args := OS.get_cmdline_user_args()
	if "--smoke-test" in args:
		call_deferred("_run_smoke_test")
		return
	_show_main_menu()

func _process(delta: float) -> void:
	if is_instance_valid(preview_robot) and state in [GameState.MENU, GameState.TIME_SELECT, GameState.BUILD, GameState.HELP]:
		preview_time += delta
		if state == GameState.BUILD:
			preview_robot.rotation.y = lerpf(preview_robot.rotation.y, sin(preview_time * 0.72) * 0.18, minf(1.0, delta * 4.0))
		else:
			preview_robot.rotation.y += delta * 0.48
	if state == GameState.BATTLE and is_instance_valid(fighter_a) and is_instance_valid(fighter_b):
		_update_battle_camera(delta)
	if state == GameState.BUILD and build_duration > 0.0:
		build_time_left = maxf(0.0, build_time_left - delta)
		_update_timer_label()
		if build_time_left <= 0.0:
			_finish_robot()
	elif state == GameState.BATTLE and battle_started and not battle_finished:
		battle_time_left = maxf(0.0, battle_time_left - delta)
		if battle_clock:
			battle_clock.text = "%02d" % int(ceil(battle_time_left))
		if battle_time_left <= 0.0:
			_finish_by_time()

func _update_battle_camera(delta: float) -> void:
	battle_camera_time += delta
	var midpoint := (fighter_a.global_position + fighter_b.global_position) * 0.5
	midpoint.y = 2.15
	var separation := fighter_a.global_position.distance_to(fighter_b.global_position)
	var orbit := sin(battle_camera_time * 0.28) * 0.34
	var distance := clampf(12.8 + separation * 0.20, 13.4, 16.0)
	var desired := midpoint + Vector3(sin(orbit) * distance, 7.2 + sin(battle_camera_time * 0.55) * 0.35, cos(orbit) * distance)
	if camera_shake > 0.01:
		var shake_offset := Vector3(sin(battle_camera_time * 71.0), cos(battle_camera_time * 83.0), sin(battle_camera_time * 97.0)) * camera_shake
		desired += shake_offset
		camera_shake = maxf(0.0, camera_shake - delta * 2.8)
	camera.position = camera.position.lerp(desired, minf(1.0, delta * 2.7))
	camera.look_at(midpoint, Vector3.UP)

func _setup_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050918")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("769bce")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("d8eeff")
	key_light.light_energy = 1.25
	key_light.shadow_enabled = true
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-4.0, 6.0, 5.0)
	fill_light.light_color = BLUE
	fill_light.light_energy = 7.0
	fill_light.omni_range = 15.0
	add_child(fill_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(5.0, 5.0, -3.0)
	rim_light.light_color = RED
	rim_light.light_energy = 6.0
	rim_light.omni_range = 14.0
	add_child(rim_light)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 5.4, 13.4)
	camera.fov = 54.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.45, 0.0), Vector3.UP)

	workshop_root = Node3D.new()
	workshop_root.name = "Workshop"
	add_child(workshop_root)
	_build_workshop()
	ring_root = Node3D.new()
	ring_root.name = "BattleRing"
	add_child(ring_root)
	_build_ring()
	ring_root.visible = false

func _setup_ui_layer() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

func _show_main_menu() -> void:
	_reset_runtime()
	state = GameState.MENU
	_clear_ui()
	_show_workshop_preview(Catalog.random_build(19), Vector3(2.85, 0.0, 0.0), BLUE)
	camera.position = Vector3(0.0, 5.4, 13.4)
	camera.look_at(Vector3(0.8, 2.45, 0.0), Vector3.UP)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.045
	panel.anchor_right = 0.48
	panel.anchor_bottom = 0.955
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 24))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
	panel.add_child(box)
	box.add_child(_title_label("FORJA INFINITA", 44, GOLD))
	box.add_child(_title_label("ROBOTS", 64, BLUE))
	var subtitle := _label("Construye la combinación más loca.\nDespués mira cómo tu robot pelea solo.", 20, INK)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(_separator())
	box.add_child(_make_button("🤖  CONTRA CPU · ARENA INFINITA", _choose_mode.bind("cpu"), BLUE, Vector2(500, 66)))
	box.add_child(_make_button("⚔  2 JUGADORES · MISMO DISPOSITIVO", _choose_mode.bind("local"), RED, Vector2(500, 66)))
	box.add_child(_make_button("?  CÓMO SE JUEGA", _show_help, Color("9d88ff"), Vector2(500, 54)))
	var record := _label("RÉCORD CPU: NIVEL %d   ·   VICTORIAS: %d" % [best_level, total_wins], 18, GOLD)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)
	var tiny := _label("8 espacios · 20 opciones en cada uno · 25.600.000.000 combinaciones", 14, Color("a8bad7"))
	tiny.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tiny)

func _choose_mode(mode: String) -> void:
	game_mode = mode
	state = GameState.TIME_SELECT
	_clear_ui()
	var panel := _center_panel(Vector2(560.0, 590.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_title_label("TIEMPO DE CONSTRUCCIÓN", 34, GOLD))
	var info := _label("El reloj solo corre mientras eliges piezas.\nSi llega a cero, el robot se termina automáticamente.", 19, INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	box.add_child(_separator())
	box.add_child(_make_button("⚡  30 SEGUNDOS", _select_time.bind(30.0), RED, Vector2(500, 60)))
	box.add_child(_make_button("⏱  1 MINUTO", _select_time.bind(60.0), Color("ffad5a"), Vector2(500, 60)))
	box.add_child(_make_button("🔧  2 MINUTOS", _select_time.bind(120.0), BLUE, Vector2(500, 60)))
	box.add_child(_make_button("∞  SIN LÍMITE", _select_time.bind(-1.0), Color("9d88ff"), Vector2(500, 60)))
	box.add_child(_make_button("←  VOLVER", _show_main_menu, Color("60759a"), Vector2(500, 48)))

func _select_time(seconds: float) -> void:
	build_duration = seconds
	current_builder = 1
	player_builds.clear()
	current_build = _load_last_build() if game_mode == "cpu" else Catalog.empty_build()
	_start_builder()

func _start_builder() -> void:
	state = GameState.BUILD
	battle_finished = false
	build_time_left = build_duration
	selected_slot = "head"
	_clear_ui()
	var tint := BLUE if current_builder == 1 else RED
	_show_workshop_preview(current_build, Vector3(-3.35, 0.0, 0.0), tint)
	camera.position = Vector3(0.0, 5.15, 13.8)
	camera.look_at(Vector3(-1.25, 2.4, 0.0), Vector3.UP)
	_build_builder_ui()
	_refresh_options()
	_update_build_info()

func _build_builder_ui() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18.0
	top.offset_top = 12.0
	top.offset_right = -18.0
	top.offset_bottom = 92.0
	top.add_theme_stylebox_override("panel", _panel_style(PANEL_LIGHT, 18))
	ui_root.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top.add_child(top_row)
	var player_text := "JUGADOR %d" % current_builder
	if game_mode == "cpu":
		player_text = "TU ROBOT · RIVAL NIVEL %d" % cpu_level
	var player_label := _label(player_text, 25, BLUE if current_builder == 1 else RED)
	player_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(player_label)
	timer_label = _label("", 30, GOLD)
	timer_label.custom_minimum_size = Vector2(200, 0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(timer_label)
	top_row.add_child(_make_button("ALEATORIO", _randomize_build, Color("9d88ff"), Vector2(170, 52)))
	top_row.add_child(_make_button("SALIR", _show_main_menu, Color("60759a"), Vector2(110, 52)))

	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 0.555
	right_panel.anchor_top = 0.145
	right_panel.anchor_right = 0.99
	right_panel.anchor_bottom = 0.985
	right_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 20))
	ui_root.add_child(right_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 9)
	right_panel.add_child(outer)
	var section_title := _label("ELIGE UNA PARTE", 25, GOLD)
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(section_title)
	var slots := GridContainer.new()
	slots.columns = 4
	slots.add_theme_constant_override("h_separation", 5)
	slots.add_theme_constant_override("v_separation", 5)
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(slots)
	slot_buttons.clear()
	for slot in Catalog.SLOTS:
		var button := _make_button(Catalog.LABELS[slot], _select_slot.bind(slot), Color("4b638d"), Vector2(112, 40))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		slots.add_child(button)
		slot_buttons[slot] = button
	options_grid = GridContainer.new()
	options_grid.columns = 4
	options_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_grid.add_theme_constant_override("h_separation", 5)
	options_grid.add_theme_constant_override("v_separation", 5)
	outer.add_child(options_grid)
	option_detail_label = _label("", 15, Color("c5d6ee"))
	option_detail_label.custom_minimum_size.y = 56
	option_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(option_detail_label)
	outer.add_child(_make_button("✓  TERMINAR Y ACTIVAR ROBOT", _finish_robot, GOLD, Vector2(0, 58)))

	var stats_panel := PanelContainer.new()
	stats_panel.anchor_left = 0.012
	stats_panel.anchor_top = 0.17
	stats_panel.anchor_right = 0.245
	stats_panel.anchor_bottom = 0.69
	stats_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 18))
	ui_root.add_child(stats_panel)
	var stat_box := VBoxContainer.new()
	stats_panel.add_child(stat_box)
	stats_label = _label("", 16, INK)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_box.add_child(stats_label)
	synergy_label = _label("", 14, GOLD)
	synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_box.add_child(synergy_label)

func _select_slot(slot: String) -> void:
	selected_slot = slot
	_refresh_options()

func _select_option(index: int) -> void:
	current_build[selected_slot] = index
	if audio:
		audio.play_sfx("join", 0.92 + float(index % 6) * 0.025)
	var tint := BLUE if current_builder == 1 else RED
	preview_robot.build_robot(current_build, tint, selected_slot)
	preview_robot.remember_floor_height()
	_refresh_options()
	_update_build_info()

func _refresh_options() -> void:
	if not options_grid:
		return
	for child in options_grid.get_children():
		options_grid.remove_child(child)
		child.queue_free()
	var chosen := int(current_build.get(selected_slot, 0))
	var names := Catalog.names_for(selected_slot)
	for index in range(20):
		var prefix := "✓ " if index == chosen else "%02d " % (index + 1)
		var button := _make_button(prefix + str(names[index]), _select_option.bind(index), GOLD if index == chosen else Color("52688f"), Vector2(108, 52))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.clip_text = true
		button.tooltip_text = str(names[index])
		options_grid.add_child(button)
	for slot in slot_buttons:
		var slot_button: Button = slot_buttons[slot]
		slot_button.modulate = Color.WHITE if slot == selected_slot else Color("b7c4dd")
	option_detail_label.text = Catalog.describe_option(selected_slot, chosen)

func _update_build_info() -> void:
	if not stats_label:
		return
	var stats := Catalog.build_stats(current_build)
	stats_label.text = "VIDA  %.0f\nPOTENCIA  %.0f\nBLINDAJE  %.0f\nVELOCIDAD  %.1f\nALCANCE  %.1f\nENERGÍA  %.0f" % [
		stats.health, stats.power, stats.armor, stats.speed, stats.range, stats.energy
	]
	var synergy := Catalog.get_synergy(current_build)
	synergy_label.text = "%s\n%s" % [synergy.title, synergy.description]
	_update_timer_label()

func _update_timer_label() -> void:
	if not timer_label:
		return
	if build_duration < 0.0:
		timer_label.text = "TIEMPO  ∞"
	else:
		var seconds := maxi(0, int(ceil(build_time_left)))
		timer_label.text = "TIEMPO  %02d:%02d" % [floori(float(seconds) / 60.0), seconds % 60]
		timer_label.modulate = RED if seconds <= 10 else Color.WHITE

func _randomize_build() -> void:
	current_build = Catalog.random_build(19)
	if audio:
		audio.play_sfx("join", 0.82)
	var tint := BLUE if current_builder == 1 else RED
	preview_robot.build_robot(current_build, tint, selected_slot)
	preview_robot.remember_floor_height()
	_refresh_options()
	_update_build_info()

func _finish_robot() -> void:
	if state != GameState.BUILD:
		return
	player_builds.append(current_build.duplicate(true))
	if game_mode == "local" and current_builder == 1:
		current_builder = 2
		current_build = Catalog.empty_build()
		_start_builder()
		return
	if game_mode == "cpu":
		_save_last_build(player_builds[0])
	_start_battle()

func _start_battle() -> void:
	state = GameState.BATTLE
	Engine.time_scale = 1.0
	battle_speed = 1.0
	battle_camera_time = 0.0
	camera_shake = 0.0
	battle_started = false
	battle_finished = false
	battle_time_left = 75.0
	last_winner = -1
	_clear_ui()
	_clear_preview()
	workshop_root.visible = false
	ring_root.visible = true
	_clear_fighters()
	camera.position = Vector3(0.0, 8.9, 14.2)
	camera.look_at(Vector3(0.0, 1.8, 0.0), Vector3.UP)

	var build_a: Dictionary = player_builds[0]
	var build_b: Dictionary
	var multiplier_b := 1.0
	var name_b := "ROBOT J2"
	if game_mode == "cpu":
		var max_cpu_part := clampi(3 + floori(float(cpu_level) / 2.0), 3, 19)
		build_b = Catalog.random_build(max_cpu_part)
		multiplier_b = 0.62 + log(float(cpu_level) + 1.0) * 0.16 + float(cpu_level) * 0.007
		name_b = "CPU-%04d" % cpu_level
	else:
		build_b = player_builds[1]
	fighter_a = FighterScript.new()
	fighter_b = FighterScript.new()
	ring_root.add_child(fighter_a)
	ring_root.add_child(fighter_b)
	fighter_a.position = Vector3(-4.2, 0.18, 0.0)
	fighter_b.position = Vector3(4.2, 0.18, 0.0)
	fighter_a.setup_robot(build_a, BLUE, 1.0, 0, "ROBOT J1")
	fighter_b.setup_robot(build_b, RED, multiplier_b, 1, name_b)
	fighter_a.set_opponent(fighter_b)
	fighter_b.set_opponent(fighter_a)
	fighter_a.health_changed.connect(_on_health_changed)
	fighter_b.health_changed.connect(_on_health_changed)
	fighter_a.defeated.connect(_on_fighter_defeated)
	fighter_b.defeated.connect(_on_fighter_defeated)
	fighter_a.combat_event.connect(_show_battle_message)
	fighter_b.combat_event.connect(_show_battle_message)
	fighter_a.sfx_requested.connect(_on_fighter_sfx)
	fighter_b.sfx_requested.connect(_on_fighter_sfx)
	fighter_a.impact.connect(_on_fighter_impact)
	fighter_b.impact.connect(_on_fighter_impact)
	_build_battle_ui(name_b)
	_on_health_changed(0, 1.0, fighter_a.hp, fighter_a.max_hp)
	_on_health_changed(1, 1.0, fighter_b.hp, fighter_b.max_hp)
	if audio:
		audio.start_battle_music()
	await _countdown()
	if state != GameState.BATTLE:
		return
	battle_started = true
	fighter_a.begin_fight()
	fighter_b.begin_fight()
	_show_battle_message("¡COMBATE!", GOLD)

func _build_battle_ui(name_b: String) -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16.0
	top.offset_top = 14.0
	top.offset_right = -16.0
	top.offset_bottom = 120.0
	top.add_theme_stylebox_override("panel", _panel_style(PANEL, 20))
	ui_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_box)
	var left_title := _label("ROBOT J1", 22, BLUE)
	left_box.add_child(left_title)
	hp_bar_a = _health_bar(BLUE)
	left_box.add_child(hp_bar_a)
	hp_text_a = _label("", 15, INK)
	left_box.add_child(hp_text_a)
	battle_clock = _title_label("75", 42, GOLD)
	battle_clock.custom_minimum_size = Vector2(110, 0)
	row.add_child(battle_clock)
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_box)
	var right_title := _label(name_b, 22, RED)
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_box.add_child(right_title)
	hp_bar_b = _health_bar(RED)
	right_box.add_child(hp_bar_b)
	hp_text_b = _label("", 15, INK)
	hp_text_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_box.add_child(hp_text_b)

	battle_message = _title_label("PREPARADOS", 34, GOLD)
	battle_message.anchor_left = 0.25
	battle_message.anchor_top = 0.18
	battle_message.anchor_right = 0.75
	battle_message.anchor_bottom = 0.28
	ui_root.add_child(battle_message)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.735
	controls.anchor_top = 0.89
	controls.anchor_right = 0.985
	controls.anchor_bottom = 0.98
	controls.add_theme_constant_override("separation", 8)
	ui_root.add_child(controls)
	controls.add_child(_make_button("x1 / x2", _toggle_battle_speed, Color("9d88ff"), Vector2(130, 48)))
	controls.add_child(_make_button("SALIR", _show_main_menu, Color("60759a"), Vector2(130, 48)))

func _countdown() -> void:
	var pitch := 0.82
	for word in ["3", "2", "1"]:
		if battle_message:
			battle_message.text = word
			battle_message.modulate = Color.WHITE
		if audio:
			audio.play_sfx("countdown", pitch)
		pitch += 0.12
		await get_tree().create_timer(0.62).timeout

func _on_fighter_sfx(kind: String, pitch: float) -> void:
	if audio:
		audio.play_sfx(kind, pitch)

func _on_fighter_impact(strength: float, _impact_position: Vector3) -> void:
	camera_shake = maxf(camera_shake, clampf(strength, 0.08, 0.46))

func _on_health_changed(id: int, ratio: float, current: float, maximum: float) -> void:
	if id == 0 and hp_bar_a:
		hp_bar_a.value = ratio * 100.0
		hp_text_a.text = "%.0f / %.0f" % [current, maximum]
	elif id == 1 and hp_bar_b:
		hp_bar_b.value = ratio * 100.0
		hp_text_b.text = "%.0f / %.0f" % [current, maximum]

func _on_fighter_defeated(loser_id: int) -> void:
	if battle_finished:
		return
	last_winner = 1 - loser_id
	_complete_battle()

func _finish_by_time() -> void:
	if battle_finished or not is_instance_valid(fighter_a) or not is_instance_valid(fighter_b):
		return
	var ratio_a: float = fighter_a.hp / fighter_a.max_hp
	var ratio_b: float = fighter_b.hp / fighter_b.max_hp
	last_winner = 0 if ratio_a >= ratio_b else 1
	if last_winner == 0:
		fighter_b.force_defeat()
	else:
		fighter_a.force_defeat()
	_complete_battle()

func _complete_battle() -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_started = false
	if audio:
		audio.stop_music()
		audio.play_sfx("victory" if last_winner == 0 else "defeat")
	if is_instance_valid(fighter_a):
		fighter_a.stop_fight()
	if is_instance_valid(fighter_b):
		fighter_b.stop_fight()
	var winner := fighter_a if last_winner == 0 else fighter_b
	if is_instance_valid(winner):
		winner.model.play_victory()
	if game_mode == "cpu" and last_winner == 0:
		total_wins += 1
		cpu_level += 1
		best_level = maxi(best_level, cpu_level)
		_save_progress()
	await get_tree().create_timer(1.15).timeout
	if state == GameState.BATTLE:
		_show_results()

func _show_results() -> void:
	state = GameState.RESULT
	Engine.time_scale = 1.0
	_clear_ui()
	var panel := _center_panel(Vector2(600.0, 560.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var victory := last_winner == 0
	var title := "¡VICTORIA!" if victory else ("GANA JUGADOR 2" if game_mode == "local" else "DERROTA")
	box.add_child(_title_label(title, 52, GOLD if victory else RED))
	if game_mode == "cpu":
		var message := "SUPERASTE EL NIVEL %d" % (cpu_level - 1) if victory else "EL RIVAL NIVEL %d FUE MÁS FUERTE" % cpu_level
		var info := _label(message, 22, INK)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(info)
		if victory:
			box.add_child(_make_button("▶  SIGUIENTE RIVAL · NIVEL %d" % cpu_level, _next_cpu_battle, BLUE, Vector2(540, 64)))
		else:
			box.add_child(_make_button("↻  REINTENTAR NIVEL %d" % cpu_level, _retry_cpu_battle, RED, Vector2(540, 64)))
		box.add_child(_make_button("🔧  VOLVER AL TALLER", _rebuild_from_result, Color("9d88ff"), Vector2(540, 58)))
	else:
		var local_info := _label("Los dos robots pelearon automáticamente.\nCambien las piezas y prueben otra locura.", 21, INK)
		local_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(local_info)
		box.add_child(_make_button("↻  REVANCHA CON LOS MISMOS ROBOTS", _local_rematch, BLUE, Vector2(540, 64)))
		box.add_child(_make_button("🔧  CONSTRUIR DOS ROBOTS NUEVOS", _restart_local_build, RED, Vector2(540, 58)))
	box.add_child(_make_button("⌂  MENÚ PRINCIPAL", _show_main_menu, Color("60759a"), Vector2(540, 52)))

func _next_cpu_battle() -> void:
	_start_battle()

func _retry_cpu_battle() -> void:
	_start_battle()

func _rebuild_from_result() -> void:
	current_builder = 1
	current_build = player_builds[0].duplicate(true)
	player_builds.clear()
	_start_builder()

func _local_rematch() -> void:
	_start_battle()

func _restart_local_build() -> void:
	current_builder = 1
	current_build = Catalog.empty_build()
	player_builds.clear()
	_start_builder()

func _toggle_battle_speed() -> void:
	battle_speed = 2.0 if battle_speed < 1.5 else 1.0
	Engine.time_scale = battle_speed
	_show_battle_message("VELOCIDAD x%d" % int(battle_speed), Color("9d88ff"))

func _show_battle_message(message: String, color: Color) -> void:
	if not battle_message:
		return
	if message_tween and message_tween.is_valid():
		message_tween.kill()
	battle_message.text = message
	battle_message.modulate = color
	battle_message.scale = Vector2(0.72, 0.72)
	battle_message.pivot_offset = battle_message.size * 0.5
	message_tween = create_tween()
	message_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	message_tween.tween_property(battle_message, "scale", Vector2.ONE, 0.22)
	message_tween.tween_interval(0.85)
	message_tween.tween_property(battle_message, "modulate:a", 0.0, 0.28)

func _show_help() -> void:
	state = GameState.HELP
	_clear_ui()
	var panel := _center_panel(Vector2(730.0, 650.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_title_label("CÓMO SE JUEGA", 40, GOLD))
	var help := _label(
		"1. ELIGE EL TIEMPO\n30 segundos, 1 minuto, 2 minutos o sin límite.\n\n" +
		"2. ARMA TU ROBOT EN EL PEDESTAL\nCabeza, torso, dos brazos, dos piernas y un arma por mano. Cada espacio tiene 20 opciones.\n\n" +
		"3. DESCUBRE SINERGIAS\nArmas gemelas y familias de piezas activan mejoras, pero cualquier mezcla funciona.\n\n" +
		"4. MIRA EL COMBATE\nLos robots caminan, apuntan, atacan y usan sobrecargas automáticamente. Tú eres el ingeniero.\n\n" +
		"ARENA INFINITA\nLa CPU comienza fácil, aprende nuevas piezas y se vuelve más potente sin límite.\n\n" +
		"2 JUGADORES\nCada persona construye por turnos en el mismo teléfono, tablet o PC.",
		19,
		INK
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(help)
	box.add_child(_make_button("←  ENTENDIDO", _show_main_menu, BLUE, Vector2(0, 56)))

func _show_workshop_preview(build: Dictionary, location: Vector3, tint: Color) -> void:
	workshop_root.visible = true
	ring_root.visible = false
	_clear_preview()
	preview_robot = RobotModelScript.new()
	workshop_root.add_child(preview_robot)
	preview_robot.position = location
	preview_robot.build_robot(build, tint)
	preview_robot.remember_floor_height()

func _clear_preview() -> void:
	if is_instance_valid(preview_robot):
		preview_robot.queue_free()
	preview_robot = null

func _clear_fighters() -> void:
	for fighter in [fighter_a, fighter_b]:
		if is_instance_valid(fighter):
			fighter.queue_free()
	fighter_a = null
	fighter_b = null

func _reset_runtime() -> void:
	Engine.time_scale = 1.0
	if audio:
		audio.stop_music()
	battle_started = false
	battle_finished = false
	_clear_fighters()
	workshop_root.visible = true
	ring_root.visible = false

func _clear_ui() -> void:
	for child in ui_root.get_children():
		ui_root.remove_child(child)
		child.queue_free()
	timer_label = null
	stats_label = null
	synergy_label = null
	option_detail_label = null
	options_grid = null
	hp_bar_a = null
	hp_bar_b = null
	hp_text_a = null
	hp_text_b = null
	battle_clock = null
	battle_message = null

func _build_workshop() -> void:
	_mesh_box(workshop_root, Vector3(22.0, 0.45, 16.0), Color("101a35"), Vector3(0.0, -0.32, 0.0), 0.45)
	_mesh_box(workshop_root, Vector3(22.0, 10.0, 0.45), Color("081027"), Vector3(0.0, 4.5, -5.0), 0.25)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		_mesh_box(workshop_root, Vector3(0.10, 8.0, 0.18), BLUE.darkened(0.25), Vector3(x, 4.2, -4.72), 0.1, true)
	for y in [1.0, 3.0, 5.0, 7.0]:
		_mesh_box(workshop_root, Vector3(19.0, 0.08, 0.15), Color("704dff"), Vector3(0.0, y, -4.70), 0.1, true)
	_mesh_cylinder(workshop_root, 2.75, 0.42, Color("283965"), Vector3(-3.35, -0.02, 0.0), false)
	_mesh_cylinder(workshop_root, 2.38, 0.55, BLUE.darkened(0.35), Vector3(-3.35, 0.18, 0.0), true)
	_mesh_cylinder(workshop_root, 2.50, 0.38, Color("283965"), Vector3(2.85, -0.02, 0.0), false)
	_mesh_cylinder(workshop_root, 2.14, 0.50, Color("5e4dff").darkened(0.30), Vector3(2.85, 0.16, 0.0), true)
	for x in [-7.0, 6.6]:
		_mesh_box(workshop_root, Vector3(2.6, 2.4, 0.36), Color("192a56"), Vector3(x, 3.9, -4.52), 0.3)
		_mesh_box(workshop_root, Vector3(2.25, 1.75, 0.18), RED if x > 0 else BLUE, Vector3(x, 3.9, -4.30), 0.12, true)

func _build_ring() -> void:
	_mesh_box(ring_root, Vector3(18.0, 0.80, 18.0), Color("151c38"), Vector3(0.0, -0.48, 0.0), 0.5)
	_mesh_box(ring_root, Vector3(13.3, 0.30, 13.3), Color("dbe8f2"), Vector3(0.0, 0.08, 0.0), 0.65)
	_mesh_box(ring_root, Vector3(1.0, 0.05, 12.0), Color("5bc9ff"), Vector3(0.0, 0.25, 0.0), 0.2)
	_mesh_box(ring_root, Vector3(12.0, 0.052, 1.0), Color("ff6b8f"), Vector3(0.0, 0.26, 0.0), 0.2)
	for x in [-6.7, 6.7]:
		for z in [-6.7, 6.7]:
			_mesh_cylinder(ring_root, 0.22, 4.2, RED if x > 0 else BLUE, Vector3(x, 2.0, z), true)
	for height in [1.25, 2.15, 3.05]:
		for z in [-6.55, 6.55]:
			_mesh_cylinder(ring_root, 0.055, 13.1, Color("f3f7ff"), Vector3(0.0, height, z), true, Vector3(0.0, 0.0, 90.0))
		for x in [-6.55, 6.55]:
			_mesh_cylinder(ring_root, 0.055, 13.1, Color("f3f7ff"), Vector3(x, height, 0.0), true, Vector3(90.0, 0.0, 0.0))
	for i in range(22):
		var angle := TAU * float(i) / 22.0
		var color := BLUE if i % 2 == 0 else RED
		_mesh_sphere(ring_root, 0.12, color, Vector3(cos(angle) * 9.5, 3.5 + float(i % 3) * 0.65, sin(angle) * 9.5), true)

func _mesh_box(parent: Node3D, size: Vector3, color: Color, position: Vector3, roughness: float, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, mesh, color, position, roughness, glow)

func _mesh_cylinder(parent: Node3D, radius: float, height: float, color: Color, position: Vector3, glow := false, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance := _mesh_instance(parent, mesh, color, position, 0.28, glow)
	instance.rotation_degrees = rotation
	return instance

func _mesh_sphere(parent: Node3D, radius: float, color: Color, position: Vector3, glow := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _mesh_instance(parent, mesh, color, position, 0.22, glow)

func _mesh_instance(parent: Node3D, mesh: PrimitiveMesh, color: Color, position: Vector3, roughness: float, glow: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.60
	material.roughness = roughness
	if glow:
		material.emission_enabled = true
		material.emission = color * 1.4
		material.emission_energy_multiplier = 1.25
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance

func _center_panel(minimum: Vector2) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 24))
	center.add_child(panel)
	return panel

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("6d8ac2")
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 17.0
	style.content_margin_bottom = 17.0
	return style

func _make_button(text: String, action: Callable, color: Color, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("f5fbff"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color.darkened(0.48), color.darkened(0.18), 2))
	button.add_theme_stylebox_override("hover", _button_style(color.darkened(0.24), color, 3))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.55), Color.WHITE, 3))
	button.add_theme_stylebox_override("focus", _button_style(color.darkened(0.38), GOLD, 3))
	button.pressed.connect(_play_ui_sound)
	button.pressed.connect(action)
	return button

func _play_ui_sound() -> void:
	if audio:
		audio.play_ui()

func _button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _title_label(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_shadow_color", Color("c0000000"))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.custom_minimum_size.y = 8.0
	return separator

func _health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 27.0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("58101a32")
	background.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_level", best_level)
	config.set_value("progress", "current_level", cpu_level)
	config.set_value("progress", "total_wins", total_wins)
	config.save("user://forja_infinita_save.cfg")

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load("user://forja_infinita_save.cfg") == OK:
		best_level = maxi(1, int(config.get_value("progress", "best_level", 1)))
		cpu_level = maxi(1, int(config.get_value("progress", "current_level", 1)))
		total_wins = maxi(0, int(config.get_value("progress", "total_wins", 0)))

func _save_last_build(build: Dictionary) -> void:
	var config := ConfigFile.new()
	for slot in Catalog.SLOTS:
		config.set_value("robot", slot, int(build.get(slot, 0)))
	config.save("user://forja_ultimo_robot.cfg")

func _load_last_build() -> Dictionary:
	var build := Catalog.empty_build()
	var config := ConfigFile.new()
	if config.load("user://forja_ultimo_robot.cfg") == OK:
		for slot in Catalog.SLOTS:
			build[slot] = clampi(int(config.get_value("robot", slot, 0)), 0, 19)
	return build

func _run_smoke_test() -> void:
	var passed := Catalog.validate_catalog()
	var maximum_build := {}
	for slot in Catalog.SLOTS:
		maximum_build[slot] = 19
	var stats := Catalog.build_stats(maximum_build)
	passed = passed and Catalog.SLOTS.size() == 8
	passed = passed and float(stats.health) > 0.0 and float(stats.power) > 0.0
	var model_test := RobotModelScript.new()
	add_child(model_test)
	model_test.build_robot(maximum_build, BLUE)
	passed = passed and model_test.part_roots.size() == 8
	passed = passed and audio.streams.has("battle_music") and audio.streams.size() >= 12
	var fighter_test_a := FighterScript.new()
	var fighter_test_b := FighterScript.new()
	add_child(fighter_test_a)
	add_child(fighter_test_b)
	fighter_test_a.setup_robot(maximum_build, BLUE, 1.0, 0, "PRUEBA A")
	fighter_test_b.setup_robot(Catalog.empty_build(), RED, 0.75, 1, "PRUEBA B")
	fighter_test_a.set_opponent(fighter_test_b)
	fighter_test_b.set_opponent(fighter_test_a)
	fighter_test_a.begin_fight()
	fighter_test_b.begin_fight()
	var hp_before: float = fighter_test_b.hp
	fighter_test_b.take_damage(50.0, fighter_test_a.global_position, false)
	passed = passed and fighter_test_b.hp < hp_before
	print("FORJA_SMOKE_TEST:", "PASS" if passed else "FAIL", " slots=", Catalog.SLOTS.size(), " options=160 combat=OK")
	get_tree().quit(0 if passed else 1)
