extends Node
## Procedural asset factory. Every texture, tileset, icon and UI theme in the
## project is generated here at runtime - the repository ships zero binaries.

enum Tile { GRASS, DIRT, ROAD, SNOW, CONCRETE, GRAVEL, WOOD, MUD, WATER, ASPHALT, SPORE }

const TILE_SIZE := Vector2i(64, 32)
const TILE_COUNT := 11

var _tileset: TileSet
var _tex: Dictionary = {}
var _theme: Theme


# ---------- textures ----------

func _img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


func _circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x - cx, y - cy).length() <= r:
				img.set_pixel(x, y, c)


func _diamond(img: Image, cx: float, cy: float, hw: float, hh: float, c: Color) -> void:
	for y in range(int(cy - hh), int(cy + hh) + 1):
		for x in range(int(cx - hw), int(cx + hw) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if absf(x - cx) / hw + absf(y - cy) / hh <= 1.0:
				img.set_pixel(x, y, c)


func _noise(x: int, y: int, seed_v: float) -> float:
	var v := sin(float(x) * 12.9898 + float(y) * 78.233 + seed_v) * 43758.5453
	return absf(v - floorf(v))


# ---------- tileset ----------

func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var atlas := _img(TILE_SIZE.x * TILE_COUNT, TILE_SIZE.y)
	for i in range(TILE_COUNT):
		_draw_tile(atlas, i)
	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas)
	src.texture_region_size = TILE_SIZE
	for i in range(TILE_COUNT):
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	_tileset = ts
	return ts


