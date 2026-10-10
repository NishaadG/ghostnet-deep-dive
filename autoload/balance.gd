extends Node
# Every tunable number in the game lives here, so a student can answer
# "why does it feel like this?" by pointing at one file.

const PX_PER_M := 10.0

# ---- Launch (boat ramp, then a ballistic arc through the air) ----
const RAMP_START := Vector2(-520, -330)        # top of the ramp with no Launch Ramp upgrades
const RAMP_END := Vector2(0, -190)             # the lip at the stern, where Nova leaves the boat
const LAUNCH_ANGLE_DEG := -14.0                # the ramp curves up into a ski jump: she leaves heading slightly upward
const RAMP_CURVE := 190.0                      # how far back the ski-jump curve starts (px)
const LAUNCH_SPEED := 440.0          # px/s at the end of the ramp, before upgrades
const AIR_GRAVITY := 520.0
const AIR_TILT_RATE := deg_to_rad(500.0)       # in the air she can spin freely and fast (flips)
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

# ---- Tricks (see scripts/style_score.gd) ----
const LOOP_MIN_SPEED := 420.0        # hold nose-up at the limit above this speed to loop
const LOOP_CHARGE := 0.12            # seconds of holding before the loop starts
const LOOP_RATE := 4.0               # rad/s while looping (a loop takes about 1.6 s)
const GRIND_MIN_SPEED := 250.0
const GRIND_MIN_TIME := 0.5
const AIR_MIN_TIME := 0.5            # airtime shorter than this does not score
const AIR_POINTS_PER_S := 120.0
const FLIP_POINTS := 150.0
const PERFECT_SPLASH_POINTS := 100.0
const LOOP_POINTS := 250.0
const GRIND_POINTS_PER_S := 80.0
const CANYON_POINTS := 120.0
const DROP_POINTS := 80.0
const CHAIN_WINDOW := 2.5            # seconds between net cuts that keep a chain alive
const CHAIN_STEP := 0.25             # multiplier added per net in the chain
const CHAIN_MAX_MULT := 3.0
const CHAIN_POINTS := 25.0
const RANKS := [["S", 1800], ["A", 900], ["B", 450], ["C", 150], ["D", 0]]   # style points needed
const STYLE_POINTS_PER_TAG := 40
const STYLE_TAG_CAP := 0.2           # style tags can add at most this share of a dive's normal tags

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

# ---- Sea creatures in the way (see scripts/hazard.gd). They cannot be cut. ----
# How many of each per 600 px slice, by zone. None in the first stretch, so the launch stays calm.
const HAZARD_RATE := {
	"reef": {"puffer": 0.25},
	"city": {"piranha": 0.3, "puffer": 0.25},
	"slope": {"piranha": 0.25, "puffer": 0.15, "ray": 0.2},
	"trench": {"piranha": 0.15, "ray": 0.35},
	"abyss": {"ray": 0.3},
}
const HAZARD_WALL_GAP := 500.0       # px kept clear before a net wall, so the wall hit is about your speed
const PIRANHA_SENSE := 420.0         # px: the school darts at Nova inside this range
const PIRANHA_SPEED := 360.0         # px/s while chasing
const PIRANHA_OUTRUN := 650.0        # Nova faster than this blasts through without a bite
const PIRANHA_OXYGEN := 3.0          # seconds of oxygen a bite costs
const PIRANHA_SLOW := 0.8            # speed kept after a bite
const PUFFER_SENSE := 230.0          # px: it puffs up when Nova is this close
const PUFFER_KEEP := 0.55            # speed kept after bouncing off the spikes
const PUFFER_OXYGEN := 1.5
const RAY_PERIOD := 3.4              # seconds between discharges
const RAY_CHARGE := 0.8              # it glows brighter for this long before a discharge (the warning)
const RAY_DISCHARGE := 0.6           # the field is live for this long
const RAY_FIELD := 150.0             # px radius of the electric field
const RAY_STUN := 0.8                # seconds Nova cannot steer or boost
const RAY_SLOW := 0.7
const RAY_OXYGEN := 2.0
const CLOSE_CALL_POINTS := 60.0      # style points for blasting through a piranha school

