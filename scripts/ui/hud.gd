class_name Hud
extends Control

var prompt := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.interact_prompt.connect(func(t): prompt = t)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := get_theme_default_font()
	var fs := get_theme_default_font_size()
	# survival bars (top-left)
	_bar(f, fs, Vector2(24, 24), 260, "HEALTH", float(GameState.stats["health"]), float(GameState.stats["max_health"]), Color(0.75, 0.25, 0.22))
	_bar(f, fs, Vector2(24, 52), 260, "STAMINA", float(GameState.stats["stamina"]), float(GameState.stats["max_stamina"]), Color(0.35, 0.65, 0.35))
	_bar(f, fs, Vector2(24, 80), 260, "HUNGER", float(GameState.stats["hunger"]), 100.0, Color(0.78, 0.6, 0.25))
	_bar(f, fs, Vector2(24, 108), 260, "THIRST", float(GameState.stats["thirst"]), 100.0, Color(0.3, 0.6, 0.8))
	_bar(f, fs, Vector2(24, 136), 260, "WARMTH", (float(GameState.stats["body_temp"]) - 26.0) * 7.14, 100.0, Color(0.85, 0.5, 0.25))
	_bar(f, fs, Vector2(24, 164), 260, "INFECTION", float(GameState.stats["infection"]), 100.0, Color(0.55, 0.75, 0.3))
	_bar(f, fs, Vector2(24, 192), 260, "FATIGUE", float(GameState.stats["fatigue"]), 100.0, Color(0.55, 0.5, 0.75))

	# clock / weather (top-right)
	var clock := "Day %d  %02d:%02d  |  %s" % [GameState.day, int(GameState.hour), int(fmod(GameState.hour, 1.0) * 60.0), String(GameState.weather).replace("_", " ")]
	var cw := f.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(get_viewport_rect().size.x - cw - 24, 40), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.8))
	draw_string(f, Vector2(get_viewport_rect().size.x - cw - 24, 66), "Auto-aim: %s" % ("ON" if GameState.auto_aim else "OFF"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.8, 0.9, 0.75))

	# active quest (right side)
	var y := 110.0
	for q in GameState.active_quests:
		var def = DataLibrary.get_quest(String(q["id"]))
		if def == null:
			continue
		draw_string(f, Vector2(get_viewport_rect().size.x - 420, y), String(def.title), HORIZONTAL_ALIGNMENT_LEFT, 396, fs, Color(0.95, 0.88, 0.6))
		y += 22.0
		for obj in def.objectives:
			var done := GameState.objective_done(String(def.id), obj)
			var cur := GameState.objective_progress(String(def.id), obj)
			var mark := "[x]" if done else "[ ]"
			draw_string(f, Vector2(get_viewport_rect().size.x - 420, y), "%s %s (%d/%d)" % [mark, String(obj.get("label", obj.get("id", ""))), cur, int(obj.get("count", 1))],
				HORIZONTAL_ALIGNMENT_LEFT, 396, fs - 2, Color(0.75, 0.8, 0.72))
			y += 19.0

	# interact prompt (bottom centre)
	if prompt != "":
		var pw := f.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2).x
		var cx := get_viewport_rect().size.x * 0.5 - pw * 0.5
		draw_rect(Rect2(cx - 16, get_viewport_rect().size.y - 150, pw + 32, 38), Color(0.08, 0.1, 0.11, 0.85))
		draw_string(f, Vector2(cx, get_viewport_rect().size.y - 124), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, Color(0.95, 0.92, 0.8))


func _bar(f: Font, fs: int, pos: Vector2, width: float, label: String, value: float, max_value: float, color: Color) -> void:
	draw_string(f, Vector2(pos.x, pos.y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, 90, fs - 3, Color(0.8, 0.82, 0.78))
	draw_rect(Rect2(pos.x + 92, pos.y, width, 16), Color(0.07, 0.09, 0.1, 0.9))
	var pct := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	draw_rect(Rect2(pos.x + 92, pos.y, width * pct, 16), color)
