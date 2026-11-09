#!/usr/bin/env python3
"""Synthesizes the short, soft sound effects of Pocket Triples (16-bit mono WAV, 44.1 kHz).
Run from the project folder: python3 tools/make_sfx.py"""
import math
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
SR = 44100
os.makedirs(OUT, exist_ok=True)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(t, attack=0.004, decay=0.2):
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def bell(freq, dur, decay, partials=((1, 1.0), (2.0, 0.35), (3.01, 0.12), (4.2, 0.05))):
    t = t_axis(dur)
    s = np.zeros_like(t)
    for mult, amp in partials:
        s += amp * np.sin(2 * math.pi * freq * mult * t) * np.exp(-t / (decay / mult ** 0.5))
    return s * np.clip(t / 0.003, 0, 1)


def place(sig, total, at):
    i = int(at * SR)
    total[i:i + len(sig)] += sig[: max(0, len(total) - i)]


def lowpass(x, alpha=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def save(name, sig, gain=0.8):
    sig = sig / max(1e-6, np.max(np.abs(sig))) * gain
    fade = min(len(sig), int(SR * 0.01))
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


rng = np.random.default_rng(3)

# pick: a soft wooden "tock" as the tile lifts off the stack
t = t_axis(0.09)
tock = (np.sin(2 * math.pi * 820 * t) * 0.8 + np.sin(2 * math.pi * 1640 * t) * 0.25) * env(t, 0.002, 0.018)
tock += lowpass(rng.standard_normal(len(t)), 0.3) * env(t, 0.001, 0.006) * 0.5
save("pick.wav", tock, 0.55)

# land: the tile settles in the tray, a little lower and rounder
t = t_axis(0.12)
f = 520 * np.exp(-t * 6)
land = np.sin(2 * math.pi * np.cumsum(f) / SR) * env(t, 0.003, 0.04)
land += lowpass(rng.standard_normal(len(t)), 0.15) * env(t, 0.001, 0.01) * 0.35
save("land.wav", land, 0.5)

# match: three quick bell notes going up, then a shimmer
total = np.zeros(int(SR * 0.85))
for k, n in enumerate((76, 79, 84)):
    place(bell(note(n), 0.7, 0.28), total, k * 0.065)
shimmer = t_axis(0.5)
place(np.sin(2 * math.pi * note(91) * shimmer) * env(shimmer, 0.02, 0.12) * 0.2, total, 0.2)
save("match.wav", total, 0.7)

# win: a small major arpeggio with a soft final chord
total = np.zeros(int(SR * 1.7))
for k, n in enumerate((72, 76, 79, 84)):
    place(bell(note(n), 1.2, 0.35), total, k * 0.11)
for n in (72, 76, 79, 84, 88):
    place(bell(note(n), 1.2, 0.5) * 0.45, total, 0.5)
save("win.wav", total, 0.75)

# lose: two gentle falling tones, no harsh buzz
total = np.zeros(int(SR * 0.9))
for k, n in enumerate((67, 62)):
    tt = t_axis(0.55)
    s = (np.sin(2 * math.pi * note(n) * tt) + 0.3 * np.sin(2 * math.pi * note(n) * 2 * tt)) * env(tt, 0.01, 0.2)
    place(s, total, k * 0.22)
save("lose.wav", lowpass(total, 0.25), 0.6)

# undo: a short upward swish
t = t_axis(0.16)
f = 300 + 900 * (t / t[-1]) ** 1.5
sw = np.sin(2 * math.pi * np.cumsum(f) / SR) * np.sin(math.pi * t / t[-1]) ** 2
sw += lowpass(rng.standard_normal(len(t)), 0.08) * np.sin(math.pi * t / t[-1]) * 0.6
save("undo.wav", sw, 0.4)

# button: tiny click
t = t_axis(0.05)
click = np.sin(2 * math.pi * 1250 * t) * env(t, 0.001, 0.01)
save("button.wav", click, 0.4)

# warn: two soft ticks when only one tray slot is left
total = np.zeros(int(SR * 0.3))
for k in range(2):
    tt = t_axis(0.1)
    place(np.sin(2 * math.pi * 660 * tt) * env(tt, 0.002, 0.025), total, k * 0.11)
save("warn.wav", total, 0.35)

# nope: tapping an empty stack
t = t_axis(0.1)
nope = np.sin(2 * math.pi * 180 * t) * env(t, 0.003, 0.03)
save("nope.wav", nope, 0.35)

print("sounds written to", OUT)