# ---- Net walls: the story goals. HP persists between dives. ----
# damage on contact = speed * ballast_mult * cutter_mult
const WALLS := [
	{"at_m": 400, "hp": 1500.0, "bonus": 25, "name": "Reef Gate"},
	{"at_m": 1500, "hp": 3800.0, "bonus": 60, "name": "City Seal"},
	{"at_m": 2800, "hp": 9500.0, "bonus": 110, "name": "Slope Curtain"},
	{"at_m": 3600, "hp": 19000.0, "bonus": 200, "name": "The Lumen's Net"},
]
const WALL_DAMAGE_SCALE := 1.5       # tuning knob: how hard walls are to tear (see tests/economy.gd)
const WALL_SPEED_KEEP := 0.6         # Nova keeps this much speed after tearing through

# ---- Terrain ----
const START_FLOOR := 420.0
const TERRAIN_AHEAD := 4000.0
const TERRAIN_BEHIND := 3000.0

# Zones by distance in metres. "corridor" is floor-to-ceiling height in px.
# Colours drive the whole look: water gradient, rock, accent glow and the zone tint.
const ZONES := [
	{"id": "reef", "dark": 0.0, "name": "Lumen Reef", "start_m": 0, "corridor": 700.0,
		"water_top": Color("1b8fa6"), "water_bottom": Color("0a4d6e"), "rock": Color("0f3a4d"),
		"accent": Color("46f2d0"), "tint": Color("ffffff")},
	{"id": "city", "dark": 0.1, "name": "The Drowned City", "start_m": 400, "corridor": 700.0,
		"water_top": Color("0f5d8c"), "water_bottom": Color("07254a"), "rock": Color("0e2744"),
		"accent": Color("ff5fa8"), "tint": Color("d6e6ff")},
	{"id": "slope", "dark": 0.3, "name": "The Slope", "start_m": 1500, "corridor": 450.0,
		"water_top": Color("0a2f66"), "water_bottom": Color("040f2e"), "rock": Color("0b1a38"),
		"accent": Color("7a8cff"), "tint": Color("b9c8ff")},
	{"id": "trench", "dark": 0.84, "name": "The Trench", "start_m": 2800, "corridor": 520.0,
		"water_top": Color("050d24"), "water_bottom": Color("01040f"), "rock": Color("060d1f"),
		"accent": Color("b66bff"), "tint": Color("8f9bd6")},
	{"id": "abyss", "dark": 0.7, "name": "The Abyss", "start_m": 3600, "corridor": 600.0,
		"water_top": Color("03081a"), "water_bottom": Color("010208"), "rock": Color("050a18"),
		"accent": Color("ffb347"), "tint": Color("a0a0d0")},
]

const TAG_METRES := 40.0             # one tag per this many metres of distance and of depth
const COST_SCALE := 0.5              # multiplies every upgrade price: the main economy knob

