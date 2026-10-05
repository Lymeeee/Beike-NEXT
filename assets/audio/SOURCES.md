# assets/audio 来源与许可

番茄钟「白噪音」全部为无版权素材（CC0 / 公有领域），可随应用自由分发。
所有素材统一对齐到 -21 LUFS 感知响度，切换时不会忽大忽小。

| 文件 | 内容 | 来源 | 许可 |
| --- | --- | --- | --- |
| noise_white.wav | 合成白噪声（12s，5kHz 以上 -8dB 柔化） | `scripts/generate_noise_wav.py` | 本仓库脚本生成 |
| noise_pink.wav | 合成粉噪声（30s） | 同上 | 同上 |
| noise_brown.wav | 合成棕噪声（60s） | 同上 | 同上 |
| noise_rain.wav | 实录音：细雨（28s） | [File:Light Rain Distant Thunder July 5th 2016.wav](https://commons.wikimedia.org/wiki/File:Light_Rain_Distant_Thunder_July_5th_2016.wav)（Wikimedia Commons） | CC0 |
| noise_wave.wav | 实录音：海浪（36s） | [File:Ocean Waves on a Tropical Beach.ogg](https://commons.wikimedia.org/wiki/File:Ocean_Waves_on_a_Tropical_Beach.ogg)（Wikimedia Commons） | CC0 |
| noise_stream.wav | 实录音：流水/溪流（34s） | [File:433589 jackthemurray stream-river-water-up-close.wav](https://commons.wikimedia.org/wiki/File:433589_jackthemurray_stream-river-water-up-close.wav)（Wikimedia Commons） | CC0 |

实录音处理流程：

1. ffmpeg 解码、单声道、44.1kHz，高通滤除低频隆隆（55–80Hz）
2. 截取平稳片段，尾部 2 秒与循环头做等功率交叉淡化（无缝循环）
   - noise_rain.wav：源 48.5–78.5s（该段无雷声）
   - noise_wave.wav：源 10.5–48.5s
   - noise_stream.wav：源 24.5–60.5s
3. 软限幅（tanh，治水花/雨点尖峰）+ 按 LUFS 对齐到 -21

## 重新生成

合成噪声（纯 stdlib）：

```sh
python3 scripts/generate_noise_wav.py
```

实录音换素材：先转 44.1k 16-bit WAV，再

```sh
python3 scripts/wav_to_seamless_loop.py \
    --src rain_44k.wav --out assets/audio/noise_rain.wav \
    --loop 28 --fade 2
```

最后对输出做软限幅 + LUFS 对齐（脚本内为 RMS 近似；尖峰多的素材需先限幅，
否则响度会被峰值顶住）。