func _draw_tile(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE.x
	var base := Color(0.2, 0.24, 0.2)
	match index:
		Tile.DIRT: base = Color(0.28, 0.22, 0.17)
		Tile.ROAD: base = Color(0.17, 0.17, 0.2)
		Tile.SNOW: base = Color(0.72, 0.77, 0.8)
		Tile.CONCRETE: base = Color(0.3, 0.3, 0.31)
		Tile.GRAVEL: base = Color(0.34, 0.32, 0.29)
		Tile.WOOD: base = Color(0.42, 0.29, 0.18)
		Tile.MUD: base = Color(0.23, 0.19, 0.16)
		Tile.WATER: base = Color(0.11, 0.22, 0.28)
		Tile.ASPHALT: base = Color(0.13, 0.13, 0.15)
		Tile.SPORE: base = Color(0.24, 0.28, 0.16)
	for y in range(TILE_SIZE.y):
		for x in range(TILE_SIZE.x):
			if absf(x - 31.5) / 32.0 + absf(y - 15.5) / 16.0 > 1.0:
				continue
			var n := _noise(ox + x, y, 3.7)
			var shade := 0.9 + n * 0.2
			var c := Color(base.r * shade, base.g * shade, base.b * shade)
			if y < 12 and x > 20 and x < 44:
				c = c.lightened(0.06)
			img.set_pixel(ox + x, y, c)
	# edge lines for readability
	for i in range(32):
		var x1 := int(31.5 + i)
		var x2 := int(31.5 - i)
		var y1 := i / 2
		var y2 := 31 - i / 2
		if x1 < 64:
			img.set_pixel(ox + x1, y1, base.darkened(0.35))
			img.set_pixel(ox + x1, y2, base.darkened(0.35))
		if x2 >= 0:
			img.set_pixel(ox + x2, y1, base.darkened(0.35))
			img.set_pixel(ox + x2, y2, base.darkened(0.35))


# ---------- entity sprites ----------

func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var img := _img(64, 80)
	match kind:
		"player": _draw_survivor(img, Color(0.32, 0.42, 0.5), Color(0.85, 0.78, 0.66))
		"player_ranger": _draw_survivor(img, Color(0.24, 0.38, 0.26), Color(0.85, 0.78, 0.66))
		"player_paramedic": _draw_survivor(img, Color(0.55, 0.25, 0.24), Color(0.9, 0.84, 0.74))
		"player_carpenter": _draw_survivor(img, Color(0.5, 0.38, 0.2), Color(0.85, 0.75, 0.62))
		"player_machinist": _draw_survivor(img, Color(0.28, 0.32, 0.38), Color(0.86, 0.78, 0.66))
		"shambler": _draw_blighted(img, Color(0.35, 0.42, 0.3), Color(0.85, 0.35, 0.25))
		"sprinter": _draw_blighted(img, Color(0.45, 0.35, 0.45), Color(1.0, 0.55, 0.2))
		"hulk": _draw_blighted(img, Color(0.3, 0.34, 0.24), Color(0.9, 0.2, 0.2))
		"npc": _draw_survivor(img, Color(0.4, 0.34, 0.42), Color(0.85, 0.78, 0.66))
		"wall": _draw_wall(img)
		"pine": _draw_pine(img)
		"container": _draw_container(img, Color(0.42, 0.32, 0.2))
		"door": _draw_container(img, Color(0.32, 0.24, 0.16))
		"generator": _draw_machine(img, Color(0.5, 0.45, 0.2))
		"relay": _draw_machine(img, Color(0.5, 0.25, 0.2))
		"campfire": _draw_campfire(img)
		"barricade": _draw_wall(img)
		"mycelium": _draw_mycelium(img)
		"crate": _draw_container(img, Color(0.35, 0.36, 0.3))
		_: _draw_container(img, Color(0.4, 0.4, 0.4))
	var tex := ImageTexture.create_from_image(img)
	_tex[kind] = tex
	return tex


func _draw_survivor(img: Image, coat: Color, skin: Color) -> void:
	_diamond(img, 32, 70, 18, 8, Color(0, 0, 0, 0.35))
	_rect(img, 24, 32, 16, 28, coat)
	_rect(img, 24, 32, 16, 4, coat.lightened(0.15))
	_circle(img, 32, 26, 8, skin)
	_rect(img, 24, 22, 16, 6, coat.darkened(0.25))
	_rect(img, 20, 38, 5, 16, coat.darkened(0.2))
	_rect(img, 39, 38, 5, 16, coat.darkened(0.2))
	_rect(img, 26, 58, 6, 12, Color(0.16, 0.16, 0.18))
	_rect(img, 33, 58, 6, 12, Color(0.16, 0.16, 0.18))


func _draw_blighted(img: Image, body: Color, eye: Color) -> void:
	_diamond(img, 32, 70, 20, 9, Color(0, 0, 0, 0.35))
	_rect(img, 22, 30, 20, 30, body)
	_rect(img, 22, 30, 20, 4, body.lightened(0.12))
	_circle(img, 32, 24, 9, body.darkened(0.15))
	_circle(img, 28, 23, 2.4, eye)
	_circle(img, 36, 23, 2.4, eye)
	_rect(img, 16, 34, 6, 18, body.darkened(0.25))
	_rect(img, 42, 34, 6, 18, body.darkened(0.25))
	_rect(img, 24, 58, 7, 12, body.darkened(0.3))
	_rect(img, 33, 58, 7, 12, body.darkened(0.3))
	for i in range(6):
		_circle(img, 26 + i * 3, 40 + (i % 2) * 6, 2.0, body.lightened(0.25))


func _draw_wall(img: Image) -> void:
	_rect(img, 8, 24, 48, 30, Color(0.36, 0.34, 0.31))
	_rect(img, 8, 24, 48, 6, Color(0.48, 0.46, 0.42))
	for y in range(30, 54, 6):
		_rect(img, 8, y, 48, 1, Color(0.28, 0.26, 0.24))
	_rect(img, 8, 54, 48, 4, Color(0.22, 0.2, 0.19))


func _draw_pine(img: Image) -> void:
	_rect(img, 29, 52, 6, 18, Color(0.26, 0.19, 0.13))
	for i in range(4):
		var w := 40 - i * 8
		_rect(img, 32 - w / 2, 12 + i * 11, w, 12, Color(0.13, 0.24, 0.17).lightened(i * 0.04))
	_diamond(img, 32, 72, 16, 7, Color(0, 0, 0, 0.3))


func _draw_container(img: Image, body: Color) -> void:
	_diamond(img, 32, 66, 20, 9, Color(0, 0, 0, 0.3))
	_rect(img, 16, 32, 32, 28, body)
	_rect(img, 16, 32, 32, 5, body.lightened(0.18))
	_rect(img, 16, 44, 32, 3, body.darkened(0.3))
	_rect(img, 28, 40, 8, 10, body.darkened(0.45))


func _draw_machine(img: Image, body: Color) -> void:
	_diamond(img, 32, 68, 22, 10, Color(0, 0, 0, 0.32))
	_rect(img, 14, 28, 36, 34, body.darkened(0.2))
	_rect(img, 14, 28, 36, 6, body)
	_circle(img, 24, 42, 5, body.lightened(0.35))
	_rect(img, 34, 38, 12, 12, body.darkened(0.35))
	for i in range(3):
		_rect(img, 18 + i * 10, 54, 6, 4, body.lightened(0.2))


func _draw_campfire(img: Image) -> void:
	_diamond(img, 32, 66, 18, 8, Color(0, 0, 0, 0.3))
	for i in range(4):
		_rect(img, 18 + i * 8, 56, 6, 6, Color(0.32, 0.22, 0.15))
	_circle(img, 32, 50, 9, Color(0.95, 0.55, 0.2))
	_circle(img, 32, 48, 5, Color(1.0, 0.85, 0.4))


func _draw_mycelium(img: Image) -> void:
	_diamond(img, 32, 66, 22, 10, Color(0, 0, 0, 0.32))
	for i in range(5):
		_circle(img, 20 + i * 6, 52 - (i % 2) * 8, 6, Color(0.68, 0.82, 0.5).lightened(0.05 * i))
	_circle(img, 32, 44, 7, Color(0.85, 0.95, 0.6))


# ---------- item icons ----------

func item_icon(def: Variant) -> Texture2D:
	var key := "icon_" + String(def.id)
	if _tex.has(key):
		return _tex[key]
	var img := _img(32, 32)
	var c: Color = def.icon_color
	match int(def.type):
		ItemDef.ItemType.WEAPON_MELEE:
			_rect(img, 6, 14, 20, 4, c)
			_rect(img, 22, 10, 5, 12, c.darkened(0.3))
		ItemDef.ItemType.WEAPON_RANGED:
			_rect(img, 5, 13, 22, 5, c)
			_rect(img, 12, 18, 6, 8, c.darkened(0.3))
		ItemDef.ItemType.AMMO:
			for i in range(3):
				_rect(img, 7 + i * 7, 12, 4, 11, c)
		ItemDef.ItemType.MEDICAL:
			_rect(img, 13, 6, 6, 20, c)
			_rect(img, 6, 13, 20, 6, c)
		ItemDef.ItemType.FOOD, ItemDef.ItemType.DRINK:
			_rect(img, 10, 9, 12, 17, c)
			_rect(img, 10, 9, 12, 3, c.lightened(0.25))
		ItemDef.ItemType.LIGHT:
			_circle(img, 16, 16, 8, c)
			_circle(img, 16, 16, 4, Color(1, 1, 0.75))
		_:
			_diamond(img, 16, 16, 12, 8, c)
			_rect(img, 12, 12, 8, 8, c.lightened(0.2))
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


# ---------- UI theme ----------

func ui_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.11, 0.12, 0.94)
	panel.border_color = Color(0.35, 0.45, 0.4)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 14.0
	panel.content_margin_right = 14.0
	panel.content_margin_top = 12.0
	panel.content_margin_bottom = 12.0
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.16, 0.2, 0.21, 0.96)
	btn.border_color = Color(0.4, 0.55, 0.45)
	btn.set_border_width_all(2)
	btn.set_corner_radius_all(10)
	btn.content_margin_left = 18.0
	btn.content_margin_right = 18.0
	btn.content_margin_top = 12.0
	btn.content_margin_bottom = 12.0
	t.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = Color(0.22, 0.3, 0.27, 0.98)
	t.set_stylebox("hover", "Button", btn_hover)
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = Color(0.3, 0.45, 0.35, 1.0)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_color("font_color", "Button", Color(0.92, 0.95, 0.92))
	t.set_color("font_color", "Label", Color(0.9, 0.93, 0.9))
	t.set_color("font_color", "RichTextLabel", Color(0.9, 0.93, 0.9))
	_theme = t
	return t


