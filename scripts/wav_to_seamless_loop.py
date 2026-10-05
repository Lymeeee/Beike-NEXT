#!/usr/bin/env python3
"""Turn a raw field recording (WAV) into a seamless-loop WAV asset.

Pipeline: downsample-free slice of the source -> equal-power crossfade of the
loop head with a tail that continues past the loop point -> RMS normalize to
match the generated noise assets.

Loop seamlessness: `--fade` seconds of audio *after* the loop point are
consumed by the crossfade, so the wrap-around is sample-continuous.

Input must be PCM WAV (16-bit). For ogg/flac/mp3 sources pre-convert first:
    python3 -m venv venv && venv/bin/pip install soundfile
    venv/bin/python -c "import soundfile as sf; \\
        x, sr = sf.read('in.ogg', samplerate=44100); \\
        sf.write('in.wav', x, sr, subtype='PCM_16')"

Usage:
    python3 scripts/wav_to_seamless_loop.py \\
        --src in.wav --out assets/audio/noise_rain.wav \\
        --start 48.5 --loop 28 --fade 2
"""

import argparse
import array
import math
import os
import sys
import wave

TARGET_DBFS = -20.0
PEAK_CEILING = 0.89


def read_wav_mono(path):
    with wave.open(path, "rb") as w:
        if w.getsampwidth() != 2:
            raise SystemExit(f"{path}: only 16-bit PCM WAV is supported")
        sr = w.getframerate()
        channels = w.getnchannels()
        raw = w.readframes(w.getnframes())

    data = array.array("h")
    data.frombytes(raw)
    if sys.byteorder == "big":
        data.byteswap()

    if channels == 1:
        return [v / 32768.0 for v in data], sr

    out = [0.0] * (len(data) // channels)
    for i in range(len(out)):
        out[i] = sum(data[i * channels : i * channels + channels]) / (
            channels * 32768.0
        )
    return out, sr


def crossfade_loop(x, loop_n, fade_n):
    out = list(x[:loop_n])
    for i in range(fade_n):
        t = i / fade_n
        out[i] = (
            x[loop_n + i] * math.cos(t * math.pi / 2)
            + x[i] * math.sin(t * math.pi / 2)
        )
    return out


def rms_normalize(x, target_dbfs=TARGET_DBFS, ceiling=PEAK_CEILING):
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
    parser.add_argument("--src", required=True, help="source PCM WAV file")
    parser.add_argument("--out", required=True, help="output loop WAV path")
    parser.add_argument(
        "--start", type=float, default=0.0, help="slice start in source (s)"
    )
    parser.add_argument(
        "--loop", type=float, required=True, help="loop length (s)"
    )
    parser.add_argument(
        "--fade",
        type=float,
        default=2.0,
        help="crossfade length (s), extra audio consumed after the loop point",
    )
    args = parser.parse_args()

    samples, sr = read_wav_mono(args.src)
    start_n = int(args.start * sr)
    loop_n = int(args.loop * sr)
    fade_n = int(args.fade * sr)

    end_n = start_n + loop_n + fade_n
    if end_n > len(samples):
        raise SystemExit(
            f"source too short: need {end_n / sr:.1f}s, have {len(samples) / sr:.1f}s"
        )
    if fade_n >= loop_n:
        raise SystemExit("--fade must be shorter than --loop")

    segment = samples[start_n:end_n]
    out = rms_normalize(crossfade_loop(segment, loop_n, fade_n))

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    write_wav_mono16(args.out, out, sr)
    print(f"{args.out}: {os.path.getsize(args.out) / 1024:.0f} KiB, {loop_n / sr:.1f}s loop")


if __name__ == "__main__":
    main()
