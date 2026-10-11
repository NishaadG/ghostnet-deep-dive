extends Node
# Renders the app icons from icon.svg: Android launcher icons (res://android_icons/) and the
# 512 x 512 Google Play listing icon (store/). Run: godot --headless --path . res://tools/store_icons.tscn

const INK := Color("050b1a")


func _ready() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	_save(_icon(svg, 192, false), "res://android_icons/icon_192.png")             # older launchers
	_save(_icon(svg, 512, true), "res://store/play_icon_512.png")                 # Play listing: full square
	# Adaptive icon: the phone crops the foreground into its own shape, so keep the art in the middle 2/3.
	var foreground := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	var art := _icon(svg, 300, false)
	foreground.blend_rect(art, Rect2i(0, 0, 300, 300), Vector2i(66, 66))
	_save(foreground, "res://android_icons/foreground_432.png")
	var background := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(INK)
	_save(background, "res://android_icons/background_432.png")
	print("icons written")
	get_tree().quit()


# The SVG at `size` px. `square` puts it on a full dark square (no transparent rounded corners).
func _icon(svg: String, size: int, square: bool) -> Image:
	var image := Image.new()
	image.load_svg_from_string(svg, size / 128.0)
	image.convert(Image.FORMAT_RGBA8)
	if not square:
		return image
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	out.fill(INK)
	out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return out


func _save(image: Image, path: String) -> void:
	image.save_png(ProjectSettings.globalize_path(path))
