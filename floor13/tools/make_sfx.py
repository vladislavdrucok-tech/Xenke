#!/usr/bin/env python3
"""Synthesizes all sound effects (WAV) and two music loops (OGG) for FLOOR 13."""
import os
import subprocess
import wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SFX = os.path.join(HERE, '..', 'assets', 'sfx')
MUS = os.path.join(HERE, '..', 'assets', 'music')
SR = 22050
rng = np.random.default_rng(13)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, total=None):
    """ADSR-ish envelope of n samples (times in seconds)."""
    e = np.zeros(n)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    i = 0
    if ai:
        e[:min(ai, n)] = np.linspace(0, 1, ai)[:n]
    i = ai
    if i < n:
        seg = min(di, n - i)
        e[i:i + seg] = np.linspace(1, s, di)[:seg]
        i += seg
    if i < n:
        e[i:] = s
    if ri and n > ri and s > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def expdec(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sq(f, t, duty=0.5):
    ph = (f * t) % 1.0 if np.isscalar(f) else np.cumsum(f / SR) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(f, t):
    ph = (f * t) % 1.0 if np.isscalar(f) else np.cumsum(f / SR) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def sine(f, t):
    if np.isscalar(f):
        return np.sin(2 * np.pi * f * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, k=0.2):
    return x - lowpass(x, k)


def write_wav(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * vol
    fade = min(len(x), 64)
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(SFX, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def blip(f, d, shape='sq', dec=30, duty=0.5):
    t = t_(d)
    w = sq(f, t, duty) if shape == 'sq' else (tri(f, t) if shape == 'tri' else sine(f, t))
    return w * expdec(len(t), dec)


def concat(*parts):
    return np.concatenate(parts)


def voice(base, n_syl, wobble=0.0, shape='sq', seed=0, speed=0.07):
    r = np.random.default_rng(seed)
    out = []
    for i in range(n_syl):
        f = base * (2 ** (r.integers(-3, 5) / 12))
        d = speed * r.uniform(0.8, 1.3)
        t = t_(d)
        fm = f * (1 + wobble * np.sin(2 * np.pi * 9 * t))
        w = (sq(fm, t, 0.3) if shape == 'sq' else tri(fm, t)) * env(len(t), 0.005, d * 0.9, 0.2, 0.01)
        out.append(lowpass(w, 0.35))
        out.append(np.zeros(int(SR * 0.012)))
    return np.concatenate(out)


def make_sfx():
    os.makedirs(SFX, exist_ok=True)
    write_wav('click', blip(1250, 0.04, 'sq', 60, 0.25), 0.4)
    write_wav('press', concat(blip(990, 0.035, 'sq', 50, 0.25), blip(1480, 0.05, 'sq', 45, 0.25)), 0.45)
    write_wav('unpress', concat(blip(740, 0.035, 'sq', 50, 0.25), blip(495, 0.06, 'sq', 40, 0.25)), 0.4)
    t = t_(0.16)
    write_wav('deny', sq(110, t, 0.5) * 0.6 + sq(116, t, 0.5) * 0.4, 0.35)
    # arrival bell
    t = t_(1.1)
    bell = (sine(1318.5, t) + 0.45 * sine(2637, t) + 0.25 * sine(3955, t) * expdec(len(t), 9)) * expdec(len(t), 3.5)
    write_wav('ding', bell, 0.55)
    # doors: filtered noise sweeps
    n = int(SR * 0.32)
    sweep = noise(n)
    ks = np.linspace(0.05, 0.35, n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += ks[i] * (sweep[i] - acc)
        y[i] = acc
    clank = np.zeros(n)
    clank[-int(SR * 0.06):] = blip(160, 0.06, 'sq', 60, 0.5) * 0.5
    write_wav('door_open', y * env(n, 0.04, 0.2, 0.3, 0.06) + clank, 0.35)
    write_wav('door_close', y[::-1] * env(n, 0.04, 0.2, 0.3, 0.06) + clank, 0.35)
    write_wav('coin', concat(blip(988, 0.05, 'sq', 25, 0.25), blip(1319, 0.16, 'sq', 18, 0.25)), 0.4)
    write_wav('coins_big', concat(*[blip(note(m), 0.06, 'sq', 22, 0.25) for m in (76, 79, 84, 88)],
                                  blip(note(91), 0.25, 'sq', 12, 0.25)), 0.4)
    # complaint: grumpy descending tone
    t = t_(0.42)
    f = np.linspace(330, 140, len(t))
    write_wav('complaint', lowpass(sq(f, t, 0.4), 0.3) * env(len(t), 0.01, 0.4, 0.0) + noise(len(t)) * 0.08 * expdec(len(t), 8), 0.5)
    t = t_(0.5)
    f = np.linspace(600, 180, len(t))
    write_wav('heart_break', concat(noise(int(SR * 0.04)) * 0.6, sq(f, t, 0.5) * expdec(len(t), 5)), 0.45)
    write_wav('board', lowpass(noise(int(SR * 0.05)), 0.4) * expdec(int(SR * 0.05), 60), 0.3)
    # voices
    write_wav('v_guest', voice(330, 4, seed=1), 0.35)
    write_wav('v_business', voice(196, 3, seed=2, speed=0.06), 0.35)
    write_wav('v_granny', voice(392, 4, wobble=0.05, seed=3, speed=0.09), 0.35)
    write_wav('v_kid', voice(620, 5, seed=4, speed=0.05), 0.33)
    t = t_(0.35)
    f = 700 + 300 * np.sin(np.pi * t / 0.35)
    write_wav('v_cat', lowpass(sq(f, t, 0.3), 0.25) * env(len(t), 0.03, 0.3, 0.0), 0.35)
    write_wav('v_rocker', voice(165, 3, seed=6, shape='sq', speed=0.08) + 0, 0.38)
    write_wav('v_robot', concat(*[blip(f, 0.05, 'sq', 5, 0.5) for f in (880, 660, 990, 550)]), 0.3)
    write_wav('v_couple', concat(voice(300, 2, seed=8), voice(480, 2, seed=9)), 0.35)
    write_wav('v_inspector', voice(150, 3, seed=10, speed=0.09), 0.38)
    write_wav('v_bellhop', voice(260, 3, seed=11), 0.35)
    t = t_(0.7)
    f = 330 * (1 + 0.04 * np.sin(2 * np.pi * 6 * t)) * np.linspace(1, 0.7, len(t))
    write_wav('v_ghost', sine(f, t) * env(len(t), 0.15, 0.4, 0.4, 0.15), 0.35)
    # events and jingles
    write_wav('event_good', concat(*[blip(note(m), 0.08, 'sq', 15, 0.25) for m in (72, 76, 79)],
                                   blip(note(84), 0.3, 'sq', 8, 0.25)), 0.38)
    t = t_(0.6)
    f = 700 + 250 * np.sign(np.sin(2 * np.pi * 5 * t))
    write_wav('event_bad', sq(f, t, 0.5) * env(len(t), 0.01, 0.55, 0.0), 0.3)
    write_wav('shift_start', concat(*[blip(note(m), 0.12, 'tri', 8) for m in (60, 64, 67)],
                                    blip(note(72), 0.5, 'tri', 4)) + 0, 0.5)
    seq = [(72, .1), (76, .1), (79, .1), (84, .18), (79, .1), (84, .45)]
    write_wav('shift_end', concat(*[blip(note(m), d, 'sq', 7, 0.3) for m, d in seq]), 0.38)
    seq = [(67, .25), (66, .25), (65, .25), (64, .7)]
    parts = []
    for m, d in seq:
        tt = t_(d)
        ff = note(m) * (1 + 0.02 * np.sin(2 * np.pi * 6 * tt))
        parts.append(lowpass(sq(ff, tt, 0.45), 0.2) * env(len(tt), 0.01, d, 0.6, 0.05))
    write_wav('fail', concat(*parts), 0.45)
    t = t_(0.45)
    f = np.geomspace(300, 1600, len(t))
    write_wav('upgrade', sq(f, t, 0.25) * env(len(t), 0.01, 0.4, 0.2, 0.05), 0.33)
    write_wav('unlock', concat(*[blip(note(m), 0.07, 'tri', 10) for m in (72, 76, 79, 83, 86, 88, 91)],
                               blip(note(96), 0.5, 'tri', 5)), 0.5)
    write_wav('kid', concat(blip(1568, 0.05, 'sq', 30, 0.5), blip(1175, 0.05, 'sq', 30, 0.5),
                            blip(1568, 0.08, 'sq', 30, 0.5)), 0.35)
    write_wav('streak', blip(1760, 0.09, 'tri', 25), 0.35)
    write_wav('tick', blip(2200, 0.02, 'sq', 120, 0.5), 0.3)
    write_wav('pickup', concat(*[blip(note(m), 0.05, 'sq', 22, 0.25) for m in (84, 88, 91, 96)]), 0.4)
    write_wav('forgive', concat(*[blip(note(m), 0.09, 'tri', 10) for m in (79, 84, 88)]), 0.45)
    t = t_(0.6)
    write_wav('vanish', sine(np.linspace(600, 1400, len(t)), t) * env(len(t), 0.02, 0.55, 0.0), 0.3)
    write_wav('buy', concat(blip(note(76), 0.06, 'sq', 20, 0.25), blip(note(83), 0.18, 'sq', 12, 0.25)), 0.4)
    # motor hum loop: exactly 1 s so it loops cleanly (55 Hz and harmonics fit whole periods)
    t = t_(1.0)
    hum = 0.6 * tri(55, t) + 0.3 * sq(110, t, 0.5) * 0.3 + 0.15 * sine(220, t) + 0.05 * sine(330, t)
    hum *= 1 + 0.08 * np.sin(2 * np.pi * 4 * t)
    data = hum / np.max(np.abs(hum)) * 0.3
    with wave.open(os.path.join(SFX, 'motor.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype('<i2').tobytes())


# ------------------------------------------------------------------ music

def epiano(f, d, vel=1.0):
    t = t_(d)
    tone = sine(f, t) + 0.35 * sine(2 * f, t) * expdec(len(t), 6) + 0.12 * sine(3 * f, t) * expdec(len(t), 12)
    tone *= 1 + 0.12 * np.sin(2 * np.pi * 5 * t)
    return tone * expdec(len(t), 2.2) * env(len(t), 0.004, d, 1.0, 0.03) * vel


def vibes(f, d, vel=1.0):
    t = t_(d)
    tone = sine(f, t) + 0.2 * sine(4 * f, t) * expdec(len(t), 8)
    tone *= 1 + 0.25 * np.sin(2 * np.pi * 6 * t)
    return tone * expdec(len(t), 3.0) * env(len(t), 0.003, d, 1.0, 0.03) * vel


def bass(f, d, vel=1.0):
    t = t_(d)
    tone = tri(f, t) * 0.8 + 0.3 * sine(f, t)
    return lowpass(tone, 0.25) * expdec(len(t), 3.5) * env(len(t), 0.005, d, 1.0, 0.02) * vel


def hat(d=0.05, vel=1.0):
    n = int(SR * d)
    return highpass(noise(n), 0.5) * expdec(n, 70) * vel


def brush(d=0.18, vel=1.0):
    n = int(SR * d)
    return lowpass(noise(n), 0.5) * expdec(n, 18) * vel


def kick(vel=1.0):
    t = t_(0.18)
    f = np.geomspace(130, 45, len(t))
    return sine(f, t) * expdec(len(t), 18) * vel


def mix_in(buf, x, pos):
    i = int(pos * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[:j - i]


CHORDS = {
    'Am7': [57, 60, 64, 67], 'D9': [50, 54, 57, 60, 64], 'Fmaj7': [53, 57, 60, 64], 'E7': [52, 56, 59, 62],
    'Dm7': [50, 53, 57, 60], 'G7': [55, 59, 62, 65], 'Cmaj7': [48, 52, 55, 59], 'Bm7b5': [47, 50, 53, 57],
    'Em7': [52, 55, 59, 62], 'A7': [57, 61, 64, 67],
}


def song(name, bpm, prog, swing=0.62, melody_seed=1, density=0.6, drums=True, length_bars=16):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * length_bars
    buf = np.zeros(int(total * SR) + SR)
    r = np.random.default_rng(melody_seed)
    for b in range(length_bars):
        ch = CHORDS[prog[b % len(prog)]]
        t0 = b * bar
        # comping: chord on beat 1 and the "and" of 2
        for (pos, vel) in ((0, 0.5), (1 + swing, 0.38)):
            for k, n in enumerate(ch[1:]):
                mix_in(buf, epiano(note(n + 12), beat * 1.6, vel * 0.32), t0 + pos * beat + k * 0.008)
        # walking bass
        root = ch[0] - 12
        walk = [root, root + 7, root + 12 if b % 2 else root + 5, root + 4 + (b % 3)]
        for i, n in enumerate(walk):
            mix_in(buf, bass(note(n), beat * 0.95, 0.9), t0 + i * beat)
        # drums
        if drums:
            for i in range(4):
                mix_in(buf, hat(0.05, 0.25 if i % 2 else 0.15), t0 + i * beat)
                mix_in(buf, hat(0.04, 0.12), t0 + (i + swing) * beat)
                if i in (1, 3):
                    mix_in(buf, brush(0.2, 0.2), t0 + i * beat)
            mix_in(buf, kick(0.5), t0)
            mix_in(buf, kick(0.3), t0 + 2 * beat + (swing if b % 2 else 0) * beat)
        # melody on vibes: chord tones with passing notes
        if b % 4 != 3 or r.random() < 0.5:
            pos = 0.0
            while pos < 4:
                step = r.choice([0.5, 1.0, 1.5, 0.5]) if r.random() < density else 1.0
                if r.random() < density:
                    n = r.choice(ch) + 24
                    if r.random() < 0.25:
                        n += r.choice([-1, 2])
                    off = pos if pos % 1 == 0 else int(pos) + swing
                    mix_in(buf, vibes(note(n), beat * min(step, 1.5), 0.42), t0 + off * beat)
                pos += step
    loop = buf[:int(total * SR)]
    # fold the tail back into the start so the loop is seamless
    tail = buf[int(total * SR):]
    loop[:len(tail)] += tail
    loop = loop / np.max(np.abs(loop)) * 0.82
    wav = os.path.join(MUS, name + '.wav')
    data = (loop * 32767).astype('<i2')
    with wave.open(wav, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    ogg = os.path.join(MUS, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '3', ogg], check=True)
    os.remove(wav)


def make_music():
    os.makedirs(MUS, exist_ok=True)
    song('menu', 84, ['Am7', 'D9', 'Fmaj7', 'E7', 'Am7', 'D9', 'Bm7b5', 'E7'], melody_seed=3, density=0.45)
    song('shift', 118, ['Dm7', 'G7', 'Cmaj7', 'A7', 'Dm7', 'G7', 'Em7', 'A7'], melody_seed=7, density=0.65)


if __name__ == '__main__':
    make_sfx()
    make_music()
    print('sounds written')
