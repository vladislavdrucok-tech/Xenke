#!/usr/bin/env python3
"""Synthesises all sounds and music of Time Post (original, license-free).

Run from the project root:  python3 tools/make_audio.py
Output: assets/audio/*.wav, mono 16-bit 22050 Hz.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(404)


def t_of(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, total=None):
    total = total or n / SR
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    rel = np.clip((total - t) / max(r, 1e-4), 0, 1)
    return e * rel


def exp_env(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sine(f, d, phase=0):
    t = t_of(d)
    if callable(f):
        ph = 2 * np.pi * np.cumsum(f(t)) / SR
    else:
        ph = 2 * np.pi * f * t
    return np.sin(ph + phase)


def square(f, d, duty=0.5):
    t = t_of(d)
    ph = (np.cumsum(f(t)) / SR) if callable(f) else f * t
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def tri(f, d):
    t = t_of(d)
    ph = (f * t) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_fast(x, a):
    # one-pole lowpass via scipy-free recursion in chunks (vectorised enough)
    from itertools import accumulate
    out = list(accumulate(x, lambda acc, v: acc + a * (v - acc)))
    return np.array(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def save(name, x, gain=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    # tiny fades to avoid clicks
    f = min(64, len(x) // 4)
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# --------------------------------------------------------------------- SFX

def sfx():
    d = 0.24
    n = noise(d)
    sweep = lowpass_fast(n, 0.25) * env(len(n), 0.03, 0.15)
    save("swipe", sweep * np.linspace(0.6, 1.0, len(n)), 0.55)

    d = 0.14
    thump = sine(lambda t: 140 * np.exp(-t * 18) + 50, d) * exp_env(int(SR * d), 30)
    click = noise(0.02) * exp_env(int(SR * 0.02), 200)
    save("stamp", mix(thump, click * 0.6), 0.9)

    def chime(notes, step, dur, wave_fn=sine, name="ok", gain=0.6):
        parts = []
        for i, m in enumerate(notes):
            s = np.zeros(int(SR * (step * i)))
            tone = wave_fn(note(m), dur) * exp_env(int(SR * dur), 9)
            tone += 0.3 * sine(note(m) * 2, dur) * exp_env(int(SR * dur), 14)
            parts.append(np.concatenate([s, tone]))
        save(name, mix(*parts), gain)

    chime([76, 83], 0.06, 0.3, name="ok")
    chime([79, 83, 86, 91], 0.055, 0.32, name="combo", gain=0.6)
    chime([88, 95], 0.04, 0.16, name="coin", gain=0.45)
    chime([72, 76, 79, 84, 88], 0.09, 0.6, name="levelup", gain=0.65)
    chime([84, 79, 76], 0.12, 0.7, name="bell", gain=0.55)

    d = 0.32
    buzz = square(lambda t: 160 - 70 * t / d, d, 0.4) * env(int(SR * d), 0.005, 0.12)
    save("error", lowpass_fast(buzz, 0.3), 0.55)

    d = 0.45
    port = sine(lambda t: 300 + 500 * t / d + 40 * np.sin(t * 60), d) * env(int(SR * d), 0.02, 0.25)
    save("portal", mix(port, 0.25 * lowpass_fast(noise(d), 0.08)), 0.5)

    d = 0.3
    tube = lowpass_fast(noise(d), 0.12) * exp_env(int(SR * d), 10)
    pop = sine(lambda t: 600 * np.exp(-t * 10) + 120, 0.12) * exp_env(int(SR * 0.12), 25)
    save("tube", mix(tube, pop * 0.7), 0.6)

    d = 0.4
    clank = mix(sine(220, d) * exp_env(int(SR * d), 12), 0.6 * sine(347, d) * exp_env(int(SR * d), 15),
                0.4 * sine(511, d) * exp_env(int(SR * d), 20))
    hiss = lowpass_fast(noise(d), 0.5) * env(int(SR * d), 0.1, 0.25) * 0.3
    save("quarantine", mix(clank, hiss), 0.6)

    d = 0.045
    save("click", square(1200, d, 0.5) * exp_env(int(SR * d), 90), 0.35)
    save("blip", sine(900, 0.03) * exp_env(int(SR * 0.03), 80), 0.3)
    save("tick", sine(1800, 0.03) * exp_env(int(SR * 0.03), 120), 0.35)

    d = 0.28
    whirr = square(lambda t: 90 + 40 * np.sin(t * 40), d, 0.3) * env(int(SR * d), 0.02, 0.1)
    save("lift", lowpass_fast(whirr, 0.15), 0.4)

    d = 0.7
    alarm = mix(*[np.concatenate([np.zeros(int(SR * 0.18 * i)), sine(note(m), 0.16) * exp_env(int(SR * 0.16), 8)])
                  for i, m in enumerate([81, 77, 81, 77])])
    save("event", alarm, 0.55)

    d = 0.45
    meow = sine(lambda t: 500 + 350 * np.sin(np.pi * t / d) - 150 * t / d, d) * env(int(SR * d), 0.04, 0.2)
    meow += 0.3 * sine(lambda t: 1000 + 700 * np.sin(np.pi * t / d), d) * env(int(SR * d), 0.04, 0.2)
    save("meow", lowpass_fast(meow, 0.5), 0.5)

    d = 0.6
    fail = mix(*[np.concatenate([np.zeros(int(SR * 0.15 * i)), tri(note(m), 0.3) * exp_env(int(SR * 0.3), 6)])
                 for i, m in enumerate([67, 63, 60])])
    save("fail", fail, 0.55)

    # Conveyor hum: seamless 1 s loop (integer number of cycles).
    d = 1.0
    hum = 0.5 * sine(60, d) + 0.25 * sine(120, d) + 0.15 * square(30, d, 0.2)
    clatter = np.zeros(int(SR * d))
    for k in range(8):
        i = int(SR * d * k / 8)
        clatter[i:i + 200] += np.sin(np.arange(200) / 200 * np.pi) * 0.3 * rng.uniform(0.5, 1)
    save("belt_loop", lowpass_fast(hum + clatter, 0.2), 0.35)


# -------------------------------------------------------------------- music

def drum_kick(d=0.25):
    return sine(lambda t: 110 * np.exp(-t * 25) + 45, d) * exp_env(int(SR * d), 14)


def drum_hat(d=0.05):
    return (noise(d) - lowpass_fast(noise(d), 0.3)) * exp_env(int(SR * d), 70)


def drum_snare(d=0.18):
    return mix(lowpass_fast(noise(d), 0.6) * exp_env(int(SR * d), 22), 0.4 * sine(190, d) * exp_env(int(SR * d), 30))


def render_song(bpm, chords, melody_scale, bars, seed, style):
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    total = bars * 4 * beat
    out = np.zeros(int(SR * total) + SR)

    def put(x, at, gain=1.0):
        i = int(at * SR)
        j = min(len(out), i + len(x))
        out[i:j] += x[:j - i] * gain

    kick, hat, snare = drum_kick(), drum_hat(), drum_snare()
    motif = [r.integers(0, len(melody_scale)) for _ in range(8)]
    for bar in range(bars):
        root = chords[bar % len(chords)]
        t0 = bar * 4 * beat
        # pad chord (soft triangle, slow attack)
        for iv in (0, 4 if style != "minor" else 3, 7):
            d = 4 * beat
            pad = tri(note(root + iv), d) * env(int(SR * d), 0.3, 0.6)
            put(pad, t0, 0.09)
        # bass
        for b in range(4):
            d = beat * 0.9
            bass_note = root - 12 + (7 if b == 2 else 0)
            put(tri(note(bass_note), d) * exp_env(int(SR * d), 4), t0 + b * beat, 0.32)
        # drums
        if style != "calm":
            for b in range(4):
                if b in (0, 2):
                    put(kick, t0 + b * beat, 0.5)
                if b in (1, 3):
                    put(snare, t0 + b * beat, 0.18)
                for h in range(2):
                    put(hat, t0 + (b + h * 0.5) * beat, 0.1)
        else:
            put(kick, t0, 0.25)
            for b in range(4):
                put(hat, t0 + (b + 0.5) * beat, 0.05)
        # melody: motif with variation, square lead
        if bar % 8 < 6 or style == "calm":
            for k in range(8):
                if (bar + k) % 3 == 0 and r.random() < 0.35:
                    continue
                idx = (motif[k] + (bar // 2) % 3) % len(melody_scale)
                m = melody_scale[idx] + (12 if style == "upbeat" and k % 4 == 0 else 0)
                d = beat * 0.45
                tone = (square(note(m), d, 0.25) * 0.5 + sine(note(m), d)) * exp_env(int(SR * d), 6)
                put(tone, t0 + k * beat * 0.5, 0.12 if style != "calm" else 0.09)
    # loop-friendly: cut to exact length, crossfade the tail into the head
    out = out[:int(SR * total)]
    return lowpass_fast(out, 0.55)


def music():
    pent = [72, 74, 76, 79, 81, 84, 86]
    save("music_menu", render_song(84, [60, 57, 53, 55], [n - 12 for n in pent], 16, 1, "calm"), 0.55)
    save("music_shift", render_song(118, [60, 55, 57, 53], pent, 16, 2, "upbeat"), 0.55)
    minor_pent = [69, 72, 74, 76, 79, 81]
    save("music_radio", render_song(96, [57, 53, 55, 52], minor_pent, 16, 3, "minor"), 0.5)


if __name__ == "__main__":
    sfx()
    music()
    print("audio files:", sorted(os.listdir(OUT)))
