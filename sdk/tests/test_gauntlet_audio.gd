extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.close_on_finish = false
	var sound = game.sound
	sound.set_process(false)
	# The headless test driver uses a dummy audio device; exercise actual stream playback.
	var fingerprints := {}
	for kind: String in sound.CLASSES:
		for take in 3:
			var sample: AudioStreamWAV = sound.samples["hurt_%s_%d"%[kind,take]]
			expect(sample.get_length()>.15 and sample.get_length()<.9,"Hurt reaction is a short playable sample")
			fingerprints[sample.data.hex_encode().sha256_text()] = true
	expect(fingerprints.size()==12,"Every class and take has different audio")
	for kind: String in sound.EFFECTS:
		expect(sound.samples[kind].get_length()>.08,"Combat and interface samples contain audio: "+kind)
	for kind in 4:
		var hero: Dictionary = game.make_hero(kind+1,kind,kind)
		hero.hurt = 0
		var before: float = hero.hp
		game.hurt(hero,20)
		expect(hero.hp<before and sound.last_hurt_sample=="hurt_%s_0"%sound.CLASSES[kind],"Actual damage selects the hurt voice for this class")
		game.hurt(hero,20)
		expect(sound.hurt_variants[kind+1]==1,"Invulnerability prevents repeated hurt sounds")
	expect(sound.last_hurt.size()==4,"Simultaneous players have independent hurt responses")
	for take in [1,2,0]:
		sound.last_hurt[1] = -1000
		sound.hurt(0,1)
		expect(sound.last_hurt_sample=="hurt_warrior_%d"%take,"Successive hits cycle through three takes")
	for kind: String in ["axe","sword","bow","shoot","magic","impact","destroy"]: sound.effect(kind)
	sound.hurt(3,16)
	var audible_hurt := false
	for voice: AudioStreamPlayer in sound.voices:
		if voice.playing and voice.stream==sound.samples["hurt_elf_0"]: audible_hurt = true
	expect(audible_hurt,"A new player hurt reaction can play during crowded weapon/impact activity")
	for chapter in 3:
		game.level_index = chapter
		sound._process(1)
		expect(sound.music_player.playing and sound.music_player.stream==sound.music_tracks[chapter],"Each vault selects its score")
		expect(sound.music_tracks[chapter].loop and sound.music_tracks[chapter].get_length()>35,"Music loops a complete multi-bar arrangement")
	game.phase = "playing"
	sound._process(10)
	var playing_volume: float = sound.music_player.volume_db
	game.phase = "paused"
	sound._process(10)
	expect(sound.music_player.volume_db<playing_volume,"Pause lowers the music")
	game.activate_menu(4)
	expect(not sound.sfx_enabled and sound.music_player.playing,"Sound effects can be muted while music continues")
	sound.hurt(0,99)
	expect(not sound.last_hurt.has(99),"Muted effects do not play hurt reactions")
	game.menu_index = 0
	game.move_menu(-2)
	expect(game.menu_index==9 and game.menu_labels()[9].begins_with("Music:"),"Controller menu navigation reaches music setting")
	game.activate_menu(game.menu_index)
	expect(not sound.music_enabled and not sound.music_player.playing,"Music setting stops playback")
	game.activate_menu(4)
	sound.hurt(0,99)
	expect(sound.last_hurt.has(99),"Effects work with music disabled")
	game.activate_menu(9)
	sound._process(1)
	expect(sound.music_player.playing,"Music resumes when enabled again")
	sound.enabled = false
	expect(not sound.music_player.playing,"Master test mute stops music")
	for voice: AudioStreamPlayer in sound.voices: expect(not voice.playing,"Master mute stops effect voices")
	check_controller_selection(game)
	# Let the last short effects finish before destroying their playback resources.
	await create_timer(2.5).timeout
	game.sound.enabled = false
	for voice: AudioStreamPlayer in game.sound.voices: voice.stream = null
	game.sound.music_player.stream = null
	await create_timer(0.10).timeout
	game.free()
	await process_frame
	if failures==0: print("Gauntlet audio checks passed: %d assertions; synthetic playback and damage/menu routes."%checks)
	quit(0 if failures==0 else 1)

