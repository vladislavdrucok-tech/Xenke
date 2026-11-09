"""Synthesises every sound of Deep Bounce (no samples). Effects: 22 kHz mono WAV. Music: a seamless cave loop
encoded to OGG Vorbis with ffmpeg.   python3 tools/audio/make_audio.py"""
import os
import subprocess
import numpy as np
import soundfile as sf
from scipy import signal

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def env(n, a=0.002, d=0.1, sr=SR, curve=4.0):
    x = np.arange(n) / sr
    e = np.minimum(1.0, x / max(a, 1e-4)) * np.exp(-np.maximum(0, x - a) * curve / max(d, 1e-4))
    return e


def bp(x, lo, hi, sr=SR, order=2):
    b, a = signal.butter(order, [lo / (sr / 2), min(hi / (sr / 2), 0.99)], 'band')
    return signal.lfilter(b, a, x)


def lp(x, f, sr=SR, order=2):
    b, a = signal.butter(order, min(f / (sr / 2), 0.99), 'low')
    return signal.lfilter(b, a, x)


def hp(x, f, sr=SR, order=2):
    b, a = signal.butter(order, f / (sr / 2), 'high')
    return signal.lfilter(b, a, x)


def noise(d, sr=SR):
    return rng.standard_normal(int(d * sr))


def sweep(f0, f1, d, sr=SR):
    x = t(d, sr)
    f = f0 * (f1 / f0) ** (x / d)
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, ms=6, sr=SR):
    n = int(ms * sr / 1000)
    if n > 0 and len(x) > 2 * n:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def save(name, x, peak=0.9):
    x = fade(norm(x, peak))
    sf.write(os.path.join(OUT, name + '.wav'), x.astype(np.float32), SR, subtype='PCM_16')


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def bell(freq, d, partials=((1, 1.0), (2.76, 0.35), (5.4, 0.15)), decay=3.0):
    x = t(d)
    out = np.zeros_like(x)
    for r, a in partials:
        out += a * np.sin(2 * np.pi * freq * r * x) * np.exp(-x * decay * (1 + r * 0.6))
    return out * np.minimum(1, x / 0.003)


