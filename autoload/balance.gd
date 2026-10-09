extends Node
# Every tunable number in the game lives here, so a student can answer
# "why does it feel like this?" by pointing at one file.

const PX_PER_M := 10.0

# ---- Launch (boat ramp, then a ballistic arc through the air) ----
const RAMP_START := Vector2(-330, -330)
const RAMP_END := Vector2(0, -190)
const LAUNCH_SPEED := 440.0          # px/s at the end of the ramp, before upgrades
const AIR_GRAVITY := 650.0
const ENTRY_FLAT_DEG := 10.0         # facing this flat or flatter = worst belly-flop
const ENTRY_STEEP_DEG := 40.0        # facing this steep or steeper = no loss
const ENTRY_MAX_LOSS := 0.4

# ---- Underwater flight model (see player.gd) ----
const GRAVITY := 700.0               # sinking weight
const TILT_RATE := deg_to_rad(130.0)
const ANGLE_MIN := deg_to_rad(-35.0)
const ANGLE_MAX := deg_to_rad(85.0)
const WING_TURN := 2.5               # rad/s the velocity may turn toward the nose
const DRAG := 0.0022
const DRAG_MISALIGN := 0.0003        # extra drag when nose and motion disagree
const THRUST := 650.0

# ---- Touching the world ----
const PLAYER_RADIUS := 22.0
const CRASH_SPEED := 330.0           # speed INTO the floor above which the run ends
const FLOOR_FRICTION := 1.4          # per second, scrapes speed while skimming
const REST_SPEED := 60.0
const REST_TIME := 0.5
const CEILING_KEEP := 0.8            # speed kept after a ceiling bump
const CEILING_COOLDOWN := 0.5

# ---- Resources ----
const BASE_OXYGEN := 18.0
const BASE_FUEL := 1.5

# ---- Things in the water ----
const OXYGEN_FROM_CANISTER := 8.0
const OXYGEN_FROM_ANIMAL := 6.0
const FUEL_FROM_CELL := 0.4          # fraction of the tank
const ANIMAL_BURST := 150.0          # px/s added when an animal swims free
const NET_ANIMAL_CHANCE := 0.2       # 1 net in 5 holds an animal
const NET_RATE := {"reef": 0.9, "city": 1.4, "slope": 1.1, "trench": 0.9}   # loose nets per 600 px slice
const WALL_DISTANCES_M := [400, 1500, 2800, 3600]

# ---- Terrain ----
const START_FLOOR := 420.0
const TERRAIN_AHEAD := 4000.0
const TERRAIN_BEHIND := 3000.0

# Zones by distance in metres. "corridor" is floor-to-ceiling height in px.
const ZONES := [
	{"id": "reef", "name": "Lumen Reef", "start_m": 0, "corridor": 700.0},
	{"id": "city", "name": "The Drowned City", "start_m": 400, "corridor": 700.0},
	{"id": "slope", "name": "The Slope", "start_m": 1500, "corridor": 450.0},
	{"id": "trench", "name": "The Trench", "start_m": 2800, "corridor": 520.0},
	{"id": "abyss", "name": "The Abyss", "start_m": 3600, "corridor": 600.0},
]

# ---- Upgrades ----
const UPGRADE_ORDER := ["ramp", "sled", "wing", "thruster", "fuel", "o2", "ballast", "cutter", "pip", "net_return"]
const UPGRADE_COSTS := {
	"ramp": [5, 10, 18, 30, 45],
	"sled": [8, 16, 28, 45],
	"wing": [6, 12, 22, 36, 55],
	"thruster": [8, 16, 30, 48],
	"fuel": [6, 12, 22, 36],
	"o2": [5, 10, 18, 30, 45],
	"ballast": [8, 16, 28, 45],
	"cutter": [6, 12, 22, 36, 55],
	"pip": [10, 20, 35],
	"net_return": [12, 25, 40, 60, 90],
}
# What the dock shows for each upgrade. "icon" is a sprite cropped to its visible part.
const UPGRADE_INFO := {
	"ramp": {"name": "Ramp", "effect": "+12% launch speed", "icon": "boat07"},
	"sled": {"name": "Dive Sled", "effect": "+10% launch speed, softer splash, -8% drag", "icon": "gear_sled"},
	"wing": {"name": "Manta Wing", "effect": "+35% wing turn: longer glides", "icon": "gear_wing"},
	"thruster": {"name": "Thruster", "effect": "+25% thrust", "icon": "gear_thruster"},
	"fuel": {"name": "Fuel Tank", "effect": "+1 s of thruster fuel", "icon": "fuel_cell"},
	"o2": {"name": "O2 Tank", "effect": "+6 s of oxygen", "icon": "o2_canister"},
	"ballast": {"name": "Ballast", "effect": "+15% sink rate and wall damage", "icon": "gear_ballast"},
	"cutter": {"name": "Cutter", "effect": "Nets slow you less. +20% wall damage", "icon": "nova_arm_front"},
	"pip": {"name": "Pip", "effect": "Pickup magnet. Lv 3: arrow to next O2", "icon": "pip_cyan"},
	"net_return": {"name": "Net Return", "effect": "Fewer loose nets in the water", "icon": "net_0"},
}

