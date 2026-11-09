#!/usr/bin/env python3
"""Synthesizes every sound effect and the music loop of «Гараж на розі».

Run from the project folder: python3 tools/make_sfx.py
Writes 16-bit mono WAV files to assets/sfx/. Deterministic (fixed seeds).
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, curve=4.0):
    t = np.arange(n) / SR
    att = np.clip(t / max(a, 1e-4), 0, 1)
    dec = np.exp(-np.maximum(t - a, 0) * curve / max(d, 1e-4))
    return att * dec


def tone(freq, dur, kind="sine", a=0.005, d=0.3, curve=4.0, vib=0.0):
    t = t_axis(dur)
    ph = 2 * np.pi * freq * t + vib * np.sin(2 * np.pi * 5 * t)
    if kind == "sine":
        w = np.sin(ph)
    elif kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == "square":
        w = np.sign(np.sin(ph)) * 0.6
    elif kind == "saw":
        w = 2 * ((freq * t) % 1.0) - 1
    else:
        w = np.sin(ph)
    return w * env(len(t), a, d, curve)


def bell(freq, dur, d=0.6):
    t = t_axis(dur)
    w = (np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t * 6)
         + 0.25 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 12))
    return w * env(len(t), 0.002, d, 3.0)


def noise(dur, color="white"):
    n = rng.standard_normal(int(SR * dur))
    if color == "brown":
        n = np.cumsum(n)
        n = n - np.convolve(n, np.ones(200) / 200, mode="same")
        n /= np.max(np.abs(n)) + 1e-9
    elif color == "pink":
        b = np.array([0.049922035, -0.095993537, 0.050612699, -0.004408786])
        a = np.array([1, -2.494956002, 2.017265875, -0.522189400])
        n = lfilter(b, a, n)
        n /= np.max(np.abs(n)) + 1e-9
    return n


def lfilter(b, a, x):
    y = np.zeros_like(x)
    for i in range(len(x)):
        acc = 0.0
        for j in range(len(b)):
            if i - j >= 0:
                acc += b[j] * x[i - j]
        for j in range(1, len(a)):
            if i - j >= 0:
                acc -= a[j] * y[i - j]
        y[i] = acc / a[0]
    return y


def lowpass(x, cutoff):
    # one-pole low-pass
    rc = 1.0 / (2 * np.pi * cutoff)
    alpha = (1 / SR) / (rc + 1 / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts, length=None):
    n = length or max(len(p[1]) + int(p[0] * SR) for p in parts)
    out = np.zeros(n)
    for off, sig in parts:
        s = int(off * SR)
        e = min(n, s + len(sig))
        out[s:e] += sig[: e - s]
    return out


def click(dur=0.03, f=2500, gain=1.0):
    n = noise(dur) * env(int(SR * dur), 0.0005, dur * 0.4, 6)
    return highpass(n, f) * gain + tone(f * 0.6, dur, d=dur * 0.3) * 0.3 * gain


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * gain
    fade = min(len(x), int(0.004 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def karplus(freq, dur, damp=0.996, bright=0.5):
    n = int(SR * dur)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    buf = lowpass(buf, 2000 + 4000 * bright) if p > 4 else buf
    out = np.zeros(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % p
        buf[idx] = damp * 0.5 * (buf[idx] + buf[nxt])
        idx = nxt
    return out * env(n, 0.002, dur, 1.2)


def note(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    octave = int(name[-1])
    key = name[:-1]
    return 440.0 * 2 ** ((names[key] + (octave - 4) * 12) / 12)


def main():
    # interface
    save("pop", mix((0, tone(880, 0.08, "sine", d=0.04)), (0, tone(1320, 0.06, d=0.03) * 0.4)), 0.5)
    save("click", mix((0, click(0.025, 3000)), (0.012, click(0.02, 1800, 0.6))), 0.7)
    save("snap", mix((0, click(0.02, 4000)), (0.0, tone(180, 0.12, d=0.05) * 0.8), (0.01, click(0.03, 1500, 0.8))), 0.85)
    save("ok", mix((0, bell(1046, 0.5, 0.3) * 0.6), (0.09, bell(1568, 0.6, 0.35) * 0.5)), 0.5)
    save("found", mix((0, bell(784, 0.5, 0.3)), (0.11, bell(1175, 0.7, 0.4))), 0.6)
    save("success", mix((0, bell(784, 0.9, 0.5)), (0.12, bell(988, 0.9, 0.5)), (0.24, bell(1175, 1.2, 0.7)), (0.36, bell(1568, 1.4, 0.8) * 0.7)), 0.7)
    coin = mix((0, bell(2093, 0.4, 0.15)), (0.05, bell(2637, 0.4, 0.15) * 0.7))
    save("coin", coin, 0.55)
    cash = mix(*[(i * 0.045, bell(1800 + 400 * ((i * 7) % 5), 0.35, 0.12) * (0.9 - i * 0.07)) for i in range(9)])
    save("cash", cash, 0.6)
    save("tip", mix(*[(i * 0.06, bell(2349 * (1 + i * 0.12), 0.3, 0.15) * 0.6) for i in range(4)]), 0.45)
    save("buy", mix((0, tone(110, 0.25, d=0.1) * 1.0), (0.0, noise(0.08) * env(int(SR * 0.08), 0.001, 0.03) * 0.6),
                    (0.12, bell(880, 0.7, 0.4) * 0.6), (0.22, bell(1320, 0.8, 0.5) * 0.5)), 0.7)
    save("whoosh", lowpass(noise(0.45), 1800) * np.sin(np.linspace(0, np.pi, int(SR * 0.45))) ** 2, 0.35)
    save("photo", mix((0, click(0.02, 3000)), (0.06, click(0.05, 1200, 0.8)), (0.0, lowpass(noise(0.15), 3000) * env(int(SR * 0.15), 0.001, 0.08) * 0.5)), 0.6)
    # repair sounds
    flick = np.zeros(int(SR * 0.6))
    for i in range(7):
        s = int(rng.uniform(0, 0.5) * SR)
        b = tone(120, 0.06, "saw", d=0.04) * 0.6 + noise(0.06) * env(int(SR * 0.06), 0.001, 0.02) * 0.5
        flick[s:s + len(b)] += b
    save("flicker", flick, 0.55)
    save("tick", click(0.015, 3500, 0.8), 0.45)
    t = t_axis(0.5)
    boing = np.sin(2 * np.pi * (180 + 160 * np.exp(-t * 6)) * t + 3 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 3)) * env(len(t), 0.003, 0.4, 3)
    save("spring", boing, 0.6)
    rat = np.zeros(int(SR * 0.55))
    for i in range(10):
        s = int((i * 0.05 + rng.uniform(0, 0.015)) * SR)
        b = bell(900 + rng.uniform(-200, 400), 0.08, 0.03) * 0.6
        rat[s:s + len(b)] += b
    save("rattle", rat, 0.6)
    t = t_axis(0.55)
    sq = np.sin(2 * np.pi * (700 + 300 * np.sin(2 * np.pi * 2 * t)) * t) * 0.3 + lowpass(noise(0.55), 2500) * 0.7
    save("wiper", sq * np.sin(np.linspace(0, np.pi, len(t))) ** 1.5, 0.4)
    t = t_axis(0.35)
    horn = (np.sign(np.sin(2 * np.pi * 410 * t)) * 0.5 + np.sign(np.sin(2 * np.pi * 515 * t)) * 0.4)
    horn = lowpass(horn, 2500) * env(len(t), 0.01, 0.6, 1.0)
    save("beep", horn, 0.55)
    save("thud", lowpass(noise(0.2), 300) * env(int(SR * 0.2), 0.002, 0.08, 4) + tone(70, 0.2, d=0.1), 0.7)
    t = t_axis(0.5)
    creak = np.sin(2 * np.pi * (300 + 120 * np.sin(2 * np.pi * 3 * t)) * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 37 * t)))
    save("creak", lowpass(creak, 1500) * np.sin(np.linspace(0, np.pi, len(t))), 0.35)
    t = t_axis(1.0)
    motor = np.sin(2 * np.pi * 180 * t) * 0.4 + np.sign(np.sin(2 * np.pi * 360 * t)) * 0.15 + lowpass(noise(1.0), 900) * 0.3
    save("motor", motor * np.clip(t / 0.05, 0, 1), 0.35)
    save("latch", mix((0, click(0.02, 3500)), (0.03, click(0.03, 1200, 0.9)), (0.03, tone(240, 0.1, d=0.04) * 0.6)), 0.8)
    save("swish", lowpass(noise(0.3), 2500) * np.sin(np.linspace(0, np.pi, int(SR * 0.3))) ** 2, 0.4)
    # garage
    save("bell", mix((0, bell(1318, 1.2, 0.9)), (0.18, bell(1046, 1.4, 1.0))), 0.55)
    t = t_axis(2.2)
    rpm = 28 + 6 * np.sin(2 * np.pi * 0.7 * t)
    phase = np.cumsum(rpm) / SR
    pulses = (np.sin(2 * np.pi * phase) > 0.6).astype(float)
    eng = lowpass(pulses * noise(2.2) * 0.6 + pulses * 0.8, 1200)
    save("engine", eng * np.clip(t / 0.15, 0, 1) * np.clip((2.2 - t) / 0.5, 0, 1), 0.5)
    t = t_axis(2.6)
    rpm = 16 + 4 * np.clip(t / 1.5, 0, 1)
    phase = np.cumsum(rpm) / SR
    car = lowpass(np.sin(2 * np.pi * phase * 2) * 0.7 + (np.sin(2 * np.pi * phase) > 0.3) * 0.5 + noise(2.6) * 0.2, 500)
    save("car", car * np.clip(t / 0.2, 0, 1) * np.clip((2.6 - t) / 0.6, 0, 1), 0.55)
    t = t_axis(1.6)
    gate = lowpass(noise(1.6), 700) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 14 * t))) * np.sin(np.linspace(0, np.pi, len(t))) ** 0.5
    save("gate", gate, 0.45)
    notes = ["C5", "E5", "G5", "C6", "E6", "G5", "C6", "E6"]
    fan = mix(*[(i * 0.16, bell(note(n), 1.6, 1.0) * 0.6) for i, n in enumerate(notes)], (1.2, bell(note("C6"), 2.4, 1.6) * 0.7), (1.2, bell(note("G5"), 2.4, 1.6) * 0.5))
    save("fanfare", fan, 0.7)
    # music: warm finger-picked loop, C - Am - F - G, 4 bars of 2 s
    bars = [["C3", "G3", "E4", "G4", "C4", "G4", "E4", "G3"],
            ["A2", "E3", "C4", "E4", "A3", "E4", "C4", "E3"],
            ["F2", "C3", "A3", "C4", "F3", "C4", "A3", "C3"],
            ["G2", "D3", "B3", "D4", "G3", "D4", "B3", "D3"]]
    beat = 0.25
    parts = []
    for bi, bar in enumerate(bars * 2):
        for ni, n in enumerate(bar):
            at = (bi * 8 + ni) * beat
            v = 0.55 if ni == 0 else 0.3
            parts.append((at, karplus(note(n), 1.6, 0.995, 0.4) * v))
    loop_len = int(len(bars) * 2 * 8 * beat * SR)
    music = mix(*parts, length=loop_len + int(1.6 * SR))
    tail = music[loop_len:]
    music = music[:loop_len]
    music[: len(tail)] += tail
    save("music", music, 0.5)
    # quiet garage ambience: distant street, soft hum
    t = t_axis(8.0)
    amb = lowpass(noise(8.0, "brown"), 400) * 0.6 + np.sin(2 * np.pi * 50 * t) * 0.03
    amb[: int(SR * 0.5)] *= np.linspace(0, 1, int(SR * 0.5))
    amb[-int(SR * 0.5):] *= np.linspace(1, 0, int(SR * 0.5))
    save("ambience", amb, 0.25)


if __name__ == "__main__":
    main()
    print("written:", sorted(os.listdir(OUT)))
