class_name NetWall
extends Node2D
# A story net wall that spans the whole corridor. Its HP persists between dives (Game.wall_hp),
# so a hard hit that does not break it still counts as progress. Once torn it stays torn.

const HALF_WIDTH := 80.0

var index := 0
var hp := 0.0
var hp_max := 0.0
var torn := false
var y_top := 0.0
var y_bottom := 0.0
var _age := 0.0
var _flash := 0.0


func setup(wall_index: int, top: float, bottom: float, already_torn: bool) -> void:
	index = wall_index
	hp_max = Balance.WALLS[index]["hp"]
	hp = Game.wall_remaining(index)
	torn = already_torn or hp <= 0.0
	y_top = top
	y_bottom = bottom


func hit(damage: float) -> void:
	hp = maxf(0.0, hp - damage)
	_flash = 1.0
	if hp <= 0.0:
		torn = true


func _process(delta: float) -> void:
	_age += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var height := y_bottom - y_top
	var mid := (y_top + y_bottom) / 2.0
	var alpha := 0.45 if torn else 0.9
	var color := Color(Art.NET_COLOR, alpha).lerp(Color.WHITE, _flash * 0.7)
	Art.glow(self, Vector2(0, mid), height * 0.7, Color(Art.CYAN if not torn else Art.MAGENTA, 0.10 + 0.1 * _flash))
	var hole := height * 0.55 if torn else 0.0                      # a torn wall has a big gap in the middle
	var y := y_top
	while y <= y_bottom:
		var in_hole := absf(y - mid) < hole / 2.0
		var points := PackedVector2Array()
		for i in 9:
			var x := -HALF_WIDTH + i * HALF_WIDTH / 4.0
			var wave := sin(_age * 1.3 + y * 0.02 + i * 0.6) * 4.0
			points.append(Vector2(x + wave, y + sin(_age + x * 0.05) * 3.0))
		if not in_hole:
			draw_polyline(points, color, 2.0, true)
		y += 34.0
	for i in 9:
		var x := -HALF_WIDTH + i * HALF_WIDTH / 4.0
		var top_part := mid - hole / 2.0
		var from := y_top
		var to := y_bottom
		if torn:
			draw_line(Vector2(x, from), Vector2(x + sin(_age + i) * 6.0, top_part), color, 2.0, true)
			draw_line(Vector2(x, mid + hole / 2.0), Vector2(x - sin(_age + i) * 6.0, to), color, 2.0, true)
		else:
			draw_line(Vector2(x, from), Vector2(x, to), color, 2.0, true)
	for i in int(height / 90.0) + 1:                                  # amber floats down the edges
		var fy := y_top + i * 90.0
		Art.glow(self, Vector2(-HALF_WIDTH, fy), 16.0, Color(Art.AMBER, 0.4))
		draw_circle(Vector2(-HALF_WIDTH, fy), 5.0, Art.AMBER)
		draw_circle(Vector2(HALF_WIDTH, fy + 45.0), 5.0, Art.AMBER)
	if not torn:
		_hp_bar(mid)


func _hp_bar(mid: float) -> void:
	var fraction := hp / hp_max
	var bar := Rect2(-110, mid - 12, 220, 18)
	draw_rect(bar.grow(3), Color(Art.INK, 0.8))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), Art.MAGENTA.lerp(Art.AMBER, 1.0 - fraction))
	draw_rect(bar, Color(1, 1, 1, 0.6), false, 1.5)
	draw_string(Game.font_bold, Vector2(-110, mid - 22), String(Balance.WALLS[index]["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 220, 16, Art.ICE)
