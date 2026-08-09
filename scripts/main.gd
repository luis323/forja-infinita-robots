extends Node

const Catalog = preload("res://scripts/robot_catalog.gd")
const RobotModelScript = preload("res://scripts/robot_model.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const AudioScript = preload("res://scripts/robot_audio.gd")
const ThumbnailScript = preload("res://scripts/part_thumbnail.gd")
const LanScript = preload("res://scripts/lan_manager.gd")

enum GameState { MENU, TIME_SELECT, BUILD, LAN_LOBBY, BATTLE, RESULT, HELP }

const BLUE := Color("43d8ff")
const RED := Color("ff537f")
const GOLD := Color("ffe36e")
const INK := Color("e9f5ff")
const PANEL := Color("d90a1230")
const PANEL_LIGHT := Color("e5172750")
const TEAM_COLORS := [Color("43d8ff"), Color("6f8cff"), Color("8edfa8"), Color("ff8b72")]

var state := GameState.MENU
var game_mode := "story"
var build_duration := 120.0
var build_time_left := 120.0
var current_builder := 1
var selected_slot := "head"
var current_build := {}
var player_builds: Array[Dictionary] = []
var cpu_level := 1
var best_level := 1
var total_wins := 0
var credits := 600
var unlocked_parts := {}
var last_reward := 0
var battle_time_left := 75.0
var battle_started := false
var battle_finished := false
var last_winner := -1
var battle_speed := 1.0
var preview_time := 0.0
var battle_camera_time := 0.0
var camera_shake := 0.0
var local_lan_index := 0

var camera: Camera3D
var audio: RobotAudio
var lan: RobotLanManager
var workshop_root: Node3D
var ring_root: Node3D
var preview_robot: RobotModel
var fighter_a: ArenaFighter
var fighter_b: ArenaFighter
var fighters: Array[ArenaFighter] = []
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
var stats_bars := {}
var stat_value_labels := {}
var fighter_hp_bars: Array[ProgressBar] = []
var fighter_hp_texts: Array[Label] = []
var heavy_buttons: Array[Button] = []
var lan_status_label: Label
var lan_start_button: Button

func _ready() -> void:
	Engine.time_scale = 1.0
	_load_progress()
	Catalog.validate_catalog()
	audio = AudioScript.new()
	add_child(audio)
	lan = LanScript.new()
	add_child(lan, true)
	lan.status_changed.connect(_on_lan_status_changed)
	lan.battle_ready.connect(_on_lan_battle_ready)
	lan.heavy_received.connect(_on_lan_heavy_received)
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
	if state == GameState.BATTLE and fighters.size() >= 2:
		_update_battle_camera(delta)
		_update_heavy_buttons()
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
	var midpoint := Vector3.ZERO
	var visible_count := 0
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.hp > 0.0:
			midpoint += fighter.global_position
			visible_count += 1
	if visible_count == 0:
		return
	midpoint /= float(visible_count)
	midpoint.y = 2.15
	var separation := 0.0
	for fighter in fighters:
		if is_instance_valid(fighter):
			separation = maxf(separation, fighter.global_position.distance_to(midpoint))
	separation *= 1.55
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
	box.add_child(_make_button("🏆  HISTORIA · GANA CRÉDITOS", _choose_mode.bind("story"), BLUE, Vector2(500, 60)))
	box.add_child(_make_button("⚔  VS HUMANO · TODO DESBLOQUEADO", _choose_mode.bind("local"), RED, Vector2(500, 60)))
	box.add_child(_make_button("📡  LAN · 2 A 4 ROBOTS", _choose_mode.bind("lan"), Color("8edfa8"), Vector2(500, 60)))
	box.add_child(_make_button("?  CÓMO SE JUEGA", _show_help, Color("9d88ff"), Vector2(500, 54)))
	var record := _label("CRÉDITOS: %d   ·   RÉCORD: NIVEL %d   ·   VICTORIAS: %d" % [credits, best_level, total_wins], 17, GOLD)
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)
	var tiny := _label("8 espacios · 20 opciones en cada uno · 25.600.000.000 combinaciones", 14, Color("a8bad7"))
	tiny.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tiny)

