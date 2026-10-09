class_name ShopRows
extends RefCounted
# Builders for the workshop's tab contents: gear rows, tuning rows and the Port Halo panel.
# Each builder adds controls to `parent` and calls `on_buy` after a purchase.

const REGION := Rect2(424, 150, 832, 420)


# ---- Gear: three slots with tier ladders ----

static func gear_tab(parent: Control, on_buy: Callable) -> void:
	for i in Balance.GEAR_IDS.size():
		_gear_row(parent, Balance.GEAR_IDS[i], Vector2(REGION.position.x, REGION.position.y + i * 138.0), on_buy)


static func _gear_row(parent: Control, id: String, pos: Vector2, on_buy: Callable) -> void:
	var tier := Game.level(id)
	var top := Balance.upgrade_max(id)
	var accent: Color = {"craft": Art.CYAN, "booster": Art.AMBER, "cutter": Art.MAGENTA}[id]
	parent.add_child(UiKit.panel(pos, Vector2(REGION.size.x, 128), accent, 0.62))
	var icon := Control.new()                                   # the owned tier, drawn by the same code as in a dive
	icon.position = pos + Vector2(14, 14)
	icon.size = Vector2(110, 100)
	icon.draw.connect(func():
		Art.glow(icon, Vector2(55, 50), 70.0, Color(accent, 0.18))
		GearArt.draw_icon(icon, id, tier, Vector2(55, 50), 92.0, 0.0))
	parent.add_child(icon)
	var slot_label := UiKit.label(id.to_upper(), 12, true, accent)
	slot_label.position = pos + Vector2(138, 12)
	parent.add_child(slot_label)
	var name_label := UiKit.label(Balance.GEAR_NAMES[id][tier], 26, true)
	name_label.position = pos + Vector2(138, 26)
	parent.add_child(name_label)
	_ladder(parent, pos + Vector2(146, 92), top + 1, tier, accent)
	if tier >= top:
		var maxed := UiKit.label("TOP TIER", 20, true, accent)
		maxed.position = pos + Vector2(600, 48)
		parent.add_child(maxed)
		return
	var next_label := UiKit.label("NEXT: %s" % Balance.GEAR_NAMES[id][tier + 1], 19, true, Art.ICE)
	next_label.position = pos + Vector2(470, 14)
	parent.add_child(next_label)
	var delta := UiKit.label(gear_delta(id, tier), 13, false, Color(Art.ICE, 0.8))
	delta.position = pos + Vector2(470, 40)
	parent.add_child(delta)
	_buy_block(parent, id, pos + Vector2(470, 88), accent, on_buy)


# A ladder of nodes: owned tiers filled, the next one ringed, the rest dim.
static func _ladder(parent: Control, pos: Vector2, count: int, owned: int, accent: Color) -> void:
	var ladder := Control.new()
	ladder.position = pos
	ladder.size = Vector2(count * 52, 30)
	ladder.draw.connect(func():
		for i in count:
			var c := Vector2(i * 52.0 + 12.0, 12.0)
			if i > 0:
				ladder.draw_line(c + Vector2(-40, 0), c + Vector2(-12, 0), Color(accent, 0.8 if i <= owned else 0.2), 3.0, true)
			if i <= owned:
				Art.glow(ladder, c, 22.0, Color(accent, 0.35))
				ladder.draw_circle(c, 9.0, accent)
			elif i == owned + 1:
				ladder.draw_arc(c, 9.0, 0.0, TAU, 20, accent, 2.5, true)
			else:
				ladder.draw_arc(c, 7.0, 0.0, TAU, 16, Color(1, 1, 1, 0.25), 2.0, true))
	parent.add_child(ladder)


static func _buy_block(parent: Control, id: String, pos: Vector2, accent: Color, on_buy: Callable) -> void:
	var cost := Balance.upgrade_cost(id, Game.level(id))
	var tag := Control.new()
	tag.position = pos
	tag.size = Vector2(130, 36)
	tag.draw.connect(func():
		tag.draw_colored_polygon(PackedVector2Array([Vector2(0, 8), Vector2(16, 8), Vector2(24, 18), Vector2(16, 28), Vector2(0, 28)]), Art.AMBER)
		tag.draw_circle(Vector2(16, 18), 2.5, Art.INK))
	parent.add_child(tag)
	var cost_label := UiKit.label(str(cost), 24, true, Art.AMBER if Game.tags >= cost else Color("ff6a6a"))
	cost_label.position = pos + Vector2(32, 0)
	parent.add_child(cost_label)
	var button := UiKit.button("BUY", Vector2(150, 40), accent, true, 20)
	button.position = pos + Vector2(120, -2)
	button.disabled = not Game.can_buy(id)
	button.pressed.connect(func():
		if Game.buy(id):
			Audio.play("buy")
			on_buy.call())
	parent.add_child(button)


# What the next tier changes, in plain numbers.
static func gear_delta(id: String, tier: int) -> String:
	var n := tier + 1
	match id:
		"craft":
			return "Wing turn %+d%%    Drag %+d%%\nSplash loss %+d%%    Launch %+d%%" % [
				_pct(Balance.CRAFT_WING[n], Balance.CRAFT_WING[tier]), _pct(Balance.CRAFT_DRAG[n], Balance.CRAFT_DRAG[tier]),
				_pct(Balance.CRAFT_ENTRY[n], Balance.CRAFT_ENTRY[tier]), _pct(Balance.CRAFT_LAUNCH[n], Balance.CRAFT_LAUNCH[tier])]
		"booster":
			return "Thrust %+d%%  (%.1fx the pump)" % [_pct(Balance.BOOSTER_THRUST[n], Balance.BOOSTER_THRUST[tier]), Balance.BOOSTER_THRUST[n]]
		_:
			return "Nets keep %d%% of your speed (now %d%%)\nWall damage %+d%%" % [
				int(Balance.CUTTER_SLOW[n] * 100), int(Balance.CUTTER_SLOW[tier] * 100), _pct(Balance.CUTTER_WALL[n], Balance.CUTTER_WALL[tier])]


