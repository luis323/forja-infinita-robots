class_name RobotCatalog
extends RefCounted

const SLOTS := [
	"head",
	"torso",
	"left_arm",
	"right_arm",
	"left_leg",
	"right_leg",
	"left_weapon",
	"right_weapon",
]

const LABELS := {
	"head": "CABEZA",
	"torso": "TORSO",
	"left_arm": "BRAZO IZQ.",
	"right_arm": "BRAZO DER.",
	"left_leg": "PIERNA IZQ.",
	"right_leg": "PIERNA DER.",
	"left_weapon": "ARMA IZQ.",
	"right_weapon": "ARMA DER.",
}

const HEAD_NAMES := [
	"Televisor Aurora", "Domo Prisma", "Ojo Cíclope", "Casco Cometa", "Cubo-8",
	"Radar Mariposa", "Ojitos Gemelos", "Máscara Voltio", "Nodo Oráculo", "Casco Meteorito",
	"Nariz Taladro", "Antena Coral", "Visor Retro", "Pantalla Holográfica", "Ojos Panorámicos",
	"Casco Vanguardia", "Domo Sonriente", "Radar Tormenta", "Pantalla Abisal", "Corona de Mando",
]

const TORSO_NAMES := [
	"Panel Colmena", "Reloj Solar", "Barriga Fortaleza", "Chasis Avispa", "Cámara Glacial",
	"Reactor Cobalto", "Caparazón Tortuga", "Bastidor Acróbata", "Motor Vórtice", "Placa Meteoro",
	"Cofre Magnético", "Chasis Submarino", "Bastión de Rescate", "Reactor de Asedio", "Bastidor Ala Alta",
	"Barriga Locomotora", "Carcasa Foresta", "Panel Prisma", "Coraza Dragón", "Reloj de Mando",
]

const ARM_NAMES := [
	"Pinza Hidráulica", "Antebrazo Turbo", "Brazo Resorte", "Escudo Integrado", "Pistón Pesado",
	"Brazo Telescópico", "Guante Magnético", "Módulo Arácnido", "Ala Articulada", "Brazo Taladro",
	"Bíceps Reactor", "Garra Cangrejo", "Actuador de Vapor", "Puño Prisma", "Cable Articulado",
	"Módulo Propulsor", "Tenaza de Asedio", "Módulo Sigilo", "Puño Coloso", "Actuador Vector",
]

const LEG_NAMES := [
	"Bota Pistón", "Pierna Saltamontes", "Oruga Compacta", "Rueda Monociclo", "Pata Arácnida",
	"Propulsor Gemelo", "Bota Magnética", "Resorte Sísmico", "Pierna Corredora", "Flotador Iónico",
	"Pata Garra", "Zanco Hidráulico", "Tren Omni", "Bota de Salto", "Pierna de Asedio",
	"Propulsor Solar", "Pata de Caza", "Rodilla Barrena", "Bota Prisma", "Tren Vector",
]

const WEAPON_NAMES := [
	"Martillo de Pulso", "Espada Fotónica", "Tijera Industrial", "Cañón Burbuja", "Sierra Circular",
	"Lanza Magnética", "Rayo Congelante", "Pala Cinética", "Taladro Cohete", "Escudo Búmeran",
	"Maza Gravitatoria", "Bláster Solar", "Látigo Eléctrico", "Hacha de Plasma", "Puño Extensible",
	"Lanzador de Red", "Pica de Cometa", "Disco Centinela", "Imán de Asedio", "Orbe de Mando",
]

const TRAITS := [
	"Equilibrado", "Preciso", "Blindado", "Veloz", "Elástico",
	"Solar", "Magnético", "Acróbata", "Vórtice", "Meteoro",
	"Industrial", "Abisal", "Rescatista", "Plasma", "Aéreo",
	"Locomotor", "Orgánico", "Prismático", "Dracónico", "Vectorial",
]

const FAMILIES := ["taller", "solar", "fortaleza", "veloz", "elástico"]

const AFFINITIES := ["thermal", "hydraulic", "electric", "mineral", "cryo"]
const AFFINITY_NAMES := {
	"thermal": "TÉRMICO",
	"hydraulic": "HIDRÁULICO",
	"electric": "ELÉCTRICO",
	"mineral": "MINERAL",
	"cryo": "CRIÓGENO",
}
const AFFINITY_COLORS := {
	"thermal": Color("ff6b4a"),
	"hydraulic": Color("48baff"),
	"electric": Color("ffe64d"),
	"mineral": Color("b49372"),
	"cryo": Color("9ff5ff"),
}
const AFFINITY_BEATS := {
	"thermal": "cryo",
	"cryo": "mineral",
	"mineral": "electric",
	"electric": "hydraulic",
	"hydraulic": "thermal",
}

