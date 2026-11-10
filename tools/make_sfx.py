"""Synthesizes the self-made sound effects (CC0): boing (bounce pad), splash, pop (gas canister), rotor (helicopter),
ouch (easter egg: a box bonks the courier's helmet).
    python3 tools/make_sfx.py
"""
import math, random, struct, wave

RATE = 44100


def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def boing(dur=0.45):
    out, ph = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        f = 180 + 260 * math.exp(-t * 9) + 40 * math.sin(t * 2 * math.pi * 22) * math.exp(-t * 4)
        ph += 2 * math.pi * f / RATE
        out.append(0.8 * math.sin(ph) * math.exp(-t * 6) * min(1, t * 200))
    return out


def splash(dur=0.6):
    random.seed(7)
    out, lp = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        lp += (random.uniform(-1, 1) - lp) * (0.25 * math.exp(-t * 3) + 0.03)
        out.append(2.2 * lp * math.exp(-t * 5) * min(1, t * 80))
    return out


def pop(dur=0.5):
    random.seed(11)
    out, lp = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        lp += (random.uniform(-1, 1) - lp) * 0.5
        hiss = lp * 0.6 * math.exp(-t * 4)
        thump = math.sin(2 * math.pi * (90 - 50 * t) * t) * math.exp(-t * 18)
        out.append((hiss + thump) * min(1, t * 400))
    return out


def rotor(dur=1.6, rate=13.0):
    """Helicopter blades: filtered noise chopped into whumps, with a low engine hum."""
    random.seed(23)
    out, lp, lp2 = [], 0.0, 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        lp += (random.uniform(-1, 1) - lp) * 0.08
        lp2 += (lp - lp2) * 0.2
        ph = (t * rate) % 1.0
        chop = math.exp(-ph * 9.0)
        hum = 0.25 * math.sin(2 * math.pi * 62 * t) + 0.12 * math.sin(2 * math.pi * 124 * t)
        env = min(1, t * 6) * min(1, (dur - t) * 4)
        out.append((3.2 * lp2 * chop + hum * (0.4 + 0.6 * chop)) * env)
    return out


def _reso(x, f, bw, st):
    """Two-pole resonator (one formant). st = [y1, y2]."""
    r = math.exp(-math.pi * bw / RATE)
    c = 2 * r * math.cos(2 * math.pi * f / RATE)
    y = (1 - r) * x + c * st[0] - r * r * st[1]
    st[1], st[0] = st[0], y
    return y


def ouch(dur=0.62):
    """A plastic helmet 'tok' followed by a cartoony falling "ow!" (formant voice, a -> u)."""
    out, ph = [], 0.0
    s1, s2, s3 = [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]
    v0 = 0.05  # the voice starts right after the bonk
    for i in range(int(RATE * dur)):
        t = i / RATE
        tok = math.sin(2 * math.pi * 1250 * t) * math.exp(-t * 70) * 0.7
        tok += math.sin(2 * math.pi * 520 * t) * math.exp(-t * 45) * 0.5
        v = 0.0
        if t >= v0:
            u = (t - v0) / (dur - v0)
            f0 = 360 - 170 * u + 18 * math.sin(2 * math.pi * 7 * t) * u  # pitch falls, a little wobble
            ph = (ph + f0 / RATE) % 1.0
            src = 1.0 - 2.0 * ph  # sawtooth "glottis"
            k = min(1.0, u * 1.6)
            f1, f2, f3 = 820 - 440 * k, 1250 - 450 * k, 2600 - 300 * k  # "ah" -> "oo"
            v = _reso(src, f1, 90, s1) * 1.0 + _reso(src, f2, 110, s2) * 0.55 + _reso(src, f3, 160, s3) * 0.2
            v *= min(1.0, (t - v0) * 40) * min(1.0, (dur - t) * 6) * 2.2
        out.append(tok + v)
    peak = max(abs(x) for x in out)
    return [x / peak * 0.85 for x in out]


if __name__ == "__main__":
    write("audio/v2/rotor.wav", rotor())
    write("audio/v2/boing.wav", boing())
    write("audio/v2/splash.wav", splash())
    write("audio/v2/pop.wav", pop())
    write("audio/v2/ouch.wav", ouch())