def effects():
    # cannon shot: low thump, metal ring, air puff
    d = 0.32
    thump = sweep(170, 70, d) * env(int(d * SR), 0.002, 0.07)
    ring = bell(880, d, ((1, 0.5), (2.4, 0.2)), decay=14) * 0.4
    puff = lp(noise(d), 1800) * env(int(d * SR), 0.001, 0.03) * 0.6
    save('shot', mix(thump, ring, puff), 0.7)
    # ball touching a wall: tiny stone tap
    d = 0.06
    save('tick', bp(noise(d), 1800, 5200) * env(int(d * SR), 0.0005, 0.012), 0.5)
    # ball hitting a stone: dry clack with a short body
    d = 0.12
    clack = bp(noise(d), 900, 3800, order=3) * env(int(d * SR), 0.0005, 0.022)
    body = np.sin(2 * np.pi * 240 * t(d)) * env(int(d * SR), 0.001, 0.03) * 0.5
    save('hit', mix(clack, body), 0.75)
    # heavy ball: deeper knock and a little crunch
    d = 0.22
    knock = sweep(140, 60, d) * env(int(d * SR), 0.001, 0.06)
    crunch = bp(noise(d), 300, 2200, order=2) * env(int(d * SR), 0.001, 0.05) * 0.8
    save('hit_heavy', mix(knock, crunch), 0.85)
    # stone breaking: granular crumble over a low boom
    d = 0.55
    out = np.zeros(int(d * SR))
    for i in range(26):
        st = int(abs(rng.normal(0, 0.09)) * SR)
        gd = rng.uniform(0.01, 0.05)
        g = bp(noise(gd), rng.uniform(300, 900), rng.uniform(1500, 4500)) * env(int(gd * SR), 0.0005, gd * 0.4)
        g *= np.exp(-st / SR * 5) * rng.uniform(0.4, 1.0)
        e = min(len(out), st + len(g))
        out[st:e] += g[:e - st]
    boom = sweep(110, 45, d) * env(int(d * SR), 0.002, 0.12) * 0.9
    save('break', mix(out, boom), 0.9)
    # crystal collected: two clear partials
    d = 0.45
    ch = bell(1320, d, ((1, 1.0), (1.5, 0.5), (3.0, 0.2)), decay=7)
    sh = hp(noise(d), 6000) * env(int(d * SR), 0.001, 0.08) * 0.08
    save('gem', mix(ch, sh), 0.55)
    # electric zap: buzzing saw with crackle
    d = 0.22
    x = t(d)
    f = 95 + 60 * np.sin(2 * np.pi * 37 * x) + rng.standard_normal(len(x)).cumsum() * 0.4
    saw = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * 0.6
    crack = hp(noise(d), 3000) * (rng.random(len(x)) < 0.08) * 1.5
    z = bp(saw + crack, 200, 7000) * env(len(x), 0.002, 0.07)
    save('zap', z, 0.7)
    # stones shifting up one row: a short grinding rumble
    d = 0.5
    r = lp(noise(d), 260) * np.sin(np.pi * np.minimum(1, t(d) / d)) ** 1.5
    grit = bp(noise(d), 600, 2400) * np.sin(np.pi * np.minimum(1, t(d) / d)) ** 3 * 0.15
    save('shift', mix(r, grit), 0.55)
    # danger: two low pulses
    d = 0.5
    x = t(d)
    tone = np.sin(2 * np.pi * 196 * x) * (np.sin(2 * np.pi * 4 * x) > 0) * np.exp(-x * 2)
    save('danger', lp(tone, 1200), 0.6)
    # game over: falling minor notes over rumble
    d = 1.6
    notes = [(0.0, 392), (0.22, 311), (0.44, 262), (0.66, 196)]
    out = np.zeros(int(d * SR))
    for st, fr in notes:
        b = bell(fr, d - st, ((1, 1.0), (2, 0.3), (3, 0.1)), decay=2.2)
        s0 = int(st * SR)
        out[s0:s0 + len(b)] += b[:len(out) - s0]
    rum = lp(noise(d), 120) * np.exp(-t(d) * 1.5) * 2.0
    save('gameover', mix(out, rum), 0.8)
    # upgrade: rising bells
    d = 0.9
    out = np.zeros(int(d * SR))
    for i, fr in enumerate([523, 659, 784, 1047]):
        b = bell(fr, d - i * 0.08, decay=4)
        s0 = int(i * 0.08 * SR)
        out[s0:s0 + len(b)] += b * 0.6
    save('upgrade', out, 0.7)
    # interface click
    d = 0.05
    save('click', bp(noise(d), 1500, 4000) * env(int(d * SR), 0.0005, 0.008) + np.sin(2 * np.pi * 1200 * t(d)) * env(int(d * SR), 0.0005, 0.01) * 0.3, 0.45)
    # purchase
    d = 0.8
    out = np.zeros(int(d * SR))
    for i, fr in enumerate([988, 1319, 1976]):
        b = bell(fr, d - i * 0.06, decay=5)
        s0 = int(i * 0.06 * SR)
        out[s0:s0 + len(b)] += b * 0.6
    save('buy', out, 0.65)
    # refusal
    d = 0.22
    save('deny', lp(signal.square(2 * np.pi * 110 * t(d)) * env(int(d * SR), 0.002, 0.08), 900), 0.45)
    # new run: soft whoosh into a chime
    d = 0.8
    wh = bp(noise(d), 300, 3000) * np.sin(np.pi * np.minimum(1, t(d) / 0.5)) ** 2 * (t(d) < 0.5) * 0.5
    ch = np.zeros(int(d * SR))
    b = bell(784, 0.5, decay=5)
    ch[int(0.3 * SR):int(0.3 * SR) + len(b)] += b[:len(ch) - int(0.3 * SR)]
    save('start', mix(wh, ch), 0.6)


