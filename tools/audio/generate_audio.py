import wave
import struct
import math
import random
import os

def write_wav(filename, samples, sample_rate=44100):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        for sample in samples:
            sample = max(-1.0, min(1.0, sample))
            val = int(sample * 32767.0)
            data = struct.pack('<h', val)
            wav_file.writeframesraw(data)

def gen_tone(freq, duration, vol=0.5, sr=44100, waveform='sine', attack=0.05, release=0.1):
    samples = []
    ns = int(duration * sr)
    for i in range(ns):
        t = float(i) / sr
        
        if waveform == 'sine':
            s = math.sin(2 * math.pi * freq * t)
        elif waveform == 'square':
            s = 1.0 if math.sin(2 * math.pi * freq * t) > 0 else -1.0
        elif waveform == 'saw':
            s = 2.0 * (t * freq - math.floor(t * freq + 0.5))
        elif waveform == 'noise':
            s = random.uniform(-1.0, 1.0)
            
        env = 1.0
        if t < attack:
            env = t / attack
        elif t > duration - release:
            env = (duration - t) / release
            
        samples.append(s * vol * env)
    return samples

def mix(*sample_lists):
    max_len = max(len(sl) for sl in sample_lists)
    mixed = [0.0] * max_len
    for sl in sample_lists:
        for i, s in enumerate(sl):
            mixed[i] += s
    return mixed

def concat(*sample_lists):
    res = []
    for sl in sample_lists:
        res.extend(sl)
    return res

# SFX
write_wav("assets/audio/sfx/ui_click.wav", gen_tone(600, 0.1, vol=0.3, attack=0.01, release=0.05))
write_wav("assets/audio/sfx/card_draw.wav", gen_tone(0, 0.2, vol=0.2, waveform='noise', attack=0.05, release=0.15))
write_wav("assets/audio/sfx/card_place.wav", mix(gen_tone(120, 0.15, vol=0.5, attack=0.01, release=0.1), gen_tone(0, 0.1, vol=0.1, waveform='noise')))
write_wav("assets/audio/sfx/hit_impact.wav", mix(gen_tone(80, 0.3, vol=0.7, waveform='square', attack=0.01, release=0.2), gen_tone(0, 0.3, vol=0.5, waveform='noise', attack=0.01, release=0.2)))
write_wav("assets/audio/sfx/score_up.wav", concat(gen_tone(880, 0.1, vol=0.2, attack=0.01, release=0.05), gen_tone(1108, 0.2, vol=0.2, attack=0.01, release=0.1)))
write_wav("assets/audio/sfx/ui_error.wav", concat(gen_tone(150, 0.15, vol=0.4, waveform='saw', attack=0.01, release=0.05), [0]*int(44100*0.05), gen_tone(120, 0.3, vol=0.4, waveform='saw', attack=0.01, release=0.2)))

# BGM (Drones - approx 5 seconds each)
# Menu: Ethereal drone (Sine wave beating)
menu_bgm = mix(gen_tone(110, 5.0, vol=0.2, attack=1.0, release=1.0), gen_tone(111.5, 5.0, vol=0.2, attack=1.0, release=1.0))
write_wav("assets/audio/bgm/main_menu.wav", menu_bgm)

# Hub: Mysterious hum
hub_bgm = mix(gen_tone(146.83, 5.0, vol=0.2, attack=1.0, release=1.0), gen_tone(196, 5.0, vol=0.1, attack=1.0, release=1.0))
write_wav("assets/audio/bgm/hub_theme.wav", hub_bgm)

# Battle: Tense drone (Low saw + noise)
battle_bgm = mix(gen_tone(65.41, 5.0, vol=0.3, waveform='saw', attack=0.5, release=0.5), gen_tone(0, 5.0, vol=0.05, waveform='noise'))
write_wav("assets/audio/bgm/battle_theme.wav", battle_bgm)

print("Procedural audio generation complete!")