const STAT_KEYS := ["health", "power", "armor", "speed", "attack_speed", "range", "energy", "accuracy", "stability", "weight"]
const STAT_LABELS := {
	"health": "VIDA",
	"power": "DAÑO",
	"armor": "BLINDAJE",
	"speed": "MOVIMIENTO",
	"attack_speed": "VEL. ATAQUE",
	"range": "ALCANCE",
	"energy": "ENERGÍA",
	"accuracy": "PRECISIÓN",
	"stability": "ESTABILIDAD",
	"weight": "PESO",
}
const STAT_RANGES := {
	"health": Vector2(600.0, 1250.0),
	"power": Vector2(70.0, 180.0),
	"armor": Vector2(20.0, 80.0),
	"speed": Vector2(2.4, 8.5),
	"attack_speed": Vector2(0.55, 2.25),
	"range": Vector2(2.0, 8.0),
	"energy": Vector2(65.0, 190.0),
	"accuracy": Vector2(50.0, 98.0),
	"stability": Vector2(15.0, 90.0),
	"weight": Vector2(55.0, 230.0),
}

static func empty_build() -> Dictionary:
	var build := {}
	for slot in SLOTS:
		build[slot] = 0
	return build

static func random_build(max_index: int = 19) -> Dictionary:
	var build := {}
	var capped := clampi(max_index, 0, 19)
	for slot in SLOTS:
		build[slot] = randi_range(0, capped)
	return build

static func names_for(slot: String) -> Array:
	match slot:
		"head":
			return HEAD_NAMES
		"torso":
			return TORSO_NAMES
		"left_arm", "right_arm":
			return ARM_NAMES
		"left_leg", "right_leg":
			return LEG_NAMES
		"left_weapon", "right_weapon":
			return WEAPON_NAMES
	return []

static func get_option(slot: String, index: int) -> Dictionary:
	var safe_index := clampi(index, 0, 19)
	var names := names_for(slot)
	if names.is_empty():
		return {}
	var tier := floori(float(safe_index) / 4.0)
	var pulse := safe_index % 5
	var option := {
		"name": names[safe_index],
		"trait": TRAITS[safe_index],
		"family": FAMILIES[pulse],
		"affinity": AFFINITIES[pulse],
		"shape": safe_index % 7,
		"color": AFFINITY_COLORS[AFFINITIES[pulse]].lerp(Color.from_hsv(fmod(0.53 + float(safe_index) * 0.071, 1.0), 0.68, 0.95), 0.24),
		"health": 0.0,
		"power": 0.0,
		"armor": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"energy": 0.0,
		"attack_speed": 0.0,
		"accuracy": 0.0,
		"stability": 0.0,
		"weight": 0.0,
	}
	match slot:
		"head":
			option.health = 18.0 + tier * 7.0
			option.power = 1.0 + pulse * 0.7
			option.armor = 1.0 + tier * 0.9
			option.speed = 0.15 + (4 - pulse) * 0.05
			option.range = 0.25 + pulse * 0.18
			option.energy = 8.0 + tier * 3.0 + pulse
			option.attack_speed = 0.04 + (4 - pulse) * 0.015
			option.accuracy = 5.0 + tier * 1.4 + pulse * 0.8
			option.stability = 1.0 + tier * 1.2
			option.weight = 5.0 + tier * 1.8 + pulse * 0.4
		"torso":
			option.health = 78.0 + tier * 25.0 + pulse * 5.0
			option.power = 3.0 + tier * 1.8
			option.armor = 5.0 + tier * 2.2 + pulse * 0.6
			option.speed = 0.03 + (4 - pulse) * 0.02
			option.energy = 15.0 + tier * 8.0
			option.attack_speed = 0.02 + (4 - pulse) * 0.01
			option.accuracy = 1.0 + pulse * 0.6
			option.stability = 8.0 + tier * 3.0 + pulse
			option.weight = 22.0 + tier * 7.0 + pulse * 2.0
		"left_arm", "right_arm":
			option.health = 28.0 + tier * 9.0
			option.power = 5.0 + tier * 2.4 + pulse * 1.0
			option.armor = 2.0 + tier * 1.1
			option.speed = 0.10 + (4 - pulse) * 0.04
			option.range = 0.12 + pulse * 0.08
			option.energy = 3.0 + tier * 2.0
			option.attack_speed = 0.07 + (4 - pulse) * 0.025
			option.accuracy = 2.0 + pulse * 0.9
			option.stability = 2.0 + tier * 1.2
			option.weight = 7.0 + tier * 3.0 + pulse
		"left_leg", "right_leg":
			option.health = 35.0 + tier * 10.0
			option.power = 1.0 + tier
			option.armor = 2.0 + tier * 1.3 + pulse * 0.4
			option.speed = 0.32 + tier * 0.10 + (4 - pulse) * 0.06
			option.energy = 2.0 + tier * 1.5
			option.attack_speed = 0.02 + (4 - pulse) * 0.012
			option.accuracy = 0.5 + pulse * 0.4
			option.stability = 4.0 + tier * 2.0 + pulse
			option.weight = 9.0 + tier * 3.5 + pulse * 1.2
		"left_weapon", "right_weapon":
			option.health = 8.0 + tier * 4.0
			option.power = 9.0 + tier * 4.0 + pulse * 1.7
			option.armor = 0.5 + tier * 0.6
			option.speed = 0.06 + (4 - pulse) * 0.04
			option.range = 0.35 + pulse * 0.25 + tier * 0.10
			option.energy = 5.0 + tier * 3.0
			option.attack_speed = 0.10 + (4 - pulse) * 0.035
			option.accuracy = 3.0 + tier * 1.2 + pulse
			option.stability = 1.0 + tier * 0.8
			option.weight = 6.0 + tier * 3.0 + pulse * 0.8
	return option

