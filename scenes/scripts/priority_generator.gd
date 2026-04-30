extends RefCounted

static func generate() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# Stage 2: medium difficulty with stronger ordering conflicts.
	var process_count: int = rng.randi_range(4, 5)
	var processes: Array[Dictionary] = []
	for i in range(process_count):
		processes.append({
			"name": "P%d" % (i + 1),
			"arrival": rng.randi_range(0, 6),
			"burst": rng.randi_range(2, 8),
			"priority": rng.randi_range(1, 7)
		})

	# Force at least one tie on arrival to make priority decisions visible.
	if process_count >= 4:
		var a_idx: int = rng.randi_range(0, process_count - 1)
		var b_idx: int = (a_idx + 1) % process_count
		processes[b_idx]["arrival"] = processes[a_idx]["arrival"]
		if processes[b_idx]["priority"] == processes[a_idx]["priority"]:
			processes[b_idx]["priority"] = clampi(int(processes[b_idx]["priority"]) + 1, 1, 7)

	var scheduled: Array[Dictionary] = []
	var remaining: Array[Dictionary] = processes.duplicate(true)
	var waiting_times: Dictionary = {}
	var turnaround_times: Dictionary = {}
	var completion_times: Dictionary = {}
	var gantt: Array[Dictionary] = []
	var current_time: int = 0

	while not remaining.is_empty():
		var available: Array[Dictionary] = []
		for p in remaining:
			if p["arrival"] <= current_time:
				available.append(p)

		if available.is_empty():
			var next_arrival: int = int(remaining[0]["arrival"])
			for p in remaining:
				next_arrival = mini(next_arrival, int(p["arrival"]))
			if current_time < next_arrival:
				gantt.append({"label": "IDLE", "start": current_time, "end": next_arrival})
				current_time = next_arrival
			continue

		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["priority"] == b["priority"]:
				if a["arrival"] == b["arrival"]:
					return a["name"] < b["name"]
				return a["arrival"] < b["arrival"]
			return a["priority"] < b["priority"]
		)

		var chosen: Dictionary = available[0]
		remaining.erase(chosen)
		scheduled.append(chosen)

		var start: int = current_time
		var end: int = current_time + int(chosen["burst"])
		gantt.append({"label": chosen["name"], "start": start, "end": end})

		var waiting: int = start - int(chosen["arrival"])
		var turnaround: int = end - int(chosen["arrival"])
		waiting_times[chosen["name"]] = waiting
		turnaround_times[chosen["name"]] = turnaround
		completion_times[chosen["name"]] = end
		current_time = end

	# Keep original process order in the table.
	processes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"] < b["name"]
	)

	var blank_index: int = rng.randi_range(0, process_count - 1)
	var blank_process_name: String = processes[blank_index]["name"]
	var gantt_blank_index: int = _pick_non_idle_gantt_index(gantt, rng)

	return {
		"algorithm": "Priority (Non-preemptive)",
		"difficulty_tip": "Stage 2 (Priority): compare ready processes by priority first, then arrival/order tie-breakers.",
		"processes": processes,
		"gantt": gantt,
		"waiting_times": waiting_times,
		"turnaround_times": turnaround_times,
		"completion_times": completion_times,
		"blank_index": blank_index,
		"gantt_blank_index": gantt_blank_index,
		"correct_answer": waiting_times[blank_process_name]
	}

static func _pick_non_idle_gantt_index(gantt: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var indices: Array[int] = []
	for i in range(gantt.size()):
		if gantt[i]["label"] != "IDLE":
			indices.append(i)
	if indices.is_empty():
		return 0
	return indices[rng.randi_range(0, indices.size() - 1)]
