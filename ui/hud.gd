class_name Hud
extends Control
# In-run readout, drawn by hand in glass panels: an oxygen ring, a segmented boost gauge,
# distance and depth, tags, a journey strip with the four net walls, plus zone banners and captions.

var run: Run
var _glass := UiKit.glass(Art.CYAN, 0.55)
var _banner_text := ""
var _banner_sub := ""
var _banner_t := 0.0
var _caption_text := ""
var _caption_t := 0.0
var _towing_reason := ""
var _radio_who := ""
var _radio_text := ""
var _radio_t := 0.0
var _radio_queued := []           # one waiting line [who, text], so a new line never cuts one off mid-sentence
const RADIO_TIME := 6.0
const RADIO_MIN := 3.0            # a line stays at least this long before the next replaces it


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_banner(text: String, sub: String) -> void:
	_banner_text = text
	_banner_sub = sub
	_banner_t = 3.0


func show_caption(text: String, seconds: float) -> void:
	_caption_text = text
	_caption_t = seconds


# A radio line from Pip, Nova or Captain Vale (see Story). It types out, stays, then fades.
func show_radio(who: String, text: String) -> void:
	if _radio_t > RADIO_TIME - RADIO_MIN:
		_radio_queued = [who, text]
		return
	_radio_who = who
	_radio_text = text
	_radio_t = RADIO_TIME


func show_towing(reason: String) -> void:
	_towing_reason = reason


func _process(delta: float) -> void:
	_banner_t = maxf(0.0, _banner_t - delta)
	_caption_t = maxf(0.0, _caption_t - delta)
	_radio_t = maxf(0.0, _radio_t - delta)
	if not _radio_queued.is_empty() and _radio_t <= RADIO_TIME - RADIO_MIN:
		var next: Array = _radio_queued
		_radio_queued = []
		show_radio(next[0], next[1])
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var player := run.player
	var oxygen_fraction: float = clampf(player.oxygen / run.stats["max_oxygen"], 0.0, 1.0)
	_speed_lines(player.vel.length())
	_danger_edges(oxygen_fraction)
	_oxygen_panel(player, oxygen_fraction)
	_distance_panel(player)
	_tags_chip()
	_journey_strip(maxf(0.0, player.position.x / Balance.PX_PER_M))
	_banner()
	_caption()
	_radio()
	if _towing_reason != "":
		_towing()


# ---- Panels ----