# ---------- audio synthesis (original PCM, no audio files) ----------

var _sfx_cache: Dictionary = {}


func sfx(sound_name: String) -> AudioStreamWAV:
	if _sfx_cache.has(sound_name):
		return _sfx_cache[sound_name]
	var rate := 22050
	var data := PackedByteArray()
	var loop := false
	match sound_name:
		"step": data = _tone(rate, 0.12, 170.0, 0.22, true)
		"swing": data = _sweep(rate, 0.18, 950.0, 150.0, 0.28)
		"hit": data = _noise_burst(rate, 0.12, 0.5)
		"gun": data = _noise_burst(rate, 0.25, 0.85)
		"hurt": data = _tone(rate, 0.2, 210.0, 0.32, true)
		"pickup": data = _tone(rate, 0.1, 680.0, 0.24, false)
		"click", "ui": data = _tone(rate, 0.06, 820.0, 0.2, false)
		"zombie": data = _tone(rate, 0.55, 105.0, 0.35, true)
		"generator":
			data = _tone(rate, 1.2, 62.0, 0.3, true)
			loop = true
		"beacon": data = _tone(rate, 1.4, 440.0, 0.28, false)
		"door": data = _tone(rate, 0.16, 280.0, 0.28, true)
		"craft": data = _sweep(rate, 0.24, 320.0, 720.0, 0.26)
		"wind":
			data = _noise_burst(rate, 1.8, 0.14)
			loop = true
		"blizzard":
			data = _noise_burst(rate, 2.2, 0.3)
			loop = true
		_: data = _tone(rate, 0.1, 440.0, 0.2, false)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = data.size() / 2
	_sfx_cache[sound_name] = stream
	return stream


