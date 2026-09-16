extends Node
## Small original synthesized effects, generated once. No external audio assets.
var samples: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2048
	for kind in ["shot","hit","hurt","reload","pickup","wave","win","build"]:
		var data := PackedByteArray()
		var duration := 0.12 if kind in ["shot","hit"] else 0.32
		for i in int(22050*duration):
			var t := float(i)/22050
			var envelope := pow(1-t/duration,2)
			var value := 0.0
			match kind:
				"shot": value = (rng.randf_range(-1,1)*0.45+sin(t*(180-t*500)*TAU)*0.5)*envelope
				"hit": value = sin(t*1700*TAU)*envelope*0.4
				"hurt": value = (sin(t*95*TAU)+rng.randf_range(-0.3,0.3))*envelope*0.5
				"reload", "build": value = rng.randf_range(-0.5,0.5)*envelope*(0.5+sin(t*50))
				_: value = sin(t*(660+int(t*12)*220)*TAU)*envelope*0.4
			var sample := int(clampf(value,-1,1)*24000)
			data.append(sample&255)
			data.append((sample>>8)&255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		samples[kind] = stream
	for i in 10:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -17
		add_child(voice)
		voices.append(voice)
func effect(kind: String) -> void:
	for voice in voices:
		if not voice.playing:
			voice.stream = samples[kind]
			voice.play()
			return
