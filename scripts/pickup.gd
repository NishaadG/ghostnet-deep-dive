class_name Pickup
extends Node2D
# Something Nova can fly through: an O2 canister, a fuel cell, or a bit of plastic.

var kind := "o2"          # "o2", "fuel" or "junk"
var radius := 45.0
var collected := false

var _sprite: Sprite2D
var _phase := randf() * TAU
var _age := 0.0


func setup(new_kind: String) -> void:
	kind = new_kind
	_sprite = Sprite2D.new()
	match kind:
		"o2":
			_sprite.texture = load("res://assets/sprites/o2_canister.png")
			_add_glow(Color(0.4, 0.9, 1.0))
		"fuel":
			_sprite.texture = load("res://assets/sprites/fuel_cell.png")
			_add_glow(Color(1.0, 0.7, 0.2))
		_:
			_sprite.texture = load("res://assets/sprites/junk_%d.png" % randi_range(0, 2))
			radius = 36.0
	add_child(_sprite)


# The glow sits behind the sprite so pickups stand out in dark water.
func _add_glow(color: Color) -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/sprites/glow.png")
	glow.modulate = color
	glow.scale = Vector2(0.9, 0.9)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	add_child(glow)


func _process(delta: float) -> void:
	if collected:
		return
	_age += delta
	if kind == "junk":
		_sprite.rotation += 0.6 * delta          # junk spins slowly
	else:
		_sprite.position.y = sin(_age * 2.0 + _phase) * 8.0   # canisters bob


func collect() -> void:
	collected = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.7, 1.7), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)
