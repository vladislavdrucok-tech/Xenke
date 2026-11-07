"""Synthesises all LOT 13 sound effects and the two music loops as 22.05 kHz mono 16-bit WAV.
python3 tools/make_audio.py"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(13)


def t_of(d):
    return np.arange(int(SR * d)) / SR


def note_hz(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(kind, f, d, duty=0.5):
    t = t_of(d)
    if np.isscalar(f):
        ph = (t * f) % 1.0
    else:
        ph = np.cumsum(np.asarray(f) / SR) % 1.0
    if kind == "sq":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    if kind == "sin":
        return np.sin(2 * np.pi * ph)
    if kind == "noise":
        return rng.uniform(-1, 1, len(t))
    raise ValueError(kind)


def env(n, a=0.005, d=0.05, s=0.6, r=0.05, total=None):
    total = total or n / SR
    t = np.arange(n) / SR
    e = np.ones(n) * s
    e[t < a] = t[t < a] / max(a, 1e-6)
    m = (t >= a) & (t < a + d)
    e[m] = 1 - (1 - s) * (t[m] - a) / max(d, 1e-6)
    m = t > total - r
    e[m] *= np.clip((total - t[m]) / max(r, 1e-6), 0, 1)
    return e


def decay(n, k):
    return np.exp(-np.arange(n) / SR * k)


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def seq(notes, kind="sq", step=0.08, dur=None, duty=0.5, k=18, vol=0.5):
    """Plays notes one after another; each rings for dur seconds with exponential decay."""
    dur = dur or step * 2
    total = step * (len(notes) - 1) + dur
    out = np.zeros(int(SR * total) + 1)
    for i, n in enumerate(notes):
        if n is None:
            continue
        s = osc(kind, note_hz(n), dur, duty) * decay(int(SR * dur), k) * vol
        st = int(SR * step * i)
        out[st: st + len(s)] += s
    return out


def write(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * vol
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def sfx():
    d = 0.06
    write("click", osc("sq", 990, d, 0.25) * decay(int(SR * d), 60), 0.45)
    write("tick", osc("sq", 1760, 0.03, 0.5) * decay(int(SR * 0.03), 120), 0.35)
    write("coin", seq([83, 88], "sq", 0.06, 0.18, 0.25, 14), 0.5)
    bell = seq([84, 88, 91, 96], "sq", 0.05, 0.35, 0.125, 9)
    ch = osc("noise", 0, 0.12) * decay(int(SR * 0.12), 35)
    write("cash", mix(lowpass(ch, 0.5) * 0.7, np.concatenate([np.zeros(int(SR * 0.08)), bell])), 0.6)
    write("bid", seq([72, 79], "sq", 0.05, 0.12, 0.25, 22), 0.5)
    write("outbid", seq([76, 71, 67], "sq", 0.06, 0.12, 0.5, 20), 0.4)
    knock = lambda: mix(osc("sin", np.linspace(220, 90, int(SR * 0.12)), 0.12) * decay(int(SR * 0.12), 30),
                        lowpass(osc("noise", 0, 0.05), 0.4) * decay(int(SR * 0.05), 80) * 0.8)
    k = knock()
    gap = np.zeros(int(SR * 0.13))
    write("gavel", np.concatenate([k, gap, k * 1.1]), 0.85)
    n = int(SR * 0.2)
    thud = mix(osc("sin", np.linspace(150, 55, n), 0.2) * decay(n, 18),
               lowpass(osc("noise", 0, 0.2), 0.25) * decay(n, 40) * 0.6)
    write("thud", thud, 0.85)
    n = int(SR * 0.35)
    whoosh = lowpass(osc("noise", 0, 0.35), 0.15) * np.sin(np.linspace(0, np.pi, n))
    pop = osc("sq", np.linspace(300, 900, int(SR * 0.08)), 0.08, 0.5) * decay(int(SR * 0.08), 30)
    write("open", mix(whoosh, np.concatenate([np.zeros(int(SR * 0.22)), pop * 0.6])), 0.7)
    write("whoosh", lowpass(osc("noise", 0, 0.22), 0.2) * np.sin(np.linspace(0, np.pi, int(SR * 0.22))), 0.45)
    write("reveal_common", seq([76], "tri", 0.1, 0.3, 0.5, 10), 0.5)
    write("reveal_uncommon", seq([76, 83], "sq", 0.08, 0.3, 0.25, 10), 0.45)
    write("reveal_rare", seq([72, 76, 79, 84], "sq", 0.07, 0.35, 0.25, 9), 0.5)
    sp = seq([96, 100, 103, 108, 103, 108], "sq", 0.04, 0.15, 0.125, 25, 0.3)
    write("reveal_epic", mix(seq([69, 73, 76, 81, 85], "sq", 0.08, 0.45, 0.5, 7), np.concatenate([np.zeros(int(SR * 0.35)), sp])), 0.55)
    fan = mix(seq([67, 72, 76, 79, None, 76, 79, 84], "sq", 0.11, 0.5, 0.5, 5),
              seq([55, 60, 64, 67, None, 64, 67, 72], "tri", 0.11, 0.5, 0.5, 4))
    write("reveal_legendary", mix(fan, np.concatenate([np.zeros(int(SR * 0.85)), seq([96, 100, 103, 108] * 2, "sq", 0.04, 0.2, 0.125, 18, 0.25)])), 0.6)
    n = int(SR * 0.22)
    clang = mix(osc("sq", 620, 0.22, 0.3) * decay(n, 22) * 0.5, osc("sq", 931, 0.22, 0.5) * decay(n, 28) * 0.3,
                lowpass(osc("noise", 0, 0.05), 0.6) * decay(int(SR * 0.05), 60))
    write("hit_good", clang, 0.6)
    write("hit_perfect", mix(clang, np.concatenate([np.zeros(int(SR * 0.05)), seq([91, 96, 100], "sq", 0.05, 0.2, 0.125, 16, 0.4)])), 0.65)
    n = int(SR * 0.3)
    write("miss", osc("saw", np.linspace(140, 90, n), 0.3) * env(n, 0.005, 0.05, 0.8, 0.08), 0.45)
    write("upgrade", seq([60, 64, 67, 72, 76, 79, 84], "sq", 0.06, 0.3, 0.25, 9), 0.5)
    write("levelup", mix(seq([72, 76, 79, 84, None, 84, 88, 91, 96], "sq", 0.09, 0.4, 0.5, 6),
                         seq([48, 52, 55, 60, None, 60, 64, 67, 72], "tri", 0.09, 0.4, 0.5, 5)), 0.6)
    write("event", seq([79, 84, 79, 88], "tri", 0.12, 0.4, 0.5, 6), 0.55)
    write("error", seq([50, 46], "sq", 0.09, 0.12, 0.5, 18), 0.4)
    write("deal", seq([72, 76, 79, 84], "tri", 0.07, 0.3, 0.5, 8), 0.55)
    n = int(SR * 0.55)
    wah = osc("sq", np.concatenate([np.linspace(330, 300, n // 2), np.linspace(280, 200, n - n // 2)]), 0.55, 0.4)
    write("angry", wah * env(n, 0.01, 0.1, 0.7, 0.15), 0.35)
    write("step", lowpass(osc("noise", 0, 0.05), 0.3) * decay(int(SR * 0.05), 70), 0.3)


def drum_kit():
    kick_n = int(SR * 0.18)
    kick = osc("sin", np.linspace(130, 45, kick_n), 0.18) * decay(kick_n, 22)
    sn_n = int(SR * 0.14)
    snare = lowpass(osc("noise", 0, 0.14), 0.55) * decay(sn_n, 28) * 0.5 + osc("tri", 190, 0.14) * decay(sn_n, 40) * 0.3
    hat_n = int(SR * 0.04)
    hat = (osc("noise", 0, 0.04) - lowpass(osc("noise", 0, 0.04), 0.3)) * decay(hat_n, 90) * 0.25
    return kick, snare, hat


def render_song(bpm, bars, chords, melody, bass_kind="tri", lead_duty=0.25, swing=0.0, drums="", lead_vol=0.22):
    beat = 60.0 / bpm
    step = beat / 2  # eighth notes
    total = int(SR * beat * 4 * bars)
    out = np.zeros(total + SR)
    kick, snare, hat = drum_kit()

    def put(sig, t0):
        i = int(SR * t0)
        out[i: i + len(sig)] += sig[: max(0, len(out) - i)]

    for b in range(bars):
        root, quality = chords[b % len(chords)]
        third = 3 if quality == "m" else 4
        tones = [root, root + third, root + 7]
        bar_t = b * beat * 4
        # bass: root on 1 and 3, fifth on the and-of-2
        for (pos, n, ln) in ((0, root - 12, 1.4), (1.5, root - 5, 0.4), (2, root - 12, 1.4), (3.5, root - 10 + (third - 3), 0.4)):
            d = beat * ln
            s = osc(bass_kind, note_hz(n), d) * env(int(SR * d), 0.005, 0.08, 0.7, 0.05) * 0.32
            put(s, bar_t + pos * beat)
        # soft chord arpeggio
        for i in range(8):
            n = tones[i % 3] + 12
            d = step * 0.9
            s = osc("sq", note_hz(n), d, 0.125) * decay(int(SR * d), 9) * 0.07
            put(s, bar_t + i * step + (swing * step if i % 2 else 0))
        # drums
        for i in range(8):
            t = bar_t + i * step + (swing * step if i % 2 else 0)
            if "k" in drums and i in (0, 4) or ("K" in drums and i in (0, 3, 4)):
                put(kick * 0.8, t)
            if "s" in drums and i in (2, 6):
                put(snare * 0.6, t)
            if "h" in drums:
                put(hat * (0.9 if i % 2 else 0.6), t)
    # melody: list of (beat position, midi or None, length in beats)
    for (pos, n, ln) in melody:
        if n is None:
            continue
        d = beat * ln
        s = osc("sq", note_hz(n), d, lead_duty) * env(int(SR * d), 0.01, 0.1, 0.6, 0.06) * lead_vol
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t_of(d))
        s = osc("sq", note_hz(n) * vib, d, lead_duty) * env(int(SR * d), 0.01, 0.1, 0.6, 0.06) * lead_vol
        put(s, pos * beat)
    out = out[:total]
    # gentle tail-to-head crossfade so the loop restarts cleanly
    return out


def music():
    # garage: relaxed, C major / A minor, 96 bpm, 8 bars
    chords = [(60, ""), (57, "m"), (65, ""), (67, ""), (60, ""), (57, "m"), (62, "m"), (67, "")]
    mel = []
    phrase = [(0, 76, 1), (1, 79, 0.5), (1.5, 76, 0.5), (2, 74, 1), (3, 72, 1),
              (4, 72, 1), (5, 76, 0.5), (5.5, 72, 0.5), (6, 69, 1.5), (7.5, None, 0.5),
              (8, 77, 1), (9, 76, 0.5), (9.5, 74, 0.5), (10, 72, 1), (11, 69, 1),
              (12, 71, 1), (13, 74, 1), (14, 79, 1.5), (15.5, None, 0.5)]
    for (p, n, l) in phrase:
        mel.append((p, n, l))
    for (p, n, l) in phrase[:10]:
        mel.append((p + 16, n, l))
    mel += [(24, 77, 1), (25, 76, 0.5), (25.5, 74, 0.5), (26, 74, 1), (27, 76, 1), (28, 72, 3), (31, None, 1)]
    write("music_garage", render_song(96, 8, chords, mel, swing=0.18, drums="kh", lead_vol=0.16), 0.55)
    # auction: upbeat, 132 bpm, 8 bars in D minor-ish
    chords = [(62, "m"), (62, "m"), (58, ""), (60, ""), (62, "m"), (65, ""), (60, ""), (57, "")]
    mel = []
    riff = [(0, 74, 0.5), (0.5, 77, 0.5), (1, 81, 0.5), (1.5, 77, 0.5), (2, 74, 0.5), (2.5, 77, 0.5), (3, 79, 1),
            (4, 74, 0.5), (4.5, 77, 0.5), (5, 81, 0.5), (5.5, 84, 0.5), (6, 81, 1), (7, None, 1)]
    for rep in range(2):
        for (p, n, l) in riff:
            mel.append((p + rep * 16, n, l))
    mel += [(8, 82, 1), (9, 81, 0.5), (9.5, 79, 0.5), (10, 77, 1), (11, 79, 1), (12, 72, 0.5), (12.5, 76, 0.5), (13, 79, 1), (14, 76, 2)]
    mel += [(24, 77, 0.5), (24.5, 81, 0.5), (25, 84, 1), (26, 82, 1), (27, 81, 1), (28, 76, 0.5), (28.5, 79, 0.5), (29, 81, 2), (31, None, 1)]
    write("music_auction", render_song(132, 8, chords, mel, bass_kind="sq", drums="Ksh", lead_vol=0.15, lead_duty=0.5), 0.55)


if __name__ == "__main__":
    sfx()
    music()
    print("audio ok:", sorted(f for f in os.listdir(OUT) if f.endswith(".wav")))