func _oxygen_panel(player: Player, fraction: float) -> void:
	draw_style_box(_glass, Rect2(20, 18, 330, 96))
	var centre := Vector2(70, 66)
	var color := Art.CYAN
	if fraction < 0.15:
		color = Color("ff4a4a").lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
	elif fraction < 0.35:
		color = Art.AMBER
	draw_arc(centre, 32.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 7.0, true)
	draw_arc(centre, 32.0, -PI / 2.0, -PI / 2.0 + TAU * fraction, 40, color, 7.0, true)
	Art.glow(self, centre, 54.0, Color(color, 0.18))
	draw_string(Game.font_bold, centre + Vector2(-30, 8), "%d" % ceili(player.oxygen), HORIZONTAL_ALIGNMENT_CENTER, 60, 24, Art.ICE)
	draw_string(Game.font, Vector2(116, 46), "OXYGEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Art.ICE, 0.7))
	draw_string(Game.font_bold, Vector2(116, 68), "%.1f s" % player.oxygen, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
	# Boost gauge: twelve segments that empty as fuel burns.
	var fuel_fraction: float = clampf(player.fuel / run.stats["max_fuel"], 0.0, 1.0)
	draw_string(Game.font, Vector2(116, 94), "BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Art.ICE, 0.7))
	for i in 12:
		var on := (i + 0.5) / 12.0 <= fuel_fraction
		var seg := Rect2(172 + i * 14, 83, 10, 12)
		draw_rect(seg, Color(Art.AMBER, 0.95) if on else Color(1, 1, 1, 0.12))
		if on and player.thrusting:
			Art.glow(self, seg.get_center(), 12.0, Color(Art.AMBER, 0.3))


func _distance_panel(player: Player) -> void:
	draw_style_box(_glass, Rect2(930, 18, 330, 102))
	var metres := maxf(0.0, player.position.x / Balance.PX_PER_M)
	draw_string(Game.font_bold, Vector2(946, 80), "%d m" % metres, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Art.ICE)
	draw_string(Game.font, Vector2(948, 106), "depth %d m     %d px/s" % [maxf(0.0, player.position.y / Balance.PX_PER_M), player.vel.length()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Art.ICE, 0.75))
	var zone: String = Balance.ZONES[Balance.zone_index_at(player.position.x)]["name"]
	draw_string(Game.font, Vector2(946, 36), zone.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Art.CYAN, 0.9))


func _tags_chip() -> void:
	draw_style_box(UiKit.glass(Art.AMBER, 0.55, 22), Rect2(560, 18, 160, 44))
	_tag_icon(Vector2(590, 40), 1.0)
	draw_string(Game.font_bold, Vector2(614, 49), "%d" % run.tags_so_far(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Art.AMBER)


# The fleet tag: a small amber tag shape with a hole.
func _tag_icon(centre: Vector2, s: float) -> void:
	var pts := PackedVector2Array([Vector2(-12, -8), Vector2(6, -8), Vector2(14, 0), Vector2(6, 8), Vector2(-12, 8)])
	for i in pts.size():
		pts[i] = centre + pts[i] * s
	draw_colored_polygon(pts, Art.AMBER)
	draw_circle(centre + Vector2(6, 0) * s, 2.5 * s, Art.INK)


# Journey strip: 0 m to the last wall with a marker per net wall; broken walls are filled.
func _journey_strip(metres: float) -> void:
	if Game.endless_mode:
		draw_string(Game.font, Vector2(340, 700), "ENDLESS   best %d m" % Game.best_distance, HORIZONTAL_ALIGNMENT_CENTER, 600, 14, Color(Art.ICE, 0.8))
		return
	var strip := Rect2(340, 690, 600, 5)
	var last: float = Balance.WALLS[-1]["at_m"]
	draw_rect(strip, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(metres / last, 0.0, 1.0), 5)), Color(Art.CYAN, 0.9))
	for i in Balance.WALLS.size():
		var x: float = strip.position.x + strip.size.x * float(Balance.WALLS[i]["at_m"]) / last
		var broken := Game.wall_broken(i)
		draw_circle(Vector2(x, strip.position.y + 2.5), 7.0, Art.AMBER if broken else Art.INK)
		draw_arc(Vector2(x, strip.position.y + 2.5), 7.0, 0.0, TAU, 14, Art.AMBER if broken else Art.MAGENTA, 2.0, true)
	var next := Game.next_wall()
	if next >= 0:
		var label := "%s  %d m" % [Balance.WALLS[next]["name"], Balance.WALLS[next]["at_m"]]
		var left: float = Game.wall_remaining(next) / float(Balance.WALLS[next]["hp"])
		if left < 1.0:
			label += "   (%d%% left)" % int(left * 100.0)
		draw_string(Game.font, Vector2(340, 680), label, HORIZONTAL_ALIGNMENT_CENTER, 600, 14, Color(Art.ICE, 0.85))


# ---- Overlays ----

func _banner() -> void:
	if _banner_t <= 0.0:
		return
	var a := clampf(minf(_banner_t, 3.0 - _banner_t) * 2.0, 0.0, 1.0)
	draw_string(Game.font_bold, Vector2(240, 250), _banner_text.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 800, 46, Color(Art.ICE, a))
	draw_string(Game.font, Vector2(240, 282), _banner_sub, HORIZONTAL_ALIGNMENT_CENTER, 800, 18, Color(Art.CYAN, a))
	draw_line(Vector2(540, 296), Vector2(740, 296), Color(Art.CYAN, a * 0.8), 2.0, true)


func _caption() -> void:
	if _caption_t <= 0.0:
		return
	var a := clampf(_caption_t * 2.0, 0.0, 1.0)
	var rect := Rect2(290, 560, 700, 60)
	draw_style_box(UiKit.glass(Art.AMBER, 0.7 * a), rect)
	draw_string(Game.font_bold, rect.position + Vector2(0, 38), _caption_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, Color(Art.ICE, a))


func _radio() -> void:
	if _radio_t <= 0.0 or _towing_reason != "":
		return
	var a := clampf(minf(_radio_t, RADIO_TIME - _radio_t) * 4.0, 0.0, 1.0)
	var speaker: Dictionary = Story.SPEAKERS.get(_radio_who, Story.SPEAKERS["pip"])
	var color: Color = speaker["color"]
	var rect := Rect2(20, 126, 470, 82)
	draw_style_box(UiKit.glass(color, 0.7 * a), rect)
	draw_circle(rect.position + Vector2(18, 20), 4.0 + sin(Time.get_ticks_msec() / 120.0), Color(color, a))   # "on air" light
	draw_string(Game.font_bold, rect.position + Vector2(30, 26), String(speaker["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, a))
	var shown := int((RADIO_TIME - _radio_t) * 45.0)
	draw_multiline_string(Game.font, rect.position + Vector2(14, 50), _radio_text.substr(0, shown), HORIZONTAL_ALIGNMENT_LEFT, 444, 16, 2, Color(Art.ICE, a))


func _towing() -> void:
	var reasons := {"oxygen": "Out of oxygen", "crash": "Hit the seabed too hard", "rest": "Came to rest on the seabed",
			"wall": "A net wall stopped you", "lumen": "The Lumen is free"}
	var rect := Rect2(340, 320, 600, 90)
	draw_style_box(UiKit.glass(Art.CYAN, 0.8), rect)
	draw_string(Game.font_bold, rect.position + Vector2(0, 38), String(reasons.get(_towing_reason, "")), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 26, Art.ICE)
	draw_string(Game.font, rect.position + Vector2(0, 68), "Pip is towing you up...", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color(Art.CYAN, 0.9))


# Streaks racing out from the centre when fast.
func _speed_lines(speed: float) -> void:
	if speed < 800.0:
		return
	var strength := clampf((speed - 800.0) / 500.0, 0.0, 1.0)
	var centre := Vector2(640, 360)
	for i in 22:
		var angle := Art.hash01(i) * TAU
		var phase := fposmod(Time.get_ticks_msec() / 400.0 + Art.hash01(i + 40), 1.0)
		var from := centre + Vector2(1, 0).rotated(angle) * (420.0 + phase * 300.0)
		var to := from + Vector2(1, 0).rotated(angle) * (50.0 + 90.0 * strength)
		draw_line(from, to, Color(Art.ICE, 0.35 * strength), 2.0, true)


# A red pulse along the top and bottom edges when oxygen is critical.
func _danger_edges(fraction: float) -> void:
	if fraction >= 0.15:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	var c := Color(1, 0.1, 0.1, 0.22 * pulse)
	var clear := Color(1, 0.1, 0.1, 0.0)
	draw_primitive(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 120), Vector2(0, 120)]), PackedColorArray([c, c, clear, clear]), PackedVector2Array())
	draw_primitive(PackedVector2Array([Vector2(0, 720), Vector2(1280, 720), Vector2(1280, 600), Vector2(0, 600)]), PackedColorArray([c, c, clear, clear]), PackedVector2Array())
