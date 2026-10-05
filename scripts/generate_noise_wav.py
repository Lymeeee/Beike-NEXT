#!/usr/bin/env python3
"""Generate loopable white/pink/brown noise WAV assets for the 专注时刻 (pomodoro) page.

Rain / waves / stream are real field recordings processed by
scripts/wav_to_seamless_loop.py (see assets/audio/SOURCES.md); this script only
produces the synthetic noise beds.

Pure stdlib (no numpy). Outputs 22050 Hz mono 16-bit PCM.
Per-sound settings keep perceived loudness (LUFS) uniform across all pomodoro
sounds: white/pink/brown end up at RMS -23.4 / -19.8 / -17.9 dBFS respectively
(≈ -21 LUFS each), so switching between them never jumps in volume.
White also gets a gentle -8 dB high shelf above 5 kHz ("soft white", 助眠向) and
pink/brown use longer loops (30 s / 60 s) so their slow fluctuations do not
repeat audibly.

Loop seamlessness: every sound is rendered with `fade` seconds of extra tail,
and the loop head is equal-power crossfaded with that tail so the wrap-around is
sample-continuous.

Usage: python3 scripts/generate_noise_wav.py [--out-dir assets/audio]
"""

import argparse
import array
import math
import os
import random
import sys
import wave

SAMPLE_RATE = 22050
FADE = 0.5
PEAK_CEILING = 0.89
SEED = 20261002

# name -> (generator, loop seconds, high shelf (f0 Hz, dB) or None, target RMS dBFS)
SOUNDS = {
    "noise_white.wav": ("white", 12.0, (5000.0, -8.0), -23.39),
    "noise_pink.wav": ("pink", 30.0, None, -19.84),
    "noise_brown.wav": ("brown", 60.0, None, -17.94),
}


def gen_white(rng, n):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def gen_pink(rng, n):
    # Paul Kellet's refined pink-noise filter (-3 dB/octave)
    b = [0.0] * 7
    out = [0.0] * n
    for i in range(n):
        w = rng.uniform(-1.0, 1.0)
        b[0] = 0.99886 * b[0] + w * 0.0555179
        b[1] = 0.99332 * b[1] + w * 0.0750759
        b[2] = 0.96900 * b[2] + w * 0.1538520
        b[3] = 0.86650 * b[3] + w * 0.3104856
        b[4] = 0.55000 * b[4] + w * 0.5329522
        b[5] = -0.7616 * b[5] - w * 0.0168980
        out[i] = b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + w * 0.5362
        b[6] = w * 0.115926
    return out


def gen_brown(rng, n):
    # Leaky-integrated white noise (random walk with DC control)
    v = 0.0
    out = [0.0] * n
    for i in range(n):
        v = (v + 0.02 * rng.uniform(-1.0, 1.0)) / 1.02
        out[i] = v
    return out


GENERATORS = {"white": gen_white, "pink": gen_pink, "brown": gen_brown}


def apply_high_shelf(x, sr, f0, gain_db, slope=1.0):
    # RBJ audio-EQ-cookbook high shelf, biquad
    a = 10 ** (gain_db / 40)
    w0 = 2 * math.pi * f0 / sr
    cos_w0 = math.cos(w0)
    alpha = math.sin(w0) / 2 * math.sqrt((a + 1 / a) * (1 / slope - 1) + 2)
    sq = 2 * math.sqrt(a) * alpha
    b0 = a * ((a + 1) + (a - 1) * cos_w0 + sq)
    b1 = -2 * a * ((a - 1) + (a + 1) * cos_w0)
    b2 = a * ((a + 1) + (a - 1) * cos_w0 - sq)
    a0 = (a + 1) - (a - 1) * cos_w0 + sq
    a1 = 2 * ((a - 1) - (a + 1) * cos_w0)
    a2 = (a + 1) - (a - 1) * cos_w0 - sq
    b = (b0 / a0, b1 / a0, b2 / a0)
    a = (a1 / a0, a2 / a0)
    out = [0.0] * len(x)
    x1 = x2 = 0.0
    y1 = y2 = 0.0
    for i, v in enumerate(x):
        y = b[0] * v + b[1] * x1 + b[2] * x2 - a[0] * y1 - a[1] * y2
        x2, x1 = x1, v
        y2, y1 = y1, y
        out[i] = y
    return out


def crossfade_loop(x, loop_n, fade_n):
    # x holds loop_n + fade_n samples. Blend the first fade_n samples with the
    # generated tail after the loop point, so playing [0, loop_n) wraps
    # sample-continuously (out[0] == x[loop_n], adjacent to out[loop_n-1]).
    out = x[:loop_n]
    for i in range(fade_n):
        t = i / fade_n
        out[i] = x[loop_n + i] * math.cos(t * math.pi / 2) + x[i] * math.sin(
            t * math.pi / 2
        )
    return out


def rms_normalize(x, target_dbfs, ceiling=PEAK_CEILING):
    rms = math.sqrt(sum(v * v for v in x) / len(x))
    if rms == 0:
        return x
    gain = (10 ** (target_dbfs / 20)) / rms
    peak = max(abs(v) for v in x)
    if peak * gain > ceiling:
        gain = ceiling / peak
    return [v * gain for v in x]


def write_wav_mono16(path, samples, sr):
    data = array.array(
        "h", (max(-32768, min(32767, int(round(v * 32767)))) for v in samples)
    )
    if sys.byteorder == "big":
        data.byteswap()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", default="assets/audio")
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    fade_n = int(SAMPLE_RATE * FADE)

    for name, (kind, loop_s, shelf, target_rms) in SOUNDS.items():
        # 每种声音单独起随机流，改一种的时长不会扰动其它文件
        rng = random.Random(SEED)
        loop_n = int(SAMPLE_RATE * loop_s)
        n = loop_n + fade_n
        samples = crossfade_loop(
            GENERATORS[kind](rng, n), loop_n, fade_n
        )
        if shelf is not None:
            # 环形滤波：前后各接一个循环取中段，避免起振瞬态、保持接缝无缝
            samples = apply_high_shelf(
                samples * 3, SAMPLE_RATE, shelf[0], shelf[1]
            )[loop_n : loop_n * 2]
        samples = rms_normalize(samples, target_rms)
        path = os.path.join(args.out_dir, name)
        write_wav_mono16(path, samples, SAMPLE_RATE)
        print(f"{path}: {os.path.getsize(path) / 1024:.0f} KiB")


if __name__ == "__main__":
    main()