# ---- Gear and upgrades ----
# Gear (craft, booster, cutter) are named tiers: owning tier 3 means you carry that item.
# Plain upgrades are levels. Both live in Game.levels as one int per id.
const UPGRADE_ORDER := ["craft", "booster", "cutter", "ramp", "fuel", "o2", "ballast", "pip", "net_return"]
const GEAR_IDS := ["craft", "booster", "cutter"]
const GEAR_NAMES := {
	"craft": ["Kickboard", "Skim Sled", "Hydrofoil", "Manta Wing", "Ray Frame", "Leviathan"],
	"booster": ["Flipper Pump", "Mini Jet", "Twin Jet", "Impeller", "Plasma Drive", "Torpedo Drive"],
	"cutter": ["Wire Snips", "Shears", "Arc Cutter", "Plasma Blade", "Net Shredder", "Reef Saw"],
}
# Cost to buy the NEXT tier / level (index = current level). Tuned with tests/economy.gd.
const UPGRADE_COSTS := {
	"craft": [30, 80, 170, 330, 600],
	"booster": [25, 70, 150, 300, 560],
	"cutter": [20, 60, 140, 280, 520],
	"ramp": [12, 30, 65, 120, 210, 340],
	"fuel": [10, 28, 60, 110, 190],
	"o2": [12, 30, 65, 120, 210, 340],
	"ballast": [20, 55, 120, 240],
	"pip": [30, 90, 220],
	"net_return": [50, 120, 240, 420, 700],
}
# Per-tier stats for the three gear slots (index = tier).
const CRAFT_WING := [1.0, 1.25, 1.55, 1.9, 2.3, 2.8]
const CRAFT_DRAG := [1.0, 0.93, 0.86, 0.78, 0.70, 0.62]
const CRAFT_ENTRY := [1.0, 0.8, 0.6, 0.4, 0.25, 0.1]       # share of the splash speed loss you still take
const CRAFT_LAUNCH := [1.0, 1.05, 1.1, 1.15, 1.2, 1.3]
const BOOSTER_THRUST := [1.0, 1.5, 2.1, 2.8, 3.6, 4.6]
const CUTTER_SLOW := [0.55, 0.65, 0.75, 0.85, 0.92, 0.97]   # speed kept when a net is cut
const CUTTER_WALL := [1.0, 1.3, 1.7, 2.2, 2.8, 3.5]

const UPGRADE_INFO := {
	"craft": {"name": "Craft", "blurb": "Hull and wings. Glide further, lose less speed on entry."},
	"booster": {"name": "Booster", "blurb": "More thrust from the same fuel."},
	"cutter": {"name": "Cutter", "blurb": "Nets slow you less and net walls take more damage."},
	"ramp": {"name": "Launch Ramp", "blurb": "Taller ramp: +10% launch speed a level."},
	"fuel": {"name": "Fuel Tank", "blurb": "+0.8 s of booster fuel a level."},
	"o2": {"name": "Air Tank", "blurb": "+5 s of oxygen a level."},
	"ballast": {"name": "Ballast", "blurb": "Sinks faster, hits walls harder."},
	"pip": {"name": "Pip Magnet", "blurb": "Pulls pickups in. Lv 3: O2 arrow."},
	"net_return": {"name": "Net Return", "blurb": "Port Halo takes its nets back: fewer loose nets in the water."},
}

# The harbourmaster's line for each Net Return level (level 5 and beyond use the last one).
const HARBOUR_LINES := [
	"A new net costs less than an hour of hauling.",
	"Fine. We log every tag you bring up.",
	"There's a return bin on the dock now.",
	"Boats haul their snags back. It costs us an hour.",
	"Every net is tagged and tracked.",
	"Every net that goes down comes back up.",
]
# Loose-net density multiplier for Net Return level 0..5.
const NET_RETURN_FACTORS := [1.0, 0.85, 0.70, 0.55, 0.45, 0.35]


# A taller Launch Ramp upgrade raises the top of the ramp (and pushes it back a little).
func ramp_start(ramp_level: int) -> Vector2:
	var offset := RAMP_START - RAMP_END
	return RAMP_END + Vector2(offset.x * (1.0 + 0.05 * ramp_level), offset.y * (1.0 + 0.12 * ramp_level))


# The ramp is a curve (quadratic Bezier): it slides down, then bends up into a ski jump at the lip.
func ramp_point(ramp_level: int, t: float) -> Vector2:
	var p0 := ramp_start(ramp_level)
	var p1 := RAMP_END - Vector2.RIGHT.rotated(deg_to_rad(LAUNCH_ANGLE_DEG)) * RAMP_CURVE
	return p0.lerp(p1, t).lerp(p1.lerp(RAMP_END, t), t)


# Direction of travel along the ramp at t (0 = top, 1 = lip), as a unit vector.
func ramp_direction(ramp_level: int, t: float) -> Vector2:
	var p0 := ramp_start(ramp_level)
	var p1 := RAMP_END - Vector2.RIGHT.rotated(deg_to_rad(LAUNCH_ANGLE_DEG)) * RAMP_CURVE
	return ((p1 - p0) * 2.0 * (1.0 - t) + (RAMP_END - p1) * 2.0 * t).normalized()


