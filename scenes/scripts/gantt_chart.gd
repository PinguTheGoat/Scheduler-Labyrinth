extends Control

@export var slot_height: float = 28.0
@export var left_padding: float = 8.0
@export var right_padding: float = 8.0
@export var min_time_label_spacing: float = 6.0

var _segments: Array[Dictionary] = []
var _blank_index: int = -1
var _is_blank_revealed: bool = false

func set_chart(segments: Array, blank_index: int) -> void:
	_segments = []
	for segment in segments:
		_segments.append(segment)
	_blank_index = blank_index
	_is_blank_revealed = false
	queue_redraw()

func reveal_blank() -> void:
	_is_blank_revealed = true
	queue_redraw()

func _draw() -> void:
	if _segments.is_empty():
		return

	var total_time: float = float(_segments[_segments.size() - 1]["end"])
	if total_time <= 0.0:
		return

	var available_width: float = maxf(32.0, size.x - left_padding - right_padding)
	var y: float = 6.0
	var border_color: Color = Color(0.10, 0.13, 0.19, 1.0)
	var fill_color: Color = Color(0.43, 0.63, 0.92, 1.0)
	var idle_color: Color = Color(0.58, 0.62, 0.70, 1.0)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(9, get_theme_default_font_size() - 3)
	var time_font_size: int = maxi(8, font_size - 1)
	var timeline_y: float = y + slot_height + 13.0

	var time_marks: Array[Dictionary] = []
	var first_segment: Dictionary = _segments[0]
	var first_start: float = float(first_segment["start"])
	var first_x: float = left_padding + (first_start / total_time) * available_width
	time_marks.append({
		"x": first_x,
		"text": str(int(first_start)),
		"force": true
	})

	for i in range(_segments.size()):
		var segment: Dictionary = _segments[i]
		var start: float = float(segment["start"])
		var finish: float = float(segment["end"])
		var x: float = left_padding + (start / total_time) * available_width
		var w: float = maxf(1.0, ((finish - start) / total_time) * available_width)
		var rect: Rect2 = Rect2(x, y, w, slot_height)

		var is_idle: bool = String(segment["label"]) == "IDLE"
		draw_rect(rect, idle_color if is_idle else fill_color, true)
		draw_rect(rect, border_color, false, 1.5)

		var label_text: String = String(segment["label"])
		if i == _blank_index and not _is_blank_revealed:
			label_text = "?"
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x + 6.0 <= rect.size.x:
			var text_x: float = clampf(rect.position.x + (rect.size.x - text_size.x) * 0.5, 0.0, size.x - text_size.x)
			var text_pos: Vector2 = Vector2(text_x, rect.position.y + slot_height * 0.62)
			draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.BLACK)

		var boundary_x: float = rect.position.x + rect.size.x
		time_marks.append({
			"x": boundary_x,
			"text": str(int(finish)),
			"force": i == _segments.size() - 1
		})

	# Keep a midpoint marker visible for readability when the chart gets dense.
	var midpoint_time: float = total_time * 0.5
	var midpoint_index: int = 0
	var best_distance: float = INF
	for i in range(time_marks.size()):
		var value: float = float(String(time_marks[i]["text"]).to_float())
		var distance: float = absf(value - midpoint_time)
		if distance < best_distance:
			best_distance = distance
			midpoint_index = i
	time_marks[midpoint_index]["force"] = true

	var selected_marks: Array[Dictionary] = []
	for mark in time_marks:
		var mark_text: String = String(mark["text"])
		var mark_x: float = float(mark["x"])
		var force_draw: bool = bool(mark["force"])
		var mark_size: Vector2 = font.get_string_size(mark_text, HORIZONTAL_ALIGNMENT_LEFT, -1, time_font_size)
		var left: float = clampf(mark_x - mark_size.x * 0.5, 0.0, size.x - mark_size.x)
		var right: float = left + mark_size.x

		if selected_marks.is_empty():
			selected_marks.append({
				"text": mark_text,
				"left": left,
				"right": right,
				"force": force_draw
			})
			continue

		var prev: Dictionary = selected_marks[selected_marks.size() - 1]
		var overlaps_prev: bool = left < float(prev["right"]) + min_time_label_spacing

		if overlaps_prev and not force_draw:
			continue

		if overlaps_prev and force_draw:
			# Keep forced marks (start/mid/end) by removing colliding optional marks before them.
			while not selected_marks.is_empty():
				var last_mark: Dictionary = selected_marks[selected_marks.size() - 1]
				var last_overlaps: bool = left < float(last_mark["right"]) + min_time_label_spacing
				if not last_overlaps or bool(last_mark["force"]):
					break
				selected_marks.pop_back()

		selected_marks.append({
			"text": mark_text,
			"left": left,
			"right": right,
			"force": force_draw
		})

	var row_last_right: Array[float] = [-INF, -INF]
	var row_vertical_spacing: float = 10.0
	for mark in selected_marks:
		var left: float = float(mark["left"])
		var right: float = float(mark["right"])
		var row: int = -1

		for r in range(2):
			if left >= row_last_right[r] + min_time_label_spacing:
				row = r
				break

		if row == -1:
			if not bool(mark["force"]):
				continue
			var overlap_0: float = (row_last_right[0] + min_time_label_spacing) - left
			var overlap_1: float = (row_last_right[1] + min_time_label_spacing) - left
			row = 0 if overlap_0 <= overlap_1 else 1

		var draw_y: float = timeline_y + row * row_vertical_spacing
		draw_string(font, Vector2(left, draw_y), String(mark["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, time_font_size, Color.WHITE)
		row_last_right[row] = maxf(row_last_right[row], right)