func _choose_mode(mode: String) -> void:
	game_mode = mode
	local_lan_index = 0
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
	current_build = _load_last_build() if game_mode == "story" else Catalog.empty_build()
	if game_mode == "story":
		for slot in Catalog.SLOTS:
			if not _is_part_unlocked(slot, int(current_build.get(slot, 0))):
				current_build[slot] = 0
	_start_builder()

func _start_builder() -> void:
	state = GameState.BUILD
	battle_finished = false
	build_time_left = build_duration
	selected_slot = "head"
	_clear_ui()
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
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
	if game_mode == "story":
		player_text = "TU ROBOT · RIVAL NIVEL %d" % cpu_level
	elif game_mode == "lan":
		player_text = "TU ROBOT LAN · TODO DESBLOQUEADO"
	var player_label := _label(player_text, 25, TEAM_COLORS[clampi(current_builder - 1, 0, 3)])
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
	options_grid.columns = 5
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
	stats_panel.anchor_right = 0.255
	stats_panel.anchor_bottom = 0.90
	stats_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 18))
	ui_root.add_child(stats_panel)
	var stat_box := VBoxContainer.new()
	stats_panel.add_child(stat_box)
	stats_label = _label("", 15, INK)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_box.add_child(stats_label)
	stats_bars.clear()
	stat_value_labels.clear()
	for key in Catalog.STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		stat_box.add_child(row)
		var name_label := _label(Catalog.STAT_LABELS[key], 11, Color("bcd0e8"))
		name_label.custom_minimum_size.x = 86.0
		row.add_child(name_label)
		var bar := _stat_bar(Catalog.AFFINITY_COLORS[Catalog.AFFINITIES[Catalog.STAT_KEYS.find(key) % 5]])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar)
		var value_label := _label("0", 11, INK)
		value_label.custom_minimum_size.x = 38.0
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		stats_bars[key] = bar
		stat_value_labels[key] = value_label
	synergy_label = _label("", 14, GOLD)
	synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	synergy_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_box.add_child(synergy_label)

func _select_slot(slot: String) -> void:
	selected_slot = slot
	_refresh_options()

func _select_option(index: int) -> void:
	if game_mode == "story" and not _is_part_unlocked(selected_slot, index):
		var price := Catalog.part_price(selected_slot, index)
		if credits < price:
			option_detail_label.text = "FALTAN %d CRÉDITOS PARA COMPRAR ESTA PIEZA" % (price - credits)
			if audio:
				audio.play_sfx("defeat", 1.25)
			return
		credits -= price
		_unlock_part(selected_slot, index)
		_save_progress()
	current_build[selected_slot] = index
	if audio:
		audio.play_sfx("join", 0.92 + float(index % 6) * 0.025)
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
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
		var locked := game_mode == "story" and not _is_part_unlocked(selected_slot, index)
		var prefix := "✓ " if index == chosen else ""
		var price_text := "\n🔒 %d C" % Catalog.part_price(selected_slot, index) if locked else ""
		var button := _make_button("\n\n" + prefix + str(names[index]) + price_text, _select_option.bind(index), GOLD if index == chosen else Color("52688f"), Vector2(92, 68))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 10)
		button.clip_text = true
		button.tooltip_text = str(names[index])
		var thumbnail := ThumbnailScript.new()
		button.add_child(thumbnail)
		thumbnail.anchor_left = 0.5
		thumbnail.anchor_right = 0.5
		thumbnail.offset_left = -27.0
		thumbnail.offset_right = 27.0
		thumbnail.offset_top = 1.0
		thumbnail.offset_bottom = 43.0
		thumbnail.setup(selected_slot, index, index == chosen, locked)
		options_grid.add_child(button)
	for slot in slot_buttons:
		var slot_button: Button = slot_buttons[slot]
		slot_button.modulate = Color.WHITE if slot == selected_slot else Color("b7c4dd")
	option_detail_label.text = Catalog.describe_option(selected_slot, chosen)

