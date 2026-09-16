extends Node
## Original short arcade effects, generated once and reused across all sixteen heroes.
var enabled := true
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var last_shot := 0
func _ready() -> void:
	var notes := {"shoot":[520,260],"hurt":[100,65],"pickup":[660,880,1100],"key":[440,660,880],"magic":[180,360,720,1440],"destroy":[150,100,60],"select":[330,440],"start":[220,330,440,660],"defeat":[330,260,196,110],"win":[330,440,550,660,880]}
	for kind in notes:
		var data := PackedByteArray()
		var duration := 0.022 if kind=="shoot" else 0.07
		for frequency in notes[kind]:
			var count := int(22050*duration)
			for i in count:
				var sample := int(sin(i*float(frequency)*TAU/22050)*0.22*(1.0-float(i)/count)*32767)
				data.append(sample&255)
				data.append((sample>>8)&255)
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.data = data
		samples[kind] = stream
	for i in 6:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -13
		add_child(voice)
		voices.append(voice)
func effect(kind: String) -> void:
	if not enabled: return
	if kind=="shoot":
		if Time.get_ticks_msec()-last_shot<90: return
		last_shot = Time.get_ticks_msec()
	for voice in voices:
		if not voice.playing:
			voice.stream = samples[kind]
			voice.play()
			return