# Captain Vale's line for each Net Return level (level 5 and beyond use the last one).
const CAPTAIN_LINES := [
	"A new net costs less than an hour of hauling.",
	"Fine. We log every tag you bring up.",
	"There's a return bin on the dock now.",
	"Boats haul their snags back. It costs us an hour.",
	"Every net is tagged and tracked.",
	"Every net that goes down comes back up.",
]

# Loose-net density multiplier for Net Return level 0..5.
const NET_RETURN_FACTORS := [1.0, 0.85, 0.70, 0.55, 0.45, 0.35]


func zone_index_at(x_px: float) -> int:
	var metres := x_px / PX_PER_M
	var index := 0
	for i in ZONES.size():
		if metres >= ZONES[i]["start_m"]:
			index = i
	return index


# Corridor height at x. Blends between zones over 400 px so the ceiling has no cliff.
func corridor_at(x_px: float) -> float:
	var i := zone_index_at(x_px)
	var here: float = ZONES[i]["corridor"]
	if i + 1 < ZONES.size():
		var next_x: float = ZONES[i + 1]["start_m"] * PX_PER_M
		if x_px > next_x - 400.0:
			return lerpf(here, ZONES[i + 1]["corridor"], (x_px - (next_x - 400.0)) / 400.0)
	return here


func zone_id_at(x_px: float) -> String:
	return ZONES[zone_index_at(x_px)]["id"]


# Tags earned by a dive. Same formula the results screen shows line by line.
func tags_for(distance_m: float, depth_m: float, nets_cut: int, animals_freed: int, wall_bonus: int) -> int:
	return int(distance_m / 10.0) + int(depth_m / 10.0) + nets_cut + 3 * animals_freed + wall_bonus


func upgrade_max(id: String) -> int:
	return UPGRADE_COSTS[id].size()


# Cost to buy the NEXT level. Past the cap (endless mode) each level costs 1.6x the last.
func upgrade_cost(id: String, current_level: int) -> int:
	var costs: Array = UPGRADE_COSTS[id]
	if current_level < costs.size():
		return costs[current_level]
	return int(round(costs[-1] * pow(1.6, current_level - costs.size() + 1)))


func net_factor(net_return_level: int) -> float:
	if net_return_level < NET_RETURN_FACTORS.size():
		return NET_RETURN_FACTORS[net_return_level]
	return NET_RETURN_FACTORS[-1] * pow(0.9, net_return_level - NET_RETURN_FACTORS.size() + 1)


# Turns upgrade levels into the multipliers the game uses. One place, easy to explain.
func stats_for(levels: Dictionary) -> Dictionary:
	var ramp: int = levels.get("ramp", 0)
	var sled: int = levels.get("sled", 0)
	var wing: int = levels.get("wing", 0)
	var thruster: int = levels.get("thruster", 0)
	var fuel: int = levels.get("fuel", 0)
	var o2: int = levels.get("o2", 0)
	var ballast: int = levels.get("ballast", 0)
	var cutter: int = levels.get("cutter", 0)
	var pip: int = levels.get("pip", 0)
	var net_return: int = levels.get("net_return", 0)
	return {
		"launch_speed": LAUNCH_SPEED * (1.0 + 0.12 * ramp + 0.10 * sled),
		"entry_loss_mult": maxf(0.0, 1.0 - 0.2 * sled),
		"drag_mult": maxf(0.3, 1.0 - 0.08 * sled),
		"wing_mult": 1.0 + 0.35 * wing,
		"thrust_mult": 1.0 + 0.25 * thruster,
		"max_fuel": BASE_FUEL + 1.0 * fuel,
		"max_oxygen": BASE_OXYGEN + 6.0 * o2,
		"ballast_mult": 1.0 + 0.15 * ballast,
		"net_slow": minf(0.98, 0.55 + 0.08 * cutter),
		"cutter_mult": 1.0 + 0.2 * cutter,
		"magnet_radius": 90.0 * pip,
		"pip_arrow": pip >= 3,
		"net_density": net_factor(net_return),
	}