func _update_build_info() -> void:
	if not stats_label:
		return
	var stats := Catalog.build_stats(current_build)
	var normalized := Catalog.normalized_stats(current_build)
	var affinity := Catalog.dominant_affinity(current_build)
	stats_label.text = "%s  ·  PODER %.0f%s" % [Catalog.AFFINITY_NAMES[affinity], Catalog.combat_rating(current_build), "  ·  %d C" % credits if game_mode == "story" else ""]
	stats_label.add_theme_color_override("font_color", Catalog.AFFINITY_COLORS[affinity])
	for key in Catalog.STAT_KEYS:
		var bar: ProgressBar = stats_bars[key]
		bar.value = float(normalized[key])
		var value_label: Label = stat_value_labels[key]
		value_label.text = "%.0f" % float(stats[key])
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
	current_build = _random_owned_build() if game_mode == "story" else Catalog.random_build(19)
	if audio:
		audio.play_sfx("join", 0.82)
	var tint: Color = TEAM_COLORS[clampi(current_builder - 1, 0, 3)]
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
	if game_mode == "story":
		_save_last_build(player_builds[0])
	if game_mode == "lan":
		_show_lan_lobby()
		return
	_start_battle()

func _show_lan_lobby() -> void:
	state = GameState.LAN_LOBBY
	_clear_ui()
	_clear_fighters()
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	var own_build: Dictionary = player_builds[own_index]
	_show_workshop_preview(own_build, Vector3(2.85, 0.0, 0.0), TEAM_COLORS[own_index])
	var panel := PanelContainer.new()
	panel.anchor_left = 0.025
	panel.anchor_top = 0.06
	panel.anchor_right = 0.52
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, 22))
	ui_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_title_label("SALA LAN · 2 A 4", 34, Color("8edfa8")))
	var info := _label("Todos deben estar conectados al mismo Wi-Fi.\nEl anfitrión comparte su IP; los demás la escriben.", 17, INK)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var address := LineEdit.new()
	address.placeholder_text = "IP DEL ANFITRIÓN · ejemplo 192.168.1.20"
	address.text = lan.get_local_ip()
	address.custom_minimum_size = Vector2(0.0, 52.0)
	address.add_theme_font_size_override("font_size", 18)
	box.add_child(address)
	box.add_child(_make_button("ABRIR SALA COMO ANFITRIÓN", _host_lan_game, BLUE, Vector2(0, 58)))
	box.add_child(_make_button("UNIRME A ESA IP", _join_lan_game.bind(address), Color("8edfa8"), Vector2(0, 58)))
	lan_status_label = _label("ELIGE ANFITRIÓN O INVITADO", 18, GOLD)
	lan_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(lan_status_label)
	lan_start_button = _make_button("INICIAR PELEA LAN", lan.start_battle, GOLD, Vector2(0, 62))
	lan_start_button.disabled = true
	box.add_child(lan_start_button)
	if lan.hosting:
		_on_lan_status_changed("ROBOTS CONECTADOS: %d / 4" % lan.submitted_builds.size(), lan.submitted_builds.size(), lan.submitted_builds.size() >= 2)
	elif not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_on_lan_status_changed("CONECTADO · esperando al anfitrión", 1, false)
	box.add_child(_make_button("← VOLVER", _show_main_menu, Color("60759a"), Vector2(0, 48)))

func _host_lan_game() -> void:
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	lan.host_game(player_builds[own_index])

func _join_lan_game(address: LineEdit) -> void:
	var own_index := clampi(local_lan_index, 0, player_builds.size() - 1)
	lan.join_game(address.text, player_builds[own_index])

func _on_lan_status_changed(message: String, _player_count: int, can_start: bool) -> void:
	if lan_status_label:
		lan_status_label.text = message
	if lan_start_button:
		lan_start_button.disabled = not can_start