func zone_index_at(x_px: float) -> int:
	var metres := x_px / PX_PER_M
	var index := 0
	for i in ZONES.size():
		if metres >= ZONES[i]["start_m"]:
			index = i
	return index


func zone_id_at(x_px: float) -> String:
	return ZONES[zone_index_at(x_px)]["id"]


# Corridor height at x. Blends between zones over 400 px so the ceiling has no cliff.
func corridor_at(x_px: float) -> float:
	var i := zone_index_at(x_px)
	var here: float = ZONES[i]["corridor"]
	if i + 1 < ZONES.size():
		var next_x: float = ZONES[i + 1]["start_m"] * PX_PER_M
		if x_px > next_x - 400.0:
			return lerpf(here, ZONES[i + 1]["corridor"], (x_px - (next_x - 400.0)) / 400.0)
	return here


# Tags earned by a dive. Same formula the results screen shows line by line.
# Distance and depth count one tag per 40 m, so tags stay scarce.
func tags_for(distance_m: float, depth_m: float, nets_cut: int, animals_freed: int, wall_bonus: int) -> int:
	return int(distance_m / TAG_METRES) + int(depth_m / TAG_METRES) + nets_cut + 3 * animals_freed + wall_bonus


func upgrade_max(id: String) -> int:
	return UPGRADE_COSTS[id].size()


func is_gear(id: String) -> bool:
	return id in GEAR_IDS


# Display name of what you own (gear) or of the upgrade (plain).
func owned_name(id: String, level: int) -> String:
	if is_gear(id):
		return GEAR_NAMES[id][mini(level, GEAR_NAMES[id].size() - 1)]
	return UPGRADE_INFO[id]["name"]


# Cost to buy the NEXT level. Past the cap (endless mode, plain upgrades only) each level costs 1.6x the last.
func upgrade_cost(id: String, current_level: int) -> int:
	var costs: Array = UPGRADE_COSTS[id]
	if current_level < costs.size():
		return maxi(1, int(round(costs[current_level] * COST_SCALE)))
	return int(round(costs[-1] * COST_SCALE * pow(1.6, current_level - costs.size() + 1)))


func net_factor(net_return_level: int) -> float:
	if net_return_level < NET_RETURN_FACTORS.size():
		return NET_RETURN_FACTORS[net_return_level]
	return NET_RETURN_FACTORS[-1] * pow(0.9, net_return_level - NET_RETURN_FACTORS.size() + 1)


# Turns what you own into the multipliers the game uses. One place, easy to explain.
func stats_for(levels: Dictionary) -> Dictionary:
	var craft: int = mini(levels.get("craft", 0), CRAFT_WING.size() - 1)
	var booster: int = mini(levels.get("booster", 0), BOOSTER_THRUST.size() - 1)
	var cutter: int = mini(levels.get("cutter", 0), CUTTER_SLOW.size() - 1)
	var ramp: int = levels.get("ramp", 0)
	var fuel: int = levels.get("fuel", 0)
	var o2: int = levels.get("o2", 0)
	var ballast: int = levels.get("ballast", 0)
	var pip: int = levels.get("pip", 0)
	var net_return: int = levels.get("net_return", 0)
	return {
		"launch_speed": LAUNCH_SPEED * (1.0 + 0.10 * ramp) * CRAFT_LAUNCH[craft],
		"entry_loss_mult": CRAFT_ENTRY[craft],
		"drag_mult": CRAFT_DRAG[craft],
		"wing_mult": CRAFT_WING[craft],
		"thrust_mult": BOOSTER_THRUST[booster],
		"max_fuel": BASE_FUEL + 0.8 * fuel,
		"max_oxygen": BASE_OXYGEN + 5.0 * o2,
		"ballast_mult": 1.0 + 0.15 * ballast,
		"net_slow": CUTTER_SLOW[cutter],
		"cutter_mult": CUTTER_WALL[cutter],
		"magnet_radius": 90.0 * pip,
		"pip_arrow": pip >= 3,
		"net_density": net_factor(net_return),
		"craft_tier": craft, "booster_tier": booster, "cutter_tier": cutter,
		"ramp_level": ramp,
	}
