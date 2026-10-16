#!/usr/bin/env python3
"""Synthesizes the story mode's sound motifs (docs/story/STORY_MODE.md, "Audio motifs").

Writes 16-bit mono WAVs, all original (no third-party source), into assets/audio/:
  ambience/rain_loop.wav   seamless 4 s rain bed (filtered noise + sparse drops)
  story/wrench.wav         a wrench hitting concrete: the bridge between nights
  story/shutter.wav        phone camera shutter click
  story/phone_buzz.wav     a phone buzzing on a table (Dante calling)
  story/pulse.wav          one low heartbeat pulse (after the crash)
  story/wiper.wav          one worn wiper stroke across wet glass

Run from the repo root:  python3 tools/audio/make_story_sfx.py
"""
import os
import wave

import numpy as np

RATE = 44100
ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
rng = np.random.default_rng(1983)


def write(path, signal, peak=0.85):
    signal = np.asarray(signal, dtype=np.float64)
    m = np.max(np.abs(signal))
    if m > 0:
        signal = signal / m * peak
    data = (signal * 32767).astype(np.int16)
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with wave.open(full, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", os.path.relpath(full))


def t(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def rain_loop(seconds=4.0):
    n = int(seconds * RATE)
    bed = highpass(lowpass(rng.standard_normal(n), 5200), 380) * 0.5
    drops = np.zeros(n)
    for _ in range(int(seconds * 140)):
        at = rng.integers(0, n - 800)
        length = rng.integers(120, 700)
        env = np.exp(-np.arange(length) / (length / 5))
        drops[at:at + length] += rng.standard_normal(length) * env * rng.uniform(0.2, 1.0)
    drops = highpass(drops, 1500)
    x = bed + drops * 0.35
    # Seamless: crossfade the last 0.25 s into the start.
    fade = int(0.25 * RATE)
    ramp = np.linspace(0, 1, fade)
    x[:fade] = x[:fade] * ramp + x[-fade:] * (1 - ramp)
    return x[:-fade]


def wrench():
    s = t(1.6)
    # A dropped steel wrench: a bright clank, then inharmonic ringing modes, a second small bounce.
    modes = [(1870, 0.9, 7), (3120, 0.6, 9), (4410, 0.45, 12), (5930, 0.3, 16), (812, 0.35, 5)]
    x = sum(a * np.sin(2 * np.pi * f * s) * np.exp(-d * s) for f, a, d in modes)
    click = rng.standard_normal(len(s)) * np.exp(-s * 160) * 1.4
    bounce_at = int(0.19 * RATE)
    bounce = np.zeros(len(s))
    sb = s[: len(s) - bounce_at]
    bounce[bounce_at:] = 0.4 * sum(a * np.sin(2 * np.pi * f * 1.01 * sb) * np.exp(-d * 1.6 * sb) for f, a, d in modes)
    bounce[bounce_at:] += rng.standard_normal(len(sb)) * np.exp(-sb * 200) * 0.6
    return x + click + bounce


def shutter():
    s = t(0.22)
    x = np.zeros(len(s))
    for at, amp in [(0.0, 1.0), (0.085, 0.7)]:
        i = int(at * RATE)
        seg = s[: len(s) - i]
        x[i:] += highpass(rng.standard_normal(len(seg)), 2000) * np.exp(-seg * 260) * amp
        x[i:] += np.sin(2 * np.pi * 2400 * seg) * np.exp(-seg * 300) * amp * 0.4
    return x


def phone_buzz():
    s = t(1.5)
    gate = ((s % 0.5) < 0.32).astype(float)
    hum = np.sign(np.sin(2 * np.pi * 172 * s)) * 0.6 + np.sin(2 * np.pi * 344 * s) * 0.3
    rattle = highpass(rng.standard_normal(len(s)), 900) * 0.25
    return lowpass((hum + rattle) * gate, 2600)


def pulse():
    s = t(1.1)
    def thump(at, amp):
        y = np.zeros(len(s))
        i = int(at * RATE)
        seg = s[: len(s) - i]
        y[i:] = np.sin(2 * np.pi * (52 - 18 * seg) * seg) * np.exp(-seg * 11) * amp
        return y
    return thump(0.0, 1.0) + thump(0.28, 0.7)


def wiper():
    s = t(0.7)
    env = np.sin(np.pi * np.clip(s / 0.62, 0, 1)) ** 0.7
    squeak = np.sin(2 * np.pi * (880 + 220 * np.sin(2 * np.pi * 3 * s)) * s) * 0.25
    smear = lowpass(highpass(rng.standard_normal(len(s)), 600), 4000)
    return (smear + squeak) * env


if __name__ == "__main__":
    write("ambience/rain_loop.wav", rain_loop(), 0.7)
    write("story/wrench.wav", wrench())
    write("story/shutter.wav", shutter())
    write("story/phone_buzz.wav", phone_buzz(), 0.6)
    write("story/pulse.wav", pulse())
    write("story/wiper.wav", wiper(), 0.5)