func _on_lan_battle_ready(builds: Array[Dictionary], local_index: int) -> void:
	player_builds = builds.duplicate(true)
	local_lan_index = local_index
	_start_battle()

func _on_lan_heavy_received(fighter_index: int) -> void:
	_trigger_heavy(fighter_index)

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

	var battle_builds: Array[Dictionary] = player_builds.duplicate(true)
	var multipliers: Array[float] = []
	var names: Array[String] = []
	for index in range(battle_builds.size()):
		multipliers.append(1.0)
		names.append("ROBOT J%d" % (index + 1))
	if game_mode == "story":
		var max_cpu_part := clampi(3 + floori(float(cpu_level) / 2.0), 3, 19)
		battle_builds.append(Catalog.random_build(max_cpu_part))
		multipliers.append(0.62 + log(float(cpu_level) + 1.0) * 0.16 + float(cpu_level) * 0.007)
		names.append("CPU-%04d" % cpu_level)
	if battle_builds.size() < 2:
		_show_main_menu()
		return
	var spawn_positions := [Vector3(-4.2, 0.18, -2.2), Vector3(4.2, 0.18, 2.2), Vector3(-2.2, 0.18, 4.2), Vector3(2.2, 0.18, -4.2)]
	for index in range(mini(4, battle_builds.size())):
		var fighter: ArenaFighter = FighterScript.new()
		ring_root.add_child(fighter)
		fighter.position = spawn_positions[index]
		fighter.setup_robot(battle_builds[index], TEAM_COLORS[index], multipliers[index], index, names[index])
		fighter.health_changed.connect(_on_health_changed)
		fighter.defeated.connect(_on_fighter_defeated)
		fighter.combat_event.connect(_show_battle_message)
		fighter.sfx_requested.connect(_on_fighter_sfx)
		fighter.impact.connect(_on_fighter_impact)
		fighters.append(fighter)
	for fighter in fighters:
		var possible_targets: Array[ArenaFighter] = []
		for candidate in fighters:
			if candidate != fighter:
				possible_targets.append(candidate)
		fighter.set_opponents(possible_targets)
	fighter_a = fighters[0]
	fighter_b = fighters[1]
	_build_battle_ui(names)
	for fighter in fighters:
		_on_health_changed(fighter.fighter_id, 1.0, fighter.hp, fighter.max_hp)
	if fighters.size() == 2:
		var prediction := Catalog.matchup_prediction(battle_builds[0], battle_builds[1])
		battle_message.text = "ANÁLISIS · J1 %.0f%%  /  J2 %.0f%%" % [float(prediction.a) * 100.0, float(prediction.b) * 100.0]
		battle_message.modulate = Color("c8d8ef")
		await get_tree().create_timer(0.85).timeout
		if state != GameState.BATTLE:
			return
	if audio:
		audio.start_battle_music()
	await _countdown()
	if state != GameState.BATTLE:
		return
	battle_started = true
	for fighter in fighters:
		fighter.begin_fight()
	_show_battle_message("¡COMBATE!", GOLD)

