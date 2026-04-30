extends RefCounted

static func generate() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# Stage 1: keep values compact and mostly linear to teach fundamentals.
	var process_count: int = rng.randi_range(3, 4)
	var processes: Array[Dictionary] = []
	for i in range(process_count):
		processes.append({
			"name": "P%d" % (i + 1),
			"arrival": rng.randi_range(0, 2),
			"burst": rng.randi_range(1, 4)
		})

	processes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["arrival"] == b["arrival"]:
			return a["name"] < b["name"]
		return a["arrival"] < b["arrival"]
	)

	var gantt: Array[Dictionary] = []
	var waiting_times: Dictionary = {}
	var turnaround_times: Dictionary = {}
	var completion_times: Dictionary = {}
	var current_time: int = 0

	for p in processes:
		var arrival: int = p["arrival"]
		var burst: int = p["burst"]
		if current_time < arrival:
			gantt.append({"label": "IDLE", "start": current_time, "end": arrival})
			current_time = arrival

		var start: int = current_time
		var end: int = current_time + burst
		gantt.append({"label": p["name"], "start": start, "end": end})

		var waiting: int = start - arrival
		var turnaround: int = end - arrival
		waiting_times[p["name"]] = waiting
		turnaround_times[p["name"]] = turnaround
		completion_times[p["name"]] = end
		current_time = end

	var blank_index: int = rng.randi_range(0, process_count - 1)
	var blank_process_name: String = processes[blank_index]["name"]
	var gantt_blank_index: int = _pick_non_idle_gantt_index(gantt, rng)

	return {
		"algorithm": "FCFS",
		"difficulty_tip": "Stage 1 (FCFS): focus on the execution order and first-start waiting times.",
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