static func _pct(next_value: float, current: float) -> int:
	return int(round((next_value / current - 1.0) * 100.0))


# ---- Tuning: plain levelled upgrades ----

static func tuning_tab(parent: Control, on_buy: Callable) -> void:
	var ids := ["ramp", "fuel", "o2", "ballast", "pip"]
	for i in ids.size():
		_tuning_row(parent, ids[i], Vector2(REGION.position.x, REGION.position.y + i * 84.0), on_buy)


static func _tuning_row(parent: Control, id: String, pos: Vector2, on_buy: Callable) -> void:
	var level := Game.level(id)
	var total := Balance.upgrade_max(id)
	parent.add_child(UiKit.panel(pos, Vector2(REGION.size.x, 76), Art.CYAN, 0.6))
	var name_label := UiKit.label(Balance.UPGRADE_INFO[id]["name"], 22, true)
	name_label.position = pos + Vector2(20, 8)
	parent.add_child(name_label)
	var blurb := UiKit.label(Balance.UPGRADE_INFO[id]["blurb"], 13, false, Color(Art.ICE, 0.7))
	blurb.position = pos + Vector2(20, 42)
	parent.add_child(blurb)
	var pips := Control.new()
	pips.position = pos + Vector2(400, 12)
	pips.size = Vector2(200, 24)
	pips.draw.connect(func():
		if level > total:
			pips.draw_string(Game.font_bold, Vector2(0, 18), "Level %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Art.AMBER)
			return
		for i in total:
			var c := Vector2(i * 22.0 + 10.0, 12.0)
			if i < level:
				pips.draw_circle(c, 8.0, Art.CYAN)
			else:
				pips.draw_arc(c, 7.0, 0.0, TAU, 16, Color(1, 1, 1, 0.3), 2.0, true))
	parent.add_child(pips)
	var effect := UiKit.label(tuning_now(id, level), 15, true, Art.CYAN)
	effect.position = pos + Vector2(400, 40)
	parent.add_child(effect)
	var capped := level >= total and (not Game.story_complete)
	if capped:
		var done := UiKit.label("MAX", 22, true, Art.CYAN)
		done.position = pos + Vector2(690, 22)
		parent.add_child(done)
	else:
		_buy_block(parent, id, pos + Vector2(560, 20), Art.CYAN, on_buy)


static func tuning_now(id: String, level: int) -> String:
	var stats := Balance.stats_for({id: level})
	match id:
		"ramp":
			return "Launch +%d%%" % int(level * 10)
		"fuel":
			return "%.1f s boost fuel" % stats["max_fuel"]
		"o2":
			return "%d s of oxygen" % int(stats["max_oxygen"])
		"ballast":
			return "Weight x%.2f" % stats["ballast_mult"]
		_:
			return "Magnet %d px%s" % [int(stats["magnet_radius"]), "  +  O2 arrow" if level >= 3 else ""]


# ---- Port Halo: the Net Return programme ----

static func port_halo_tab(parent: Control, on_buy: Callable) -> void:
	var level := Game.level("net_return")
	var total := Balance.upgrade_max("net_return")
	var pos := REGION.position
	parent.add_child(UiKit.panel(pos, Vector2(REGION.size.x, 420), Art.AMBER, 0.62))
	var heading := UiKit.label("PORT HALO PROGRAMME", 14, true, Art.AMBER)
	heading.position = pos + Vector2(28, 18)
	parent.add_child(heading)
	var title := UiKit.label("Net Return", 40, true)
	title.position = pos + Vector2(28, 38)
	parent.add_child(title)
	var quote := UiKit.label("\"%s\"" % Balance.HARBOUR_LINES[mini(level, Balance.HARBOUR_LINES.size() - 1)], 22, false, Art.ICE)
	quote.position = pos + Vector2(28, 100)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.size = Vector2(770, 70)
	parent.add_child(quote)
	var who := UiKit.label("The harbourmaster", 14, false, Color(Art.ICE, 0.55))
	who.position = pos + Vector2(28, 150)
	parent.add_child(who)
	_ladder(parent, pos + Vector2(40, 200), total + 1, level, Art.AMBER)
	var now := UiKit.label("Loose nets in the water now: x%.2f" % Balance.net_factor(level), 24, true, Art.AMBER)
	now.position = pos + Vector2(28, 250)
	parent.add_child(now)
	if level < total or Game.story_complete:
		var next := UiKit.label("Next level: x%.2f" % Balance.net_factor(level + 1), 18, false, Art.ICE)
		next.position = pos + Vector2(28, 292)
		parent.add_child(next)
		_buy_block(parent, "net_return", pos + Vector2(560, 290), Art.AMBER, on_buy)
	var message := UiKit.label("Cleaning up helps one animal at a time. Net Return ends the problem at its source: it permanently removes loose nets from the water.", 15, false, Color(Art.ICE, 0.75))
	message.position = pos + Vector2(28, 350)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size = Vector2(770, 56)
	parent.add_child(message)
