class_name StyleScore
extends RefCounted
# The evaluation of a dive: style points for tricks, a rank (D to S), and a small tag bonus.
# Tricks: launch airtime and flips, underwater loops, floor grinds, canyon and drop clears, and net chains.
# A net chain (nets cut within CHAIN_WINDOW of each other) raises a multiplier that boosts later tricks.
# Run feeds events in; the HUD listens to `trick`; the results screen reads summary().

signal trick(label: String, points: int)

var total := 0
var best_chain := 0
var chain := 0
var multiplier := 1.0
var categories := {}          # category -> {"count": n, "points": n}, for the results breakdown
var _chain_timer := 0.0


# Call once per frame: a chain dies when its window runs out.
func update(delta: float) -> void:
	if chain > 0:
		_chain_timer -= delta
		if _chain_timer <= 0.0:
			break_chain()


func break_chain() -> void:
	chain = 0
	multiplier = 1.0
	_chain_timer = 0.0


func chain_fraction() -> float:
	return clampf(_chain_timer / Balance.CHAIN_WINDOW, 0.0, 1.0) if chain > 0 else 0.0


# A net was cut. Cutting another one within the window keeps the chain going.
func net_cut() -> void:
	chain = chain + 1 if _chain_timer > 0.0 else 1
	_chain_timer = Balance.CHAIN_WINDOW
	best_chain = maxi(best_chain, chain)
	multiplier = minf(1.0 + Balance.CHAIN_STEP * (chain - 1), Balance.CHAIN_MAX_MULT)
	if chain >= 2:
		_add("Net chain", "CHAIN x%d" % chain, Balance.CHAIN_POINTS * chain, false)


# Back in the water after being airborne. Flips only count if she came down nose-first.
func landed(air_time: float, flips: int, clean: bool, entry_deg: float) -> void:
	if air_time >= Balance.AIR_MIN_TIME and clean:
		_add("Airtime", "AIRTIME %.1fs" % air_time, Balance.AIR_POINTS_PER_S * air_time)
	if flips > 0 and clean:
		var chain_bonus := 1.0 + 0.5 * (flips - 1)                # each extra flip in one jump is worth more
		_add("Flips", "%d FLIP%s" % [flips, "S" if flips > 1 else ""], Balance.FLIP_POINTS * flips * chain_bonus)
	if clean and entry_deg >= 40.0 and entry_deg <= 70.0 and (flips > 0 or air_time >= Balance.AIR_MIN_TIME):
		_add("Perfect splash", "PERFECT SPLASH", Balance.PERFECT_SPLASH_POINTS)


func looped() -> void:
	_add("Loops", "LOOP", Balance.LOOP_POINTS)


func grind_ended(seconds: float) -> void:
	_add("Grinds", "GRIND %.1fs" % seconds, Balance.GRIND_POINTS_PER_S * seconds)


# Crossed a city canyon or plunged down a drop without touching rock.
func zone_cleared(kind: String, size_px: float) -> void:
	if kind == "canyon":
		_add("Canyon clears", "CANYON CLEAR", Balance.CANYON_POINTS + size_px * 0.05)
	else:
		_add("Drop clears", "DROP CLEAR", Balance.DROP_POINTS + size_px * 0.04)


# Blasted through a piranha school too fast for a bite.
func close_call(label: String) -> void:
	_add("Close calls", label, Balance.CLOSE_CALL_POINTS)


func _add(category: String, label: String, base_points: float, use_multiplier := true) -> void:
	var points := int(round(base_points * (multiplier if use_multiplier else 1.0)))
	total += points
	var entry: Dictionary = categories.get(category, {"count": 0, "points": 0})
	entry["count"] += 1
	entry["points"] += points
	categories[category] = entry
	trick.emit(label if multiplier <= 1.0 or not use_multiplier else "%s  x%.2f" % [label, multiplier], points)


func rank() -> String:
	for entry in Balance.RANKS:
		if total >= int(entry[1]):
			return entry[0]
	return "D"


# Tags for style: points / 40, but never more than a quarter of the dive's normal tags (plus one).
func tag_bonus(base_tags: int) -> int:
	return mini(total / Balance.STYLE_POINTS_PER_TAG, int(ceil(base_tags * Balance.STYLE_TAG_CAP)) + 1)


func summary(base_tags: int) -> Dictionary:
	var lines := []
	for category in categories:
		lines.append([category, categories[category]["count"], categories[category]["points"]])
	return {"total": total, "rank": rank(), "lines": lines, "best_chain": best_chain, "tags": tag_bonus(base_tags)}