def music():
    """Calm cave loop: low drone, slow pentatonic plucks, drips, a soft pad. 72 s, loops seamlessly."""
    sr = 32000
    bpm = 80
    beat = 60 / bpm
    bars = 24
    d = bars * 4 * beat          # 72 s
    n = int(d * sr)
    x = np.arange(n) / sr
    out = np.zeros(n)
    # drone on D with slow movement
    for f, a in [(73.42, 0.22), (110.0, 0.12), (146.83, 0.06)]:
        lfo = 1 + 0.003 * np.sin(2 * np.pi * x / d * 3)
        out += a * np.sin(2 * np.pi * f * lfo * x) * (0.7 + 0.3 * np.sin(2 * np.pi * x / d * 2 + f))
    # pad chords (Dm, Bb, F, C), one per 6 bars, slow attack
    chords = [[146.83, 174.61, 220.0], [116.54, 146.83, 174.61], [174.61, 220.0, 261.63], [130.81, 164.81, 196.0]]
    seg = d / 4
    for i, ch in enumerate(chords):
        s0, s1 = int(i * seg * sr), int((i + 1) * seg * sr)
        xs = np.arange(s1 - s0) / sr
        envp = np.sin(np.pi * xs / seg) ** 1.2
        for f in ch:
            out[s0:s1] += 0.045 * envp * (np.sin(2 * np.pi * f * xs) + 0.3 * np.sin(2 * np.pi * f * 2.003 * xs))
    # plucks: D minor pentatonic, sparse, deterministic pattern
    scale = [293.66, 349.23, 392.0, 440.0, 523.25, 587.33, 698.46]
    prng = np.random.default_rng(11)
    step = beat / 2
    for k in range(int(d / step)):
        if prng.random() < 0.34:
            f = scale[prng.integers(0, len(scale))] * (0.5 if prng.random() < 0.3 else 1.0)
            st = int(k * step * sr)
            ln = int(1.6 * sr)
            xs = np.arange(ln) / sr
            pl = (np.sin(2 * np.pi * f * xs) + 0.25 * np.sin(2 * np.pi * f * 3.01 * xs)) * np.exp(-xs * 3.2) * np.minimum(1, xs / 0.004)
            vol = prng.uniform(0.05, 0.11)
            idx = (st + np.arange(ln)) % n          # wraps: the loop point stays seamless
            np.add.at(out, idx, pl * vol)
    # water drips with a small echo
    for k in range(int(d / 2.5)):
        if prng.random() < 0.6:
            st = int((k * 2.5 + prng.uniform(0, 2.0)) * sr)
            ln = int(0.25 * sr)
            xs = np.arange(ln) / sr
            f0 = prng.uniform(900, 1500)
            dr = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.8 * np.exp(-xs * 30))) / sr) * np.exp(-xs * 22) * 0.05
            for echo, g in [(0, 1.0), (0.18, 0.35), (0.37, 0.15)]:
                idx = (st + int(echo * sr) + np.arange(ln)) % n
                np.add.at(out, idx, dr * g)
    # air
    air = lp(np.random.default_rng(3).standard_normal(n), 500, sr) * 0.03
    out += air
    # gentle reverb-ish smear
    ir_len = int(1.2 * sr)
    ir = np.random.default_rng(5).standard_normal(ir_len) * np.exp(-np.arange(ir_len) / sr * 3.5) * 0.02
    wet = signal.fftconvolve(np.concatenate([out, out[:ir_len]]), ir)[:n + ir_len]
    wet[:ir_len] += wet[n:n + ir_len]
    out = out + wet[:n] * 0.8
    out = norm(out, 0.7)
    stereo = np.stack([out, np.roll(out, int(0.011 * sr))], axis=1)
    wav = os.path.join('/tmp', 'db_music.wav')
    sf.write(wav, stereo.astype(np.float32), sr, subtype='PCM_16')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', os.path.join(OUT, 'music.ogg')], check=True)


if __name__ == '__main__':
    effects()
    music()
    print('ok', sorted(os.listdir(OUT)))
