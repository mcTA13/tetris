class_name Synth
## 効果音をコードで合成する小さなシンセ。素材ファイルなしで音を作るため。

const RATE := 44100


static func midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## 1音。wave: sine / triangle / square / saw / noise
## decay: 大きいほど早く減衰。freq_end を渡すと周波数が滑らかに変わる
static func tone(freq: float, duration: float, wave := "sine", volume := 0.5, decay := 8.0,
		freq_end := -1.0, attack := 0.004) -> PackedFloat32Array:
	var n := int(duration * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var f_end := freq if freq_end < 0.0 else freq_end
	var noise_value := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / duration
		var f := freq * pow(f_end / freq, k)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		match wave:
			"sine":
				v = sin(phase * TAU)
			"triangle":
				v = 4.0 * absf(phase - 0.5) - 1.0
			"square":
				v = 0.6 if phase < 0.5 else -0.6
			"saw":
				v = (2.0 * phase - 1.0) * 0.7
			"noise":
				# 周波数で粗さを変えるサンプル＆ホールドのノイズ
				if phase < f / RATE:
					noise_value = randf_range(-1.0, 1.0)
				v = noise_value
		var env := minf(t / attack, 1.0) * exp(-t * decay)
		var fade_out := minf((duration - t) / 0.005, 1.0)
		out[i] = v * env * fade_out * volume
	return out


## parts: [[開始秒, サンプル列], ...] を重ねる
static func mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for p in parts:
		length = maxi(length, int(p[0] * RATE) + p[1].size())
	var out := PackedFloat32Array()
	out.resize(length)
	for p in parts:
		var start := int(p[0] * RATE)
		var samples: PackedFloat32Array = p[1]
		for i in samples.size():
			out[start + i] += samples[i]
	return out


## notes を gap 秒ずつずらして鳴らすアルペジオ
static func arpeggio(notes: Array, gap: float, duration: float, wave := "triangle", volume := 0.3, decay := 10.0) -> PackedFloat32Array:
	var parts := []
	for i in notes.size():
		parts.append([i * gap, tone(midi(notes[i]), duration, wave, volume, decay)])
	return mix(parts)


## 再生速度を変えて音程を上げ下げする（semitones 半音。上げると短くなる）
static func pitched(samples: PackedFloat32Array, semitones: float) -> PackedFloat32Array:
	var rate := pow(2.0, semitones / 12.0)
	var out := PackedFloat32Array()
	out.resize(int(samples.size() / rate))
	for i in out.size():
		out[i] = samples[mini(int(i * rate), samples.size() - 1)]
	return out


static func to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
