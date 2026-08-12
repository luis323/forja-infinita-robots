class_name PartThumbnail
extends Control

const Catalog = preload("res://scripts/robot_catalog.gd")

var slot := "head"
var option_index := 0
var selected := false
var locked := false

func setup(new_slot: String, new_index: int, is_selected: bool, is_locked: bool) -> void:
	slot = new_slot
	option_index = new_index
	selected = is_selected
	locked = is_locked
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var affinity: String = Catalog.AFFINITIES[option_index % Catalog.AFFINITIES.size()]
	var color: Color = Catalog.AFFINITY_COLORS[affinity]
	var dark := color.darkened(0.48)
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var visual_scale: float = clampf(minf(size.x / 54.0, size.y / 48.0), 1.0, 2.75)
	draw_set_transform(center, 0.0, Vector2.ONE * visual_scale)
	if selected:
		draw_circle(Vector2.ZERO, 19.0, Color(color, 0.20))
	match slot:
		"head":
			_draw_head(Vector2.ZERO, color, dark)
		"torso":
			_draw_torso(Vector2.ZERO, color, dark)
		"left_arm", "right_arm":
			_draw_arm(Vector2.ZERO, color, dark)
		"left_leg", "right_leg":
			_draw_leg(Vector2.ZERO, color, dark)
		_:
			_draw_weapon(Vector2.ZERO, color, dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(size.x - 10.0, 10.0), 5.2, color)
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color("d90c101c"), true)
		for stripe_x in range(-40, 80, 12):
			draw_line(Vector2(float(stripe_x), size.y), Vector2(float(stripe_x + 38), 0.0), Color("38ff537f"), 3.0)
		draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), Color("ff537f"), false, 2.5)
		draw_rect(Rect2(center + Vector2(-9.0, -1.0), Vector2(18.0, 15.0)), Color("ef24162c"), true)
		draw_arc(center + Vector2(0.0, -1.0), 6.5, PI, TAU, 14, Color("fff1bd"), 3.0)
		draw_circle(center + Vector2(0.0, 6.0), 2.0, Color("fff1bd"))

func _draw_head(center: Vector2, color: Color, dark: Color) -> void:
	var width := 20.0 + float(option_index % 4) * 2.2
	var height := 15.0 + float(floori(float(option_index) / 4.0) % 3) * 2.0
	draw_rect(Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height)), dark, true)
	if option_index % 3 == 0:
		draw_rect(Rect2(center + Vector2(-width * 0.36, -2.0), Vector2(width * 0.72, 4.0)), color, true)
	elif option_index % 3 == 1:
		draw_circle(center, 4.3, color)
	else:
		draw_circle(center + Vector2(-5.0, 0.0), 3.0, color)
		draw_circle(center + Vector2(5.0, 0.0), 3.0, color)
	if option_index in [3, 9, 16, 18, 19]:
		draw_line(center + Vector2(-7.0, -height * 0.5), center + Vector2(-11.0, -height), color, 2.5)
		draw_line(center + Vector2(7.0, -height * 0.5), center + Vector2(11.0, -height), color, 2.5)

func _draw_torso(center: Vector2, color: Color, dark: Color) -> void:
	var width := 21.0 + float(option_index % 5) * 2.0
	var height := 22.0 - float(option_index % 4)
	var points := PackedVector2Array([
		center + Vector2(-width * 0.5, -height * 0.45),
		center + Vector2(width * 0.5, -height * 0.45),
		center + Vector2(width * 0.36, height * 0.50),
		center + Vector2(-width * 0.36, height * 0.50),
	])
	draw_polygon(points, PackedColorArray([dark]))
	if option_index % 2 == 0:
		draw_circle(center, 5.0 + float(option_index % 3), color)
	else:
		draw_rect(Rect2(center - Vector2(8.0, 3.0), Vector2(16.0, 6.0)), color, true)

func _draw_arm(center: Vector2, color: Color, dark: Color) -> void:
	var thin := 3.0 + float(option_index % 4)
	var length := 11.0 + float(option_index % 6)
	var elbow := center + Vector2(-5.0, 1.0)
	draw_line(center + Vector2(-length, -8.0), elbow, dark, thin + 2.0)
	draw_circle(elbow, thin, color)
	draw_line(elbow, center + Vector2(length, 7.0), dark, thin)
	if option_index % 5 == 0:
		for y in [-5.0, 0.0, 5.0]:
			draw_line(center + Vector2(length, 7.0), center + Vector2(length + 7.0, 7.0 + y), color, 1.8)
	else:
		draw_circle(center + Vector2(length, 7.0), thin + 2.0, color)

func _draw_leg(center: Vector2, color: Color, dark: Color) -> void:
	var spread := 5.0 + float(option_index % 4)
	var knee := center + Vector2(spread, 1.0)
	draw_line(center + Vector2(-spread, -12.0), knee, dark, 5.0 + float(option_index % 3))
	draw_circle(knee, 3.5, color)
	draw_line(knee, center + Vector2(-spread * 0.5, 12.0), dark, 4.0)
	if option_index in [2, 3, 9, 12]:
		draw_circle(center + Vector2(-spread * 0.5, 12.0), 6.0, color)
		draw_circle(center + Vector2(-spread * 0.5, 12.0), 2.5, Color("172038"))
	else:
		draw_rect(Rect2(center + Vector2(-spread - 3.0, 10.0), Vector2(15.0, 5.0)), color, true)

func _draw_weapon(center: Vector2, color: Color, dark: Color) -> void:
	match option_index:
		0:
			draw_line(center + Vector2(-10.0, 12.0), center + Vector2(4.0, -6.0), dark, 4.0)
			draw_rect(Rect2(center + Vector2(-3.0, -13.0), Vector2(19.0, 10.0)), color, true)
		1:
			draw_polygon(PackedVector2Array([center + Vector2(-4.0, 13.0), center + Vector2(-1.0, -14.0), center + Vector2(5.0, -4.0)]), PackedColorArray([color]))
		2:
			draw_circle(center + Vector2(-7.0, 8.0), 5.0, dark)
			draw_circle(center + Vector2(7.0, 8.0), 5.0, dark)
			draw_line(center, center + Vector2(-13.0, -13.0), color, 3.0)
			draw_line(center, center + Vector2(13.0, -13.0), color, 3.0)
		4:
			draw_circle(center, 14.0, color)
			for angle in range(0, 360, 45):
				var direction := Vector2.from_angle(deg_to_rad(float(angle)))
				draw_line(center + direction * 12.0, center + direction * 17.0, color, 3.0)
		7:
			draw_line(center + Vector2(-10.0, 13.0), center + Vector2(4.0, -7.0), dark, 4.0)
			draw_polygon(PackedVector2Array([center + Vector2(-2.0, -10.0), center + Vector2(13.0, -15.0), center + Vector2(9.0, 0.0)]), PackedColorArray([color]))
		_:
			draw_line(center + Vector2(-13.0, 9.0), center + Vector2(10.0, -10.0), dark, 5.0)
			draw_circle(center + Vector2(10.0, -10.0), 7.0 + float(option_index % 4), color)
