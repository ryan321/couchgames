extends Node
## Host-owned native Wii output, with shared-speaker fallback for other controllers.
signal fallback_requested(hero_class: int, player_id: int)
const AUDIO := "res://examples/gauntlet/assets/audio/"
const CLASSES := ["warrior","valkyrie","wizard","elf"]
var directory := ""
var service: Node
var pending: Dictionary = {}
var sent: Dictionary = {}
var enabled := true
# Streaming destabilized the physically tested Remote. Use shared audio until qualified.
var speaker_enabled := false
var clips: Array[PackedByteArray] = []
var hurt_clips: Dictionary = {}
var rumble_enabled := true
var rumbling: Dictionary = {}
var connected_devices: Callable = Input.get_connected_joypads
var rumble_output: Callable = Input.start_joy_vibration
var rumble_stop: Callable = Input.stop_joy_vibration

func _ready() -> void:
	for kind: String in CLASSES:
		clips.append(FileAccess.get_file_as_bytes(AUDIO+"choose_"+kind+".adpcm"))
		for take in 3: hurt_clips["%s_%d"%[kind,take]] = FileAccess.get_file_as_bytes(AUDIO+"hurt_%s_%d.adpcm"%[kind,take])

func choose(player_id: int, hero_class: int) -> void:
	if not enabled or not service.players.has(player_id) or hero_class<0 or hero_class>=4: return
	var device: int = service.players[player_id].device
	var state := connection(device-1000) if speaker_enabled and device>=1000 and device<1016 and not directory.is_empty() else {}
	# Bind to this player/device/connection now, so slot reuse cannot receive an old selection.
	pending[player_id] = {"device":device,"class":hero_class,"generation":state.get("generation",""),"at":Time.get_ticks_msec()+90}

func connection(slot: int) -> Dictionary:
	var path := directory.path_join("remote-%d.json"%slot)
	var file := FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>512: return {}
	var state = JSON.parse_string(file.get_as_text())
	if not state is Dictionary or not state.get("generation") is String: return {}
	var timestamp = state.get("updated")
	if not (timestamp is float or timestamp is int): return {}
	var age := Time.get_unix_time_from_system()-float(timestamp)
	if not is_finite(age) or age>2 or age< -1: return {}
	return state

func send(slot: int, generation: String, audio: PackedByteArray, rumble_ms := 0) -> void:
	if directory.is_empty(): return
	var request := {"generation":generation,"id":Crypto.new().generate_random_bytes(12).hex_encode(),
		"expires":Time.get_unix_time_from_system()+1.0,"encoding":"yamaha4k","rumble_ms":rumble_ms,"audio":"" if audio.is_empty() else Marshalls.raw_to_base64(audio)}
	var path := directory.path_join("speaker-%d.json"%slot)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(request))
	file.close()
	if DirAccess.rename_absolute(path+".tmp",path)==OK: sent[slot] = generation

func _process(_delta: float) -> void:
	for player_id: int in pending.keys():
		var request: Dictionary = pending[player_id]
		if Time.get_ticks_msec()<request.at: continue
		pending.erase(player_id)
		if not enabled or not service.players.has(player_id): continue
		if int(service.players[player_id].device)!=request.device: continue
		if request.generation.is_empty():
			fallback_requested.emit(request["class"],player_id)
			continue
		var slot: int = request.device-1000
		var state := connection(slot)
		if state.get("generation","")!=request.generation: continue
		send(slot,request.generation,clips[request["class"]])

func stop_all() -> void:
	for device: int in rumbling: rumble_stop.call(device)
	rumbling.clear()
	pending.clear()
	for slot: int in sent.keys(): send(slot,sent[slot],PackedByteArray())
	sent.clear()

func _exit_tree() -> void: stop_all()

func hurt(player_id: int, hero_class: int, take: int, audible := true) -> void:
	if not enabled or not service.players.has(player_id): return
	var device: int = service.players[player_id].device
	var slot := device-1000
	if slot>=0 and slot<16 and not directory.is_empty():
		var state := connection(slot)
		if state.is_empty(): return
		var audio: PackedByteArray = hurt_clips["%s_%d"%[CLASSES[clampi(hero_class,0,3)],posmod(take,3)]] if audible and speaker_enabled else PackedByteArray()
		send(slot,state.generation,audio,120 if rumble_enabled else 0)
	elif device>=0 and rumble_enabled and connected_devices.call().has(device):
		rumbling[device] = player_id
		rumble_output.call(device,0.22,0.35,0.12)