func _build_battle_ui(names: Array[String]) -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16.0
	top.offset_top = 14.0
	top.offset_right = -16.0
	top.offset_bottom = 146.0
	top.add_theme_stylebox_override("panel", _panel_style(PANEL, 20))
	ui_root.add_child(top)
	var outer := VBoxContainer.new()
	top.add_child(outer)
	battle_clock = _title_label("75", 29, GOLD)
	battle_clock.custom_minimum_size = Vector2(0, 32)
	outer.add_child(battle_clock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)
	fighter_hp_bars.clear()
	fighter_hp_texts.clear()
	for index in range(fighters.size()):
		var fighter_box := VBoxContainer.new()
		fighter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(fighter_box)
		var title := _label("%s · %s" % [names[index], Catalog.AFFINITY_NAMES[Catalog.dominant_affinity(fighters[index].build)]], 14, TEAM_COLORS[index])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fighter_box.add_child(title)
		var hp_bar := _health_bar(TEAM_COLORS[index])
		hp_bar.custom_minimum_size.y = 20.0
		fighter_box.add_child(hp_bar)
		var hp_text := _label("", 12, INK)
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fighter_box.add_child(hp_text)
		fighter_hp_bars.append(hp_bar)
		fighter_hp_texts.append(hp_text)
	hp_bar_a = fighter_hp_bars[0]
	hp_bar_b = fighter_hp_bars[1]
	hp_text_a = fighter_hp_texts[0]
	hp_text_b = fighter_hp_texts[1]

	battle_message = _title_label("PREPARADOS", 34, GOLD)
	battle_message.anchor_left = 0.25
	battle_message.anchor_top = 0.21
	battle_message.anchor_right = 0.75
	battle_message.anchor_bottom = 0.28
	ui_root.add_child(battle_message)
	var controls := HBoxContainer.new()
	controls.anchor_left = 0.64
	controls.anchor_top = 0.89
	controls.anchor_right = 0.985
	controls.anchor_bottom = 0.98
	controls.add_theme_constant_override("separation", 8)
	ui_root.add_child(controls)
	if game_mode != "lan":
		controls.add_child(_make_button("x1 / x2", _toggle_battle_speed, Color("9d88ff"), Vector2(115, 48)))
	controls.add_child(_make_button("SALIR", _show_main_menu, Color("60759a"), Vector2(130, 48)))
	var heavy_row := HBoxContainer.new()
	heavy_row.anchor_left = 0.015
	heavy_row.anchor_top = 0.87
	heavy_row.anchor_right = 0.62
	heavy_row.anchor_bottom = 0.98
	heavy_row.add_theme_constant_override("separation", 8)
	ui_root.add_child(heavy_row)
	heavy_buttons.clear()
	var controllable: Array[int] = []
	if game_mode == "lan":
		controllable.append(local_lan_index)
	elif game_mode == "local":
		for index in range(fighters.size()):
			controllable.append(index)
	else:
		controllable.append(0)
	for index in controllable:
		var button := _make_button("GOLPE FUERTE J%d" % (index + 1), _request_heavy.bind(index), TEAM_COLORS[index], Vector2(190, 56))
		button.set_meta("fighter_index", index)
		heavy_row.add_child(button)
		heavy_buttons.append(button)

func _request_heavy(fighter_index: int) -> void:
	if game_mode == "lan":
		lan.request_heavy(fighter_index)
	else:
		_trigger_heavy(fighter_index)

func _trigger_heavy(fighter_index: int) -> void:
	if fighter_index < 0 or fighter_index >= fighters.size():
		return
	var fighter := fighters[fighter_index]
	if is_instance_valid(fighter) and not fighter.request_heavy_attack():
		_show_battle_message("GOLPE FUERTE RECARGANDO", Color("c4cfdd"))

func _update_heavy_buttons() -> void:
	for button in heavy_buttons:
		var fighter_index := int(button.get_meta("fighter_index", -1))
		if fighter_index < 0 or fighter_index >= fighters.size():
			continue
		var fighter := fighters[fighter_index]
		if not is_instance_valid(fighter):
			button.disabled = true
			continue
		button.disabled = fighter.hp <= 0.0
		button.text = "GOLPE FUERTE J%d%s" % [fighter_index + 1, " · %.1fs" % fighter.heavy_cooldown if fighter.heavy_cooldown > 0.05 else " · ¡LISTO!"]

func _countdown() -> void:
	var pitch := 0.82
	for word in ["3", "2", "1"]:
		if state != GameState.BATTLE:
			return
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
	if id >= 0 and id < fighter_hp_bars.size():
		fighter_hp_bars[id].value = ratio * 100.0
		fighter_hp_texts[id].text = "%.0f / %.0f" % [current, maximum]