static func build_stats(build: Dictionary) -> Dictionary:
	var stats := {
		"health": 420.0,
		"power": 14.0,
		"armor": 3.0,
		"speed": 2.25,
		"range": 1.55,
		"energy": 30.0,
		"attack_speed": 0.58,
		"accuracy": 48.0,
		"stability": 12.0,
		"weight": 24.0,
	}
	for slot in SLOTS:
		var part := get_option(slot, int(build.get(slot, 0)))
		for stat in stats.keys():
			stats[stat] += float(part.get(stat, 0.0))
	var synergy := get_synergy(build)
	stats.health *= float(synergy.health_mult)
	stats.power *= float(synergy.power_mult)
	stats.armor *= float(synergy.armor_mult)
	stats.speed *= float(synergy.speed_mult)
	stats.range *= float(synergy.range_mult)
	stats.energy *= float(synergy.energy_mult)
	stats.attack_speed *= float(synergy.speed_mult)
	stats.stability *= float(synergy.armor_mult)
	stats.speed -= maxf(0.0, float(stats.weight) - 115.0) * 0.006
	stats.attack_speed -= maxf(0.0, float(stats.weight) - 105.0) * 0.0015
	stats.speed = clampf(stats.speed, 2.4, 8.5)
	stats.attack_speed = clampf(stats.attack_speed, 0.55, 2.25)
	stats.range = clampf(stats.range, 2.0, 8.0)
	stats.accuracy = clampf(stats.accuracy, 50.0, 98.0)
	stats.stability = clampf(stats.stability, 15.0, 90.0)
	stats.weight = clampf(stats.weight, 55.0, 230.0)
	return stats

static func normalized_stats(build: Dictionary) -> Dictionary:
	var stats := build_stats(build)
	var normalized := {}
	for key in STAT_KEYS:
		var limits: Vector2 = STAT_RANGES[key]
		normalized[key] = clampf(inverse_lerp(limits.x, limits.y, float(stats[key])) * 100.0, 0.0, 100.0)
	return normalized

static func chassis_class(build: Dictionary) -> String:
	var weight: float = float(build_stats(build).weight)
	if weight < 92.0:
		return "EXPLORADOR"
	if weight < 132.0:
		return "VANGUARDIA"
	if weight < 176.0:
		return "ASALTO"
	return "COLOSO"

static func loadout_summary(build: Dictionary) -> String:
	var left_name: String = str(WEAPON_NAMES[clampi(int(build.get("left_weapon", 0)), 0, 19)])
	var right_name: String = str(WEAPON_NAMES[clampi(int(build.get("right_weapon", 0)), 0, 19)])
	return "I · %s\nD · %s" % [left_name, right_name]

static func dominant_affinity(build: Dictionary) -> String:
	var counts := {}
	for affinity in AFFINITIES:
		counts[affinity] = 0
	for slot in SLOTS:
		var part := get_option(slot, int(build.get(slot, 0)))
		counts[part.affinity] = int(counts[part.affinity]) + 1
	var winner: String = AFFINITIES[0]
	for affinity in AFFINITIES:
		if int(counts[affinity]) > int(counts[winner]):
			winner = affinity
	return winner

static func weapon_affinity(build: Dictionary, use_left: bool) -> String:
	var slot := "left_weapon" if use_left else "right_weapon"
	return str(get_option(slot, int(build.get(slot, 0))).affinity)

