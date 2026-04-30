extends RefCounted

static func generate() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	# Stage 3: highest difficulty, encourage multi-quantum slicing.
	var process_count: int = rng.randi_range(5, 6)
	var quantum: int = 2
	var processes: Array[Dictionary] = []
	for i in range(process_count):
		var burst_value: int = rng.randi_range(4, 9)
		processes.append({
			"name": "P%d" % (i + 1),
			"arrival": rng.randi_range(0, 4),
			"burst": burst_value
		})

	# Guarantee one process needs at least 3 CPU slices.
	var forced_idx: int = rng.randi_range(0, process_count - 1)
	processes[forced_idx]["burst"] = maxi(int(processes[forced_idx]["burst"]), 7)

	processes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["arrival"] == b["arrival"]:
			return a["name"] < b["name"]
		return a["arrival"] < b["arrival"]
	)

	var remaining: Dictionary = {}
	var completion: Dictionary = {}
	for p in processes:
		remaining[p["name"]] = p["burst"]

	var queue: Array[String] = []
	var gantt: Array[Dictionary] = []
	var current_time: int = 0
	var next_index: int = 0
	var completed: int = 0

	while completed < process_count:
		while next_index < process_count and processes[next_index]["arrival"] <= current_time:
			queue.append(processes[next_index]["name"])
			next_index += 1

		if queue.is_empty():
			if next_index >= process_count:
				break
			var next_arrival: int = processes[next_index]["arrival"]
			if current_time < next_arrival:
				gantt.append({"label": "IDLE", "start": current_time, "end": next_arrival})
				current_time = next_arrival
			continue

		var proc_name: String = queue.pop_front()
		var remaining_time: int = remaining[proc_name]
		var run_time: int = mini(quantum, remaining_time)
		var start: int = current_time
		var end: int = current_time + run_time
		gantt.append({"label": proc_name, "start": start, "end": end})
		current_time = end

		remaining[proc_name] = remaining_time - run_time

		while next_index < process_count and processes[next_index]["arrival"] <= current_time:
			queue.append(processes[next_index]["name"])
			next_index += 1

		if int(remaining[proc_name]) > 0:
			queue.append(proc_name)
		else:
			completion[proc_name] = current_time
			completed += 1

	var waiting_times: Dictionary = {}
	var turnaround_times: Dictionary = {}

	# Keep process table sorted by process id for readability.
	processes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"] < b["name"]
	)

	for p in processes:
		var name: String = p["name"]
		var turnaround: int = int(completion[name]) - int(p["arrival"])
		var waiting: int = turnaround - int(p["burst"])
		turnaround_times[name] = turnaround
		waiting_times[name] = waiting

	var blank_process_name: String = _pick_multi_slice_process_name(gantt, processes, rng)
	var blank_index: int = 0
	for i in range(processes.size()):
		if String(processes[i]["name"]) == blank_process_name:
			blank_index = i
			break
	var gantt_blank_index: int = _pick_non_idle_gantt_index(gantt, rng)

	return {
		"algorithm": "Round Robin",
		"difficulty_tip": "Stage 3 (Round Robin): track each process across multiple time slices with quantum = 2.",
		"processes": processes,
		"gantt": gantt,
		"quantum": quantum,
		"waiting_times": waiting_times,
		"turnaround_times": turnaround_times,
		"completion_times": completion,
		"blank_index": blank_index,
		"gantt_blank_index": gantt_blank_index,
		"correct_answer": waiting_times[blank_process_name]
	}

static func _pick_multi_slice_process_name(gantt: Array[Dictionary], processes: Array[Dictionary], rng: RandomNumberGenerator) -> String:
	var slice_count: Dictionary = {}
	for slot in gantt:
		var label: String = String(slot.get("label", ""))
		if label == "" or label == "IDLE":
			continue
		slice_count[label] = int(slice_count.get(label, 0)) + 1

	var candidates: Array[String] = []
	for p in processes:
		var name: String = String(p["name"])
		if int(slice_count.get(name, 0)) >= 2:
			candidates.append(name)

	if candidates.is_empty():
		return String(processes[rng.randi_range(0, processes.size() - 1)]["name"])
	return candidates[rng.randi_range(0, candidates.size() - 1)]

static func _pick_non_idle_gantt_index(gantt: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var indices: Array[int] = []
	for i in range(gantt.size()):
		if gantt[i]["label"] != "IDLE":
			indices.append(i)
	if indices.is_empty():
		return 0
	return indices[rng.randi_range(0, indices.size() - 1)]
