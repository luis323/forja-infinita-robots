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
	"Visor Aurora", "Cráneo Prisma", "Domo Cíclope", "Yelmo Cometa", "Cubo-8",
	"Radar Mariposa", "Faros Gemelos", "Máscara Voltio", "Nodo Oráculo", "Meteorito",
	"Cabeza Taladro", "Antena Coral", "Mandíbula Titanio", "Prisma Holográfico", "Ojo Panorámico",
	"Casco Aleta", "Cúpula Solar", "Casco Relámpago", "Faro Abisal", "Corona Vector",
]

const TORSO_NAMES := [
	"Núcleo Colmena", "Reactor Solar", "Pecho Fortaleza", "Chasis Avispa", "Cámara Glacial",
	"Reactor Cobalto", "Caparazón Tortuga", "Bastidor Acróbata", "Motor Vórtice", "Placa Meteoro",
	"Cofre Magnético", "Chasis Submarino", "Armadura Salvavidas", "Núcleo de Plasma", "Bastidor Nube",
	"Torso Locomotora", "Reactor Musgo", "Pecho Prisma", "Chasis Draco", "Núcleo Infinito",
]

const ARM_NAMES := [
	"Pinza Hidráulica", "Antebrazo Turbo", "Brazo Resorte", "Escudo Integrado", "Pistón Pesado",
	"Brazo Telescópico", "Guante Magnético", "Módulo Arácnido", "Ala Articulada", "Brazo Taladro",
	"Bíceps Reactor", "Garra Cangrejo", "Brazo de Vapor", "Puño Prisma", "Látigo Mecánico",
	"Brazo Cohete", "Tenaza Industrial", "Módulo Fantasma", "Puño Meteoro", "Brazo Vectorial",
]

const LEG_NAMES := [
	"Bota Pistón", "Pierna Saltamontes", "Oruga Compacta", "Rueda Monociclo", "Pata Arácnida",
	"Propulsor Gemelo", "Bota Magnética", "Resorte Sísmico", "Pierna Corredora", "Flotador Iónico",
	"Pata Garra", "Zanco Hidráulico", "Rueda Omni", "Bota Cometa", "Pierna Acorazada",
	"Propulsor Solar", "Pata Felina", "Rodilla Taladro", "Bota Prisma", "Pierna Vectorial",
]

const WEAPON_NAMES := [
	"Martillo de Pulso", "Espada Fotónica", "Guante de Choque", "Cañón Burbuja", "Sierra Circular",
	"Lanza Magnética", "Rayo Congelante", "Yoyó de Acero", "Taladro Cohete", "Escudo Búmeran",
	"Maza Gravitatoria", "Bláster Solar", "Látigo Eléctrico", "Hacha de Plasma", "Puño Extensible",
	"Cañón de Red", "Lanza Cometa", "Disco Prisma", "Imán Demoledor", "Orbe Vectorial",
]

const TRAITS := [
	"Equilibrado", "Preciso", "Blindado", "Veloz", "Elástico",
	"Solar", "Magnético", "Acróbata", "Vórtice", "Meteoro",
	"Industrial", "Abisal", "Rescatista", "Plasma", "Aéreo",
	"Locomotor", "Orgánico", "Prismático", "Dracónico", "Vectorial",
]

const FAMILIES := ["taller", "solar", "fortaleza", "veloz", "elástico"]

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
		"shape": safe_index % 7,
		"color": Color.from_hsv(fmod(0.53 + float(safe_index) * 0.071, 1.0), 0.68, 0.95),
		"health": 0.0,
		"power": 0.0,
		"armor": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"energy": 0.0,
	}
	match slot:
		"head":
			option.health = 18.0 + tier * 7.0
			option.power = 1.0 + pulse * 0.7
			option.armor = 1.0 + tier * 0.9
			option.speed = 0.15 + (4 - pulse) * 0.05
			option.range = 0.25 + pulse * 0.18
			option.energy = 8.0 + tier * 3.0 + pulse
		"torso":
			option.health = 78.0 + tier * 25.0 + pulse * 5.0
			option.power = 3.0 + tier * 1.8
			option.armor = 5.0 + tier * 2.2 + pulse * 0.6
			option.speed = 0.03 + (4 - pulse) * 0.02
			option.energy = 15.0 + tier * 8.0
		"left_arm", "right_arm":
			option.health = 28.0 + tier * 9.0
			option.power = 5.0 + tier * 2.4 + pulse * 1.0
			option.armor = 2.0 + tier * 1.1
			option.speed = 0.10 + (4 - pulse) * 0.04
			option.range = 0.12 + pulse * 0.08
			option.energy = 3.0 + tier * 2.0
		"left_leg", "right_leg":
			option.health = 35.0 + tier * 10.0
			option.power = 1.0 + tier
			option.armor = 2.0 + tier * 1.3 + pulse * 0.4
			option.speed = 0.32 + tier * 0.10 + (4 - pulse) * 0.06
			option.energy = 2.0 + tier * 1.5
		"left_weapon", "right_weapon":
			option.health = 8.0 + tier * 4.0
			option.power = 9.0 + tier * 4.0 + pulse * 1.7
			option.armor = 0.5 + tier * 0.6
			option.speed = 0.06 + (4 - pulse) * 0.04
			option.range = 0.35 + pulse * 0.25 + tier * 0.10
			option.energy = 5.0 + tier * 3.0
	return option

static func build_stats(build: Dictionary) -> Dictionary:
	var stats := {
		"health": 420.0,
		"power": 14.0,
		"armor": 3.0,
		"speed": 2.25,
		"range": 1.55,
		"energy": 30.0,
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
	stats.speed = clampf(stats.speed, 3.2, 8.5)
	stats.range = clampf(stats.range, 2.0, 8.0)
	return stats

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
	return "%s · %s\nPOT +%.0f   ARM +%.0f   VEL +%.1f\nVIDA +%.0f   ALC +%.1f   ENE +%.0f" % [
		part.name,
		part.trait,
		part.power,
		part.armor,
		part.speed,
		part.health,
		part.range,
		part.energy,
	]

static func validate_catalog() -> bool:
	for slot in SLOTS:
		if names_for(slot).size() != 20:
			push_error("El catálogo %s no tiene 20 opciones" % slot)
			return false
	return true
