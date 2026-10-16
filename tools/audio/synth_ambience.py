"""Synthesises the mountain-road ambience: `python3 tools/audio/synth_ambience.py`.

Writes assets/audio/ambience/{crickets_loop,wind_loop,dog_bark_far}.wav (44.1 kHz mono 16-bit).
Everything is generated here from noise and sines, so the files are ours (CC0). Loops are built
circularly (events wrap, filtering is done in the FFT domain) so they repeat without a seam.
"""
import os
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "ambience")
rng = np.random.default_rng(2026)


def save(name, x, peak=0.8):
    x = x / max(np.abs(x).max(), 1e-9) * peak
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"{name}: {len(x) / RATE:.1f} s")


def shape(x, gain_of_hz):
    """Circular FFT filter: multiplies the spectrum by gain_of_hz(freqs)."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    return np.fft.irfft(spec * gain_of_hz(freqs), len(x))


def band(f, center, width):
    return np.exp(-0.5 * ((f - center) / width) ** 2)


def crickets(seconds=12.0):
    """Field crickets: a few near voices chirping in pulse trains, over a dense far chorus."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for v in range(5):
        # Whole cycles per loop, so the sine wraps without a click.
        carrier = round(rng.uniform(4300, 5200) * seconds) / seconds
        gain = rng.uniform(0.4, 1.0)
        period = rng.uniform(0.45, 0.9)
        pulses = rng.integers(3, 6)
        pulse_rate = rng.uniform(28, 45)
        start = rng.uniform(0, period)
        env = np.zeros(n)
        k = start
        while k < seconds:
            for p in range(pulses):
                c = int(((k + p / pulse_rate) % seconds) * RATE)
                width = int(0.012 * RATE)
                idx = (c + np.arange(width)) % n
                env[idx] += np.sin(np.linspace(0, np.pi, width)) ** 2
            # Crickets drift: each chirp a little early or late.
            k += period * rng.uniform(0.9, 1.1)
        out += gain * env * np.sin(2 * np.pi * carrier * t + rng.uniform(0, 6.28))
    chorus = shape(rng.standard_normal(n), lambda f: band(f, 4700, 250))
    chorus *= 0.6 + 0.4 * np.sin(2 * np.pi * 37 * t) ** 2   # the massed trill
    out = out + 0.35 * chorus / np.abs(chorus).max()
    return out


def wind(seconds=16.0):
    """Mountain wind: brownish noise with a soft whistle band, swelling in gusts."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    body = shape(noise, lambda f: 1.0 / np.maximum(f, 20.0) ** 0.9 * (f > 30) * (f < 2500))
    whistle = shape(rng.standard_normal(n), lambda f: band(f, 620, 60) + 0.5 * band(f, 1100, 90))
    body /= np.abs(body).max()
    whistle /= np.abs(whistle).max()
    # Gusts: whole cycles per loop so the envelope wraps too.
    gust = 0.55 + 0.25 * np.sin(2 * np.pi * 1 * t / seconds) + 0.2 * np.sin(2 * np.pi * 3 * t / seconds + 1.3)
    gust += 0.1 * np.sin(2 * np.pi * 7 * t / seconds + 0.4)
    return body * gust + 0.25 * whistle * gust ** 2


def bark(f0, length=0.16):
    """One bark: a harmonic yelp gliding down, through dog-ish formants, with a breathy edge."""
    n = int(length * RATE)
    t = np.arange(n) / RATE
    glide = f0 * (1.0 - 0.35 * t / length)
    phase = 2 * np.pi * np.cumsum(glide) / RATE
    src = sum(np.sin(h * phase) / h for h in range(1, 14))
    src += 0.3 * rng.standard_normal(n)
    env = np.minimum(t / 0.006, 1.0) * np.exp(-t / 0.05)
    voice = src * env
    pad = np.zeros(int(0.05 * RATE))
    x = np.concatenate([voice, pad])
    return shape(x, lambda f: band(f, 850, 220) + 0.8 * band(f, 1750, 300) + 0.4 * band(f, 2900, 400))


def dog_far():
    """Two barks across the valley: low-passed by distance, with a long hillside echo."""
    total = int(2.6 * RATE)
    dry = np.zeros(total)
    for at, f0 in [(0.05, 640), (0.42, 590), (1.1, 620)]:
        b = bark(f0)
        i = int(at * RATE)
        dry[i:i + len(b)] += b[: total - i]
    dry = shape(dry, lambda f: 1.0 / (1.0 + (f / 1800.0) ** 4))
    ir_len = int(1.6 * RATE)
    tt = np.arange(ir_len) / RATE
    ir = rng.standard_normal(ir_len) * np.exp(-tt / 0.35) * 0.25
    ir[0] = 1.0
    # A discrete slap back off the far slope.
    ir[int(0.28 * RATE)] += 0.35
    wet = np.convolve(dry, ir)[:total]
    fade = np.ones(total)
    fade[-int(0.3 * RATE):] = np.linspace(1, 0, int(0.3 * RATE))
    return (0.45 * dry + wet) * fade


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    save("crickets_loop.wav", crickets(), 0.7)
    save("wind_loop.wav", wind(), 0.7)
    save("dog_bark_far.wav", dog_far(), 0.8)