func _on_fighter_defeated(_loser_id: int) -> void:
	if battle_finished:
		return
	var alive: Array[ArenaFighter] = []
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.hp > 0.0:
			alive.append(fighter)
	if alive.size() <= 1:
		last_winner = alive[0].fighter_id if alive.size() == 1 else 0
		_complete_battle()

func _finish_by_time() -> void:
	if battle_finished or fighters.is_empty():
		return
	var best_ratio := -1.0
	for fighter in fighters:
		if not is_instance_valid(fighter):
			continue
		var ratio: float = fighter.hp / fighter.max_hp
		if ratio > best_ratio:
			best_ratio = ratio
			last_winner = fighter.fighter_id
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.fighter_id != last_winner:
			fighter.stop_fight()
			fighter.model.play_defeat()
	_complete_battle()

func _complete_battle() -> void:
	if battle_finished:
		return
	battle_finished = true
	battle_started = false
	var local_victory := last_winner == (local_lan_index if game_mode == "lan" else 0)
	if audio:
		audio.stop_music()
		audio.play_sfx("victory" if local_victory else "defeat")
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.stop_fight()
	var winner: ArenaFighter = fighters[last_winner] if last_winner >= 0 and last_winner < fighters.size() else null
	if is_instance_valid(winner):
		winner.model.play_victory()
	last_reward = 0
	if game_mode == "story":
		if last_winner == 0:
			last_reward = 180 + cpu_level * 35
			credits += last_reward
			total_wins += 1
			cpu_level += 1
			best_level = maxi(best_level, cpu_level)
		else:
			last_reward = 45
			credits += last_reward
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
	var local_player := local_lan_index if game_mode == "lan" else 0
	var victory := last_winner == local_player
	var title := "¡VICTORIA!" if victory else "GANA ROBOT %d" % (last_winner + 1)
	if game_mode == "story" and not victory:
		title = "DERROTA"
	box.add_child(_title_label(title, 52, GOLD if victory else RED))
	if game_mode == "story":
		var message := "SUPERASTE EL NIVEL %d" % (cpu_level - 1) if victory else "EL RIVAL NIVEL %d FUE MÁS FUERTE" % cpu_level
		var info := _label(message, 22, INK)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(info)
		var reward_label := _label("+%d CRÉDITOS · TOTAL %d" % [last_reward, credits], 21, GOLD)
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(reward_label)
		if victory:
			box.add_child(_make_button("▶  SIGUIENTE RIVAL · NIVEL %d" % cpu_level, _next_cpu_battle, BLUE, Vector2(540, 64)))
		else:
			box.add_child(_make_button("↻  REINTENTAR NIVEL %d" % cpu_level, _retry_cpu_battle, RED, Vector2(540, 64)))
		box.add_child(_make_button("🔧  VOLVER AL TALLER", _rebuild_from_result, Color("9d88ff"), Vector2(540, 58)))
	elif game_mode == "local":
		var local_info := _label("Los robots pelearon con sus estadísticas y afinidades.\nEl golpe fuerte permitió intervenir sin depender del azar.", 20, INK)
		local_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(local_info)
		box.add_child(_make_button("↻  REVANCHA CON LOS MISMOS ROBOTS", _local_rematch, BLUE, Vector2(540, 64)))
		box.add_child(_make_button("🔧  CONSTRUIR DOS ROBOTS NUEVOS", _restart_local_build, RED, Vector2(540, 58)))
	else:
		var lan_info := _label("PELEA LAN TERMINADA · GANA ROBOT %d" % (last_winner + 1), 21, INK)
		lan_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(lan_info)
		box.add_child(_make_button("📡  VOLVER A LA SALA LAN", _show_lan_lobby, Color("8edfa8"), Vector2(540, 60)))
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
		"1. ARMA Y REVISA LAS 10 BARRAS\nVida, daño, blindaje, movimiento, ataque, alcance, energía, precisión, estabilidad y peso cambian con cada pieza.\n\n" +
		"2. USA LAS AFINIDADES\nHidráulico > Térmico > Criógeno > Mineral > Eléctrico > Hidráulico. Una ventaja causa más daño.\n\n" +
		"3. HISTORIA Y TIENDA\nGana créditos peleando contra la CPU y toca una pieza bloqueada para comprarla.\n\n" +
		"4. GOLPE FUERTE\nTú decides cuándo lanzarlo. Siempre impacta al alcanzar al objetivo, pero necesita recargarse.\n\n" +
		"VS Y LAN\nEn VS están las 160 piezas desbloqueadas. En LAN pueden conectar de 2 a 4 teléfonos al mismo Wi-Fi.",
		17,
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
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.queue_free()
	fighters.clear()
	fighter_a = null
	fighter_b = null