func _tone(rate: int, duration: float, freq: float, volume: float, rumble: bool) -> PackedByteArray:
	var data := PackedByteArray()
	var n := int(rate * duration)
	for i in range(n):
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / float(n), 1.7)
		var s := sin(TAU * freq * t)
		if rumble:
			s = s * 0.7 + sin(TAU * freq * 0.5 * t) * 0.5
		_pcm_append(data, s * env * volume)
	return data


func _sweep(rate: int, duration: float, f0: float, f1: float, volume: float) -> PackedByteArray:
	var data := PackedByteArray()
	var n := int(rate * duration)
	var phase := 0.0
	for i in range(n):
		var k := float(i) / float(n)
		phase += TAU * lerpf(f0, f1, k) / float(rate)
		_pcm_append(data, sin(phase) * (1.0 - k) * volume)
	return data


func _noise_burst(rate: int, duration: float, volume: float) -> PackedByteArray:
	var data := PackedByteArray()
	var n := int(rate * duration)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var last := 0.0
	for i in range(n):
		var env := pow(1.0 - float(i) / float(n), 1.5)
		last = last * 0.82 + rng.randf_range(-1.0, 1.0) * 0.35
		_pcm_append(data, last * env * volume)
	return data


func _pcm_append(data: PackedByteArray, sample: float) -> void:
	var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
	data.append(v & 0xFF)
	data.append((v >> 8) & 0xFF)