static func affinity_multiplier(attacking_affinity: String, defending_affinity: String) -> float:
	if str(AFFINITY_BEATS.get(attacking_affinity, "")) == defending_affinity:
		return 1.35
	if str(AFFINITY_BEATS.get(defending_affinity, "")) == attacking_affinity:
		return 0.74
	if attacking_affinity == defending_affinity:
		return 0.92
	return 1.0

static func combat_rating(build: Dictionary) -> float:
	var stats := build_stats(build)
	var durability: float = float(stats.health) * (1.0 + float(stats.armor) / 115.0)
	var dps: float = float(stats.power) * float(stats.attack_speed) * float(stats.accuracy) / 100.0
	var control: float = 0.72 + float(stats.speed) * 0.035 + float(stats.range) * 0.025 + float(stats.stability) * 0.002
	return sqrt(durability * dps) * control

static func matchup_prediction(build_a: Dictionary, build_b: Dictionary) -> Dictionary:
	var rating_a := combat_rating(build_a)
	var rating_b := combat_rating(build_b)
	var affinity_a := dominant_affinity(build_a)
	var affinity_b := dominant_affinity(build_b)
	rating_a *= affinity_multiplier(affinity_a, affinity_b)
	rating_b *= affinity_multiplier(affinity_b, affinity_a)
	var total := maxf(0.001, rating_a + rating_b)
	return {
		"a": rating_a / total,
		"b": rating_b / total,
		"affinity_a": affinity_a,
		"affinity_b": affinity_b,
	}

static func part_price(slot: String, index: int) -> int:
	var tier := floori(float(clampi(index, 0, 19)) / 4.0)
	var slot_bonus := 55 if slot in ["left_weapon", "right_weapon"] else 0
	return 90 + tier * 145 + index * 18 + slot_bonus

static func get_synergy(build: Dictionary) -> Dictionary:
	var result := {
		"title": "MEZCLA IMPOSIBLE",
		"description": "Todas las piezas cooperan sin penalizaciones.",
		"health_mult": 1.0,
		"power_mult": 1.0,
		"armor_mult": 1.0,
		"speed_mult": 1.0,
		"range_mult": 1.0,
		"energy_mult": 1.0,
	}
	var counts := {}
	for slot in SLOTS:
		var family: String = get_option(slot, int(build.get(slot, 0))).family
		counts[family] = int(counts.get(family, 0)) + 1
	var strongest_family := ""
	var strongest_count := 0
	for family in counts:
		if int(counts[family]) > strongest_count:
			strongest_family = family
			strongest_count = int(counts[family])
	if strongest_count >= 4:
		match strongest_family:
			"taller":
				result.title = "MAESTRO DEL TALLER"
				result.armor_mult = 1.18
				result.description = "+18% blindaje por piezas industriales."
			"solar":
				result.title = "REACCIÓN SOLAR"
				result.energy_mult = 1.25
				result.power_mult = 1.08
				result.description = "+25% energía y +8% potencia."
			"fortaleza":
				result.title = "FORTALEZA ANDANTE"
				result.health_mult = 1.22
				result.description = "+22% estructura máxima."
			"veloz":
				result.title = "COMBO RELÁMPAGO"
				result.speed_mult = 1.17
				result.description = "+17% velocidad de movimiento y ataque."
			"elástico":
				result.title = "ALCANCE IMPOSIBLE"
				result.range_mult = 1.22
				result.description = "+22% alcance de combate."
	if int(build.get("left_weapon", -1)) == int(build.get("right_weapon", -2)):
		result.title = "ARMAS GEMELAS"
		result.power_mult *= 1.12
		result.description += " +12% potencia por armas idénticas."
	if int(build.get("left_leg", -1)) == int(build.get("right_leg", -2)):
		result.speed_mult *= 1.08
		result.description += " +8% velocidad por piernas sincronizadas."
	if int(build.get("left_arm", -1)) == int(build.get("right_arm", -2)):
		result.armor_mult *= 1.07
		result.description += " +7% blindaje por brazos sincronizados."
	return result

static func describe_option(slot: String, index: int) -> String:
	var part := get_option(slot, index)
	return "%s · %s · %s\nDAÑO +%.0f  ARM +%.0f  ATAQ +%.2f  PREC +%.0f\nVIDA +%.0f  ALC +%.1f  ENE +%.0f  PESO +%.0f" % [
		part.name,
		part.trait,
		AFFINITY_NAMES[part.affinity],
		part.power,
		part.armor,
		part.attack_speed,
		part.accuracy,
		part.health,
		part.range,
		part.energy,
		part.weight,
	]

static func validate_catalog() -> bool:
	for slot in SLOTS:
		if names_for(slot).size() != 20:
			push_error("El catálogo %s no tiene 20 opciones" % slot)
			return false
	return true