func _reset_runtime() -> void:
	Engine.time_scale = 1.0
	if audio:
		audio.stop_music()
	battle_started = false
	battle_finished = false
	if lan:
		lan.close_connection()
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
	stats_bars.clear()
	stat_value_labels.clear()
	fighter_hp_bars.clear()
	fighter_hp_texts.clear()
	heavy_buttons.clear()
	lan_status_label = null
	lan_start_button = null

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

func _stat_bar(color: Color) -> ProgressBar:
	var bar := _health_bar(color)
	bar.custom_minimum_size = Vector2(0.0, 13.0)
	return bar

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_level", best_level)
	config.set_value("progress", "current_level", cpu_level)
	config.set_value("progress", "total_wins", total_wins)
	config.set_value("progress", "credits", credits)
	for slot in Catalog.SLOTS:
		config.set_value("unlocks", slot, unlocked_parts.get(slot, [0, 1, 2, 3]))
	config.save("user://forja_infinita_save.cfg")

func _load_progress() -> void:
	_initialize_unlocks()
	var config := ConfigFile.new()
	if config.load("user://forja_infinita_save.cfg") == OK:
		best_level = maxi(1, int(config.get_value("progress", "best_level", 1)))
		cpu_level = maxi(1, int(config.get_value("progress", "current_level", 1)))
		total_wins = maxi(0, int(config.get_value("progress", "total_wins", 0)))
		credits = maxi(0, int(config.get_value("progress", "credits", 600)))
		for slot in Catalog.SLOTS:
			var saved: Array = config.get_value("unlocks", slot, [0, 1, 2, 3])
			unlocked_parts[slot] = saved.duplicate()

func _initialize_unlocks() -> void:
	unlocked_parts.clear()
	for slot in Catalog.SLOTS:
		unlocked_parts[slot] = [0, 1, 2, 3]

func _is_part_unlocked(slot: String, index: int) -> bool:
	var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
	return index in unlocked

func _unlock_part(slot: String, index: int) -> void:
	var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
	if not index in unlocked:
		unlocked.append(index)
		unlocked.sort()
	unlocked_parts[slot] = unlocked

func _random_owned_build() -> Dictionary:
	var build := {}
	for slot in Catalog.SLOTS:
		var unlocked: Array = unlocked_parts.get(slot, [0, 1, 2, 3])
		build[slot] = int(unlocked[randi_range(0, unlocked.size() - 1)])
	return build

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
	passed = passed and Catalog.STAT_KEYS.size() == 10 and Catalog.AFFINITIES.size() == 5
	passed = passed and float(stats.health) > 0.0 and float(stats.power) > 0.0
	passed = passed and Catalog.combat_rating(maximum_build) > 0.0
	passed = passed and Catalog.affinity_multiplier("hydraulic", "thermal") > 1.0
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
	passed = passed and fighter_test_a.request_heavy_attack()
	var hp_before: float = fighter_test_b.hp
	fighter_test_b.take_damage(50.0, fighter_test_a.global_position, false)
	passed = passed and fighter_test_b.hp < hp_before
	print("FORJA_SMOKE_TEST:", "PASS" if passed else "FAIL", " slots=", Catalog.SLOTS.size(), " options=160 stats=10 affinities=5 LAN=4 combat=OK")
	get_tree().quit(0 if passed else 1)
