"""Generates all SFX and chiptune loops for Party Pack LAN.

All audio is synthesized from scratch (square/triangle/noise waves),
so the assets are original and free to distribute with the game.
Output: assets/audio/*.wav (22050 Hz, 16-bit mono)
"""
import math
import random
import struct
import wave
import os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)

def write_wav(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        clipped = [max(-1.0, min(1.0, s)) for s in samples]
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in clipped))
    print(f"wrote {name} ({len(samples)/SR:.2f}s)")

def envelope(n, attack_s=0.005, release_s=0.04):
    out = []
    for i in range(n):
        t = i / SR
        total = n / SR
        a = min(1.0, t / attack_s) if attack_s > 0 else 1.0
        r = min(1.0, (total - t) / release_s) if release_s > 0 else 1.0
        out.append(a * min(1.0, max(0.0, r)) * (0.75 + 0.25 * math.cos(math.pi * t / total)))
    return out

def square(freq, dur, vol=0.5, duty=0.5):
    n = int(dur * SR)
    e = envelope(n)
    return [vol * (1.0 if (i * freq / SR) % 1.0 < duty else -1.0) * e[i] for i in range(n)]

def triangle(freq, dur, vol=0.5):
    n = int(dur * SR)
    e = envelope(n)
    out = []
    for i in range(n):
        ph = (i * freq / SR) % 1.0
        out.append(vol * (4 * abs(ph - 0.5) - 1) * e[i])
    return out

def sine(freq, dur, vol=0.5, sweep_to=None):
    n = int(dur * SR)
    e = envelope(n)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq + (sweep_to - freq) * (i / n) if sweep_to else freq
        phase += 2 * math.pi * f / SR
        out.append(vol * math.sin(phase) * e[i])
    return out

def noise(dur, vol=0.5, seed=1234, lowpass=False):
    random.seed(seed)
    n = int(dur * SR)
    e = envelope(n)
    out = []
    prev = 0.0
    for i in range(n):
        s = random.uniform(-1, 1)
        if lowpass:
            s = 0.6 * prev + 0.4 * s
            prev = s
        out.append(vol * s * e[i])
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    m = max(1e-6, max(abs(s) for s in out))
    if m > 0.95:
        out = [s * 0.95 / m for s in out]
    return out

def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out

def note(midi):
    return 440.0 * (2 ** ((midi - 69) / 12))

def seq(pattern, bpm, wave_fn, vol=0.4):
    """pattern: list of (midi_or_None, beats)"""
    beat = 60.0 / bpm
    out = []
    for midi, beats in pattern:
        if midi is None:
            out.extend([0.0] * int(beats * beat * SR))
        else:
            out.extend(wave_fn(note(midi), beats * beat * 0.92, vol))
            out.extend([0.0] * int(beats * beat * 0.08 * SR))
    return out

# ---------------- SFX ----------------
write_wav("tap.wav", square(880, 0.055, 0.35))
write_wav("confirm.wav", concat(square(659, 0.09, 0.4), square(988, 0.16, 0.4)))
write_wav("back.wav", concat(square(622, 0.08, 0.35), square(392, 0.14, 0.35)))
write_wav("select.wav", square(1250, 0.045, 0.4))
write_wav("tick.wav", square(1046, 0.07, 0.45))
write_wav("go.wav", concat(square(1568, 0.12, 0.45), square(2093, 0.3, 0.45)))
write_wav("mash.wav", concat(square(233, 0.03, 0.5), noise(0.03, 0.3, seed=7)))
write_wav("hit.wav", mix(square(139, 0.14, 0.6), noise(0.12, 0.4, seed=11, lowpass=True)))
write_wav("gem.wav", sine(1175, 0.16, 0.45, sweep_to=1760))
write_wav("bomb.wav", mix(sine(82, 0.3, 0.65), noise(0.25, 0.35, seed=13, lowpass=True)))
write_wav("spray.wav", noise(0.16, 0.4, seed=17, lowpass=True))
write_wav("fire_hit.wav", mix(square(196, 0.1, 0.4), noise(0.08, 0.3, seed=19, lowpass=True)))
write_wav("point.wav", concat(triangle(1319, 0.07, 0.5), triangle(1760, 0.12, 0.5)))
write_wav("win.wav", concat(square(523, 0.12, 0.42), square(659, 0.12, 0.42), square(784, 0.12, 0.42), square(1046, 0.35, 0.45)))
write_wav("lose.wav", concat(square(440, 0.15, 0.4), square(349, 0.15, 0.4), square(294, 0.32, 0.4)))
whistle = []
for i in range(int(0.6 * SR)):
    t = i / SR
    f = 1750 + 350 * math.sin(2 * math.pi * 14 * t)
    e = envelope(int(0.6 * SR))[i]
    whistle.append(0.45 * math.sin(2 * math.pi * f * t) * e)
write_wav("whistle.wav", whistle)

# ---------------- MUSIC LOOPS ----------------
# Lobby: bright I-V-vi-IV in C, 118 bpm
lobby_lead = seq([
    (72,1),(None,0.5),(76,0.5),(79,1),(None,1),
    (77,1),(None,0.5),(74,0.5),(76,2),
    (72,1),(None,0.5),(76,0.5),(79,1),(None,1),
    (81,1),(79,1),(76,2),
    (72,1),(None,0.5),(76,0.5),(79,1),(None,1),
    (76,1),(None,0.5),(74,0.5),(71,1),(None,1),
    (72,1),(74,1),(76,1),(79,1),
    (84,2),(None,2),
], 118, square, 0.32)
lobby_bass = seq([
    (36,2),(43,2),(45,2),(41,2),
    (36,2),(43,2),(45,2),(41,2),
], 118, triangle, 0.5)
write_wav("music_lobby.wav", mix(lobby_lead, lobby_bass))

# Game: driving A minor, 128 bpm
game_lead = seq([
    (69,0.5),(69,0.5),(72,1),(74,0.5),(72,0.5),(69,1),
    (67,0.5),(67,0.5),(71,1.5),(None,0.5),
    (69,0.5),(69,0.5),(72,1),(76,0.5),(74,0.5),(72,1),
    (74,1),(71,1),(67,2),
    (69,0.5),(69,0.5),(72,1),(74,0.5),(72,0.5),(69,1),
    (67,0.5),(67,0.5),(71,1),(72,1),(None,1),
    (76,1),(74,1),(72,1),(71,1),
    (69,3),(None,1),
], 128, square, 0.3)
game_bass = seq([
    (33,1),(33,1),(36,1),(36,1),(40,1),(40,1),(36,1),(36,1),
    (33,1),(33,1),(36,1),(36,1),(40,1),(40,1),(43,1),(43,1),
], 128, triangle, 0.55)
write_wav("music_game.wav", mix(game_lead, game_bass))

# Podium: triumphant C-F-G fanfare loop, 112 bpm
podium_lead = seq([
    (72,1),(76,1),(79,1),(84,2),(None,0.5),
    (81,0.5),(79,1),(76,2),(None,1),
    (77,1),(81,1),(84,1),(86,2),(None,0.5),
    (84,0.5),(79,1),(84,2),(None,1),
    (79,1),(77,1),(76,1),(74,1),(72,1),(74,1),(76,2),(None,1),
], 112, square, 0.34)
podium_bass = seq([
    (36,4),(41,4),(43,4),(36,4),
], 112, triangle, 0.5)
write_wav("music_podium.wav", mix(podium_lead, podium_bass))

print("done")
