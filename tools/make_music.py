"""Synthesize the Flick Freight background loop (CC0, no samples).

Usage: python3 tools/make_music.py audio/v2/music_loop.ogg
Pizzicato-style plucks + soft pad + light percussion, 104 BPM, 8 bars, seamless loop.
"""
import subprocess
import sys

import numpy as np

SR = 32000
BPM = 104
BEAT = 60.0 / BPM
BARS = 8
LEN = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def pluck(freq, dur, vol):
    t = np.arange(int(SR * dur)) / SR
    env = np.exp(-t * 9.0) * (1 - np.exp(-t * 400))
    w = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) * np.exp(-t * 6) + 0.12 * np.sin(6 * np.pi * freq * t) * np.exp(-t * 14)
    return vol * env * w


def pad(freqs, dur, vol):
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(1, t / 0.25) * np.minimum(1, (dur - t) / 0.3)
    w = sum(np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.7 * t)) for f in freqs) / len(freqs)
    return vol * env * w


def kick(vol):
    t = np.arange(int(SR * 0.18)) / SR
    f = 110 * np.exp(-t * 22) + 45
    return vol * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)


def hat(vol):
    t = np.arange(int(SR * 0.05)) / SR
    n = rng.standard_normal(len(t))
    n = np.diff(np.concatenate([[0], n]))  # crude high-pass
    return vol * n * np.exp(-t * 90)


out = np.zeros(LEN + SR)


def put(sig, at):
    i = int(at * SR)
    out[i:i + len(sig)] += sig


# C major: C - G - Am - F, twice; melody varies on the second pass
chords = [(48, [60, 64, 67]), (43, [59, 62, 67]), (45, [60, 64, 69]), (41, [60, 65, 69])]
mel_a = [72, 76, 79, 76, 74, 79, 74, 71, 72, 76, 81, 76, 77, 72, 69, 72]
mel_b = [79, 76, 72, 76, 79, 81, 79, 74, 76, 72, 69, 72, 77, 76, 74, 72]
for bar in range(BARS):
    t0 = bar * 4 * BEAT
    root, triad = chords[bar % 4]
    put(pad([midi(n) for n in triad], 4 * BEAT, 0.07), t0)
    for b in range(4):
        put(pluck(midi(root), 0.6, 0.30), t0 + b * BEAT)
        put(kick(0.35 if b in (0, 2) else 0.0), t0 + b * BEAT)
        put(hat(0.06), t0 + b * BEAT + BEAT / 2)
    mel = mel_a if bar < 4 else mel_b
    for k in range(4):
        n = mel[(bar % 4) * 4 + k]
        put(pluck(midi(n), 0.5, 0.17), t0 + k * BEAT)
        if k % 2 == 1:
            put(pluck(midi(triad[k % 3] + 12), 0.3, 0.07), t0 + k * BEAT + BEAT / 2)

# fold the tail back into the start so the loop is seamless
loop = out[:LEN].copy()
loop[: len(out) - LEN] += out[LEN:]
loop /= np.max(np.abs(loop)) * 1.15
pcm = (loop * 32767).astype(np.int16).tobytes()
dst = sys.argv[1] if len(sys.argv) > 1 else "music_loop.ogg"
subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                "-c:a", "libvorbis", "-q:a", "3", dst], input=pcm, check=True)
print("wrote", dst, round(LEN / SR, 2), "s")
