class_name Net
extends Node2D
# A loose ghost net. It sways, and when Nova touches it, it is cut in two halves
# that drift apart. If an animal is trapped inside, it swims free.

var radius := 70.0
var has_animal := false
var is_cut := false

var _sprite: Sprite2D
var _animal: Sprite2D
var _phase := randf() * TAU
var _age := 0.0


func setup(kind: int, with_animal: bool) -> void:
	var texture: Texture2D = load("res://assets/sprites/net_%d.png" % kind)
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	add_child(_sprite)
	radius = minf(texture.get_width(), texture.get_height()) * 0.38
	has_animal = with_animal
	if with_animal:
		_animal = Sprite2D.new()
		# Big nets hold a turtle, small ones a (dull, trapped-colour) fish.
		if kind == 1 or kind == 2:
			_animal.texture = load("res://assets/sprites/turtle.png")
			_animal.scale = Vector2(0.6, 0.6)
		else:
			_animal.texture = load("res://assets/sprites/fish_3.png")
			_animal.scale = Vector2(1.8, 1.8)
		add_child(_animal)


func _process(delta: float) -> void:
	if is_cut:
		return
	_age += delta
	_sprite.rotation = sin(_age * 0.9 + _phase) * 0.1
	_sprite.scale = Vector2(1.0 + sin(_age * 1.3 + _phase) * 0.03, 1.0 - sin(_age * 1.3 + _phase) * 0.03)
	position.y += sin(_age * 0.5 + _phase) * 5.0 * delta                 # slow drift
	if _animal:
		_animal.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))   # trapped animals shake


func cut_open() -> void:
	is_cut = true
	var texture := _sprite.texture
	var half_w := texture.get_width() / 2.0
	_sprite.visible = false
	for side in [-1, 1]:
		var half := Sprite2D.new()
		half.texture = texture
		half.region_enabled = true
		half.region_rect = Rect2(0 if side < 0 else half_w, 0, half_w, texture.get_height())
		half.position = Vector2(side * half_w / 2.0, 0)
		add_child(half)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(half, "position", half.position + Vector2(side * 90, 60), 0.9)
		tween.tween_property(half, "rotation", side * 0.5, 0.9)
		tween.tween_property(half, "modulate:a", 0.0, 0.9)
	_add_sparks()
	if _animal:
		_free_animal()
	get_tree().create_timer(1.6).timeout.connect(queue_free)


func _add_sparks() -> void:
	var sparks := CPUParticles2D.new()
	sparks.texture = load("res://assets/sprites/spark.png")
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 16
	sparks.lifetime = 0.6
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 120.0
	sparks.initial_velocity_max = 280.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.1
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = additive
	add_child(sparks)


# The animal tweens away with a trail of bubbles.
func _free_animal() -> void:
	var bubbles := CPUParticles2D.new()
	bubbles.texture = load("res://assets/sprites/bubble.png")
	bubbles.amount = 12
	bubbles.lifetime = 0.8
	bubbles.gravity = Vector2(0, -60)
	bubbles.scale_amount_min = 0.3
	bubbles.scale_amount_max = 0.6
	bubbles.initial_velocity_max = 20.0
	_animal.add_child(bubbles)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_animal, "position", Vector2(520, -260), 1.4).set_ease(Tween.EASE_IN)
	tween.tween_property(_animal, "modulate:a", 0.0, 1.4)
