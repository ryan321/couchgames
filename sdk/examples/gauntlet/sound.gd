extends Node
## Recorded lobby lines and synthesized combat/music with reserved player voice pools.
const AUDIO := "res://examples/gauntlet/assets/audio/"
const CLASSES := ["warrior","valkyrie","wizard","elf"]
const EFFECTS := ["shoot","axe","sword","bow","impact","impact_ghost","stone","enemy_grunt","enemy_ghost","enemy_demon","pickup","key","magic","destroy","select","start","defeat","win"]
var enabled := true:
	set(value):
		enabled = value
		if not value:
			stop_effects()
			if music_player: music_player.stop()
var sfx_enabled := true:
	set(value):
		sfx_enabled = value
		if not value: stop_effects()
var music_enabled := true:
	set(value):
		music_enabled = value
		if not value and music_player: music_player.stop()
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var last_effect: Dictionary = {}
var last_hurt: Dictionary = {}
var hurt_variants: Dictionary = {}
var music_player: AudioStreamPlayer
var music_tracks: Array[AudioStreamOggVorbis] = []
var music_chapter := -1
var last_hurt_sample := ""
var last_hurt_player := 0
var selection_voices: Dictionary = {}

func _ready() -> void:
	for kind: String in EFFECTS: samples[kind] = load(AUDIO+kind+".wav")
	for kind: String in CLASSES:
		samples["choose_"+kind] = load(AUDIO+"choose_"+kind+".wav")
		for take in 3:
			var key := "hurt_%s_%d"%[kind,take]
			samples[key] = load(AUDIO+key+".wav")
	for i in 16:
		var voice := AudioStreamPlayer.new()
		voice.name = "EffectVoice%d"%i
		add_child(voice)
		voices.append(voice)
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.volume_db = -40
	add_child(music_player)
	for theme in ["ember","archive","crown"]:
		var stream: AudioStreamOggVorbis = load(AUDIO+"music_"+theme+".ogg").duplicate()
		stream.loop = true
		music_tracks.append(stream)

func _process(delta: float) -> void:
	if not enabled or not music_enabled: return
	var game := get_parent()
	var chapter: int = clampi(game.level_index,0,music_tracks.size()-1)
	if chapter!=music_chapter:
		music_chapter = chapter
		music_player.stream = music_tracks[chapter]
		music_player.volume_db = -40
		music_player.play()
	elif not music_player.playing: music_player.play()
	var target := -25.0
	match game.phase:
		"lobby": target = -29.0
		"paused": target = -35.0
		"complete": target = -34.0
		"defeat": target = -38.0
	music_player.volume_db = move_toward(music_player.volume_db,target,delta*12)

func stop_effects() -> void:
	selection_voices.clear()
	for voice: AudioStreamPlayer in voices: voice.stop()

func play_in_pool(kind: String, first: int, end: int, volume: float, pitch := 1.0, priority := false) -> AudioStreamPlayer:
	var chosen: AudioStreamPlayer
	var oldest := -1.0
	for i in range(first,end):
		var voice := voices[i]
		if not voice.playing:
			chosen = voice
			break
		if priority and voice.get_playback_position()>oldest:
			oldest = voice.get_playback_position()
			chosen = voice
	if not chosen: return null
	chosen.volume_db = volume
	chosen.pitch_scale = pitch
	chosen.stream = samples[kind]
	chosen.set_meta("selection_owner",-1)
	chosen.play()
	return chosen

func hurt(hero_class: int, player_id: int) -> void:
	if not enabled or not sfx_enabled: return
	var now := Time.get_ticks_msec()
	if now-int(last_hurt.get(player_id,-1000))<220: return
	last_hurt[player_id] = now
	var take: int = int(hurt_variants.get(player_id,0))%3
	hurt_variants[player_id] = take+1
	last_hurt_sample = "hurt_%s_%d"%[CLASSES[clampi(hero_class,0,3)],take]
	last_hurt_player = player_id
	# Eight reserved voices keep a hurt response audible during a full party's attacks.
	play_in_pool(last_hurt_sample,0,8,-9,1.0,true)
	# Briefly lower the score so the player's reaction comes through.
	if music_player: music_player.volume_db = minf(music_player.volume_db,-31)

func effect(kind: String) -> void:
	if not enabled or not sfx_enabled or not samples.has(kind): return
	var impact := kind in ["impact","impact_ghost","stone","enemy_grunt","enemy_ghost","enemy_demon"]
	var weapon := kind in ["shoot","axe","sword","bow"]
	var gap := 65 if impact else (70 if weapon else 85)
	var now := Time.get_ticks_msec()
	if now-int(last_effect.get(kind,-1000))<gap: return
	last_effect[kind] = now
	var pitch := 1.0+sin(now*0.013)*0.035 if impact or weapon else 1.0
	var priority := kind in ["win","defeat","start","magic","destroy"]
	play_in_pool(kind,8 if impact else 11,11 if impact else 16,(-25 if kind.begins_with("enemy_") else -20) if impact else -17,pitch,priority)

func stop_selection(player_id: int) -> void:
	var previous: AudioStreamPlayer = selection_voices.get(player_id)
	if is_instance_valid(previous) and previous.get_meta("selection_owner",-1)==player_id: previous.stop()
	selection_voices.erase(player_id)

func selection(hero_class: int, player_id := 0) -> void:
	if not enabled or not sfx_enabled: return
	stop_selection(player_id)
	var voice := play_in_pool("choose_"+CLASSES[clampi(hero_class,0,3)],0,8,-9,1.0,true)
	if voice:
		voice.set_meta("selection_owner",player_id)
		selection_voices[player_id] = voice
