extends Node
## Small original synthesized effects; no original soundtrack recording.
var enabled := true
var voices: Array[AudioStreamPlayer] = []
func _ready() -> void:
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -18
		add_child(voice)
		voices.append(voice)
func effect(kind: String) -> void:
	if not enabled: return
	var patterns := {"jump":[220,440,660],"coin":[988,1319],"bump":[160,90],
		"power":[262,330,392,523,659,784],"stomp":[180,80],"death":[440,330,220,110],
		"win":[392,523,659,784,1047],"fire":[600,300,150],"life":[659,784,1319,1047]}
	var notes: Array = patterns.get(kind,[220])
	var data := PackedByteArray()
	var seconds := 0.045 if kind not in ["death","win"] else 0.12
	for frequency in notes:
		var samples := int(22050*seconds)
		for i in samples:
			var fade := minf(1.0,float(samples-i)/200)
			var sample := int((0.3 if fmod(i*float(frequency)/22050,1)<0.25 else -0.3)*fade*32767)
			data.append(sample&255)
			data.append((sample>>8)&255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			return