func check_controller_selection(game: Node) -> void:
	var output: Node = game.controller_voice
	output.set_process(false)
	var path := OS.get_user_data_dir().path_join("speaker-test-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(path)
	output.directory = path
	output.speaker_enabled = true
	game.phase = "lobby"
	game.sound.enabled = true
	game.sound.sfx_enabled = true
	var service: Node = game.service
	service.set_process_input(false)
	service.set_physics_process(false)
	var fallbacks: Array = []
	output.fallback_requested.connect(func(kind, _player): fallbacks.append(kind))
	# Device IDs deliberately differ from player IDs; synthetic state matches host framing.
	service.players[1] = {"device":1002}
	service.players[2] = {"device":0}
	game.heroes[1] = game.make_hero(1,0,0)
	game.heroes[2] = game.make_hero(2,0,1)
	var state_file := FileAccess.open(path.path_join("remote-2.json"),FileAccess.WRITE)
	state_file.store_string(JSON.stringify({"generation":"connection-a","updated":Time.get_unix_time_from_system()}))
	state_file.close()
	game.cycle_class(1,1)
	game.cycle_class(1,1)
	expect(output.pending.size()==1,"Rapid scrolling retains only the latest selection for this player")
	output.pending[1].at = 0
	output._process(0)
	var request = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(request.generation=="connection-a" and request.expires>Time.get_unix_time_from_system(),"Wii speaker request belongs to the current connection and expires")
	expect(Marshalls.base64_to_raw(request.audio)==output.clips[2],"Wii receives the chosen Wizard utterance")
	expect(fallbacks.is_empty(),"Wii utterance is not duplicated on shared speakers")
	game.cycle_class(2,1)
	output.pending[2].at = 0
	output._process(0)
	expect(fallbacks==[1],"Xbox-style device uses shared speakers for its class")
	game.cycle_class(1,1)
	service.players[1].device = 1003
	output.pending[1].at = 0
	output._process(0)
	expect(not FileAccess.file_exists(path.path_join("speaker-3.json")),"A reassigned controller cannot receive the previous device's utterance")
	service.players[1].device = 1002
	game.cycle_class(1,1)
	state_file = FileAccess.open(path.path_join("remote-2.json"),FileAccess.WRITE)
	state_file.store_string(JSON.stringify({"generation":"connection-b","updated":Time.get_unix_time_from_system()}))
	state_file.close()
	output.pending[1].at = 0
	output._process(0)
	var unchanged = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(unchanged.id==request.id,"A reconnect does not replay a selection meant for an old connection")
	game.phase = "paused"
	game.activate_menu(4)
	var stop = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(stop.audio=="" and output.pending.is_empty(),"Muting effects cancels pending and active controller speech")
	for clip: PackedByteArray in output.clips: expect(clip.size()>200 and clip.size()<=1600,"Each controller utterance fits the host's bounded ADPCM payload")
	game.sound.sfx_enabled = true
	game.sound.selection(0,2)
	var old_voice: AudioStreamPlayer = game.sound.selection_voices[2]
	game.sound.selection(1,3)
	var other_voice: AudioStreamPlayer = game.sound.selection_voices[3]
	game.sound.selection(2,2)
	expect(game.sound.selection_voices[2].stream==game.sound.samples["choose_wizard"],"Class switching replaces that player's current line")
	expect(not old_voice.playing or old_voice.stream==game.sound.samples["choose_wizard"],"The old class line cannot keep talking over the new choice")
	expect(other_voice.playing and other_voice.stream==game.sound.samples["choose_valkyrie"],"Another player's selection is not interrupted")
	# Real damage routes feedback only to its owning device; stubs avoid physical rumble in tests.
	var vibrations: Array = []
	var stops: Array = []
	output.connected_devices = func(): return [0]
	output.rumble_output = func(device, weak, strong, duration): vibrations.append([device,weak,strong,duration])
	output.rumble_stop = func(device): stops.append(device)
	game.sound.sfx_enabled = true
	game.phase = "playing"
	var hero: Dictionary = game.heroes[1]
	hero.hurt = 0
	game.hurt(hero,20)
	var hit = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(hit.encoding=="yamaha4k" and hit.rumble_ms==120 and not hit.audio.is_empty(),"Wii damage requests a short rumble and class hurt audio")
	game.hurt(hero,20)
	var repeated = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(hit.id==repeated.id,"Invulnerable contact cannot retrigger controller feedback")
	game.heroes[2].hurt = 0
	game.hurt(game.heroes[2],20)
	expect(vibrations.size()==1 and vibrations[0][0]==0 and vibrations[0][3]==0.12,"Gamepad hit targets its physical device for 120 ms")
	game.toggle_pause()
	expect(stops==[0] and output.rumbling.is_empty(),"Pause stops active gamepad rumble")
	game.activate_menu(10)
	expect(not output.rumble_enabled,"Controller rumble has a menu switch")
	game.heroes[2].hurt = 0
	game.hurt(game.heroes[2],20)
	expect(vibrations.size()==1,"Disabled rumble sends no new vibration")
	for kind in ["grunt","ghost","demon"]:
		game.damage_enemy({"hp":100.0,"kind":kind},10)
		expect(game.sound.last_effect.has("enemy_"+kind),"Enemy damage selects its short vocal reaction")
		expect(game.sound.samples["enemy_"+kind].get_length()<.15,"Enemy reactions are shorter than hero oofs")
	# Production fallback avoids the physically observed Wii streaming/disconnect regression.
	output.speaker_enabled = false
	game.phase = "lobby"
	game.cycle_class(1,1)
	output.pending[1].at = 0
	output._process(0)
	expect(fallbacks.size()==2,"Wii voices use regular speakers while native streaming is unqualified")
	output.rumble_enabled = true
	game.heroes[1].hurt = 0
	game.hurt(game.heroes[1],20)
	var safe_hit = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("speaker-2.json")))
	expect(safe_hit.audio=="" and safe_hit.rumble_ms==120,"Production Wii hit sends only bounded rumble, without speaker data")
	service.players.clear()
	game.heroes.clear()
	output.stop_all()
	output.directory = ""
	for entry in DirAccess.get_files_at(path): DirAccess.remove_absolute(path.path_join(entry))
	DirAccess.remove_absolute(path)
