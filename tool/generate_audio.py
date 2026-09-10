"""Generate the game's original, deterministic PCM sound effects.

Run with Python 3. No third-party recordings, packages or network calls.
Durations match ShotSound in lib/game/striker_audio.dart.
"""

from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
CLIPS = [("kick", .18), ("net", .60), ("save", .26), ("post", .55),
         ("wide", .30), ("charge", .70), ("fire_goal", 1.10)]
TAU = math.tau


def bell(t, frequency, decay):
    return 0 if t < 0 else math.sin(TAU * frequency * t) * math.exp(-decay * t)


def synth(name, duration, seed):
    rng = random.Random(seed)
    low = mid = phase = 0.0
    samples = []
    for i in range(round(duration * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += .035 * (noise - low)
        mid += .30 * (noise - mid)
        air = mid - low
        phase += TAU * (55 + 135 * math.exp(-t * 32)) / RATE
        if name == "kick":
            value = .8 * math.sin(phase) * math.exp(-t * 27)
            value += .35 * air * math.exp(-t * 60)
        elif name == "net":
            value = .7 * air * math.exp(-t * 16)
            value += .25 * bell(t, 145, 20)
            value += .65 * low * math.sin(math.pi * t / duration)
            value += .09 * (bell(t - .03, 523.25, 7) + bell(t - .07, 659.25, 8))
        elif name == "save":
            value = .75 * bell(t, 100, 28) + .35 * bell(t - .025, 145, 32)
            value += .7 * mid * math.exp(-t * 30)
        elif name == "post":
            value = .52 * bell(t, 980, 9) + .27 * bell(t, 2350, 15)
            value += .14 * bell(t, 3470, 22) + .2 * air * math.exp(-t * 70)
        elif name == "wide":
            value = air * math.sin(math.pi * t / duration) ** 2
        elif name == "charge":
            value = .5 * air * math.sin(math.pi * t / duration)
            for start, note in [(0, 523.25), (.16, 659.25), (.32, 783.99)]:
                age = t - start
                if age >= 0:
                    value += .23 * bell(age, note, 7) * min(1, age / .01)
        else:
            swell = math.sin(math.pi * t / duration) ** 1.3
            value = .55 * bell(t, 90, 18) + .8 * low * swell + .35 * air * swell
            for start, note in [(.035, 523.25), (.08, 659.25), (.13, 783.99), (.19, 1046.5)]:
                age = t - start
                if age >= 0:
                    value += .14 * bell(age, note, 3.7) * min(1, age / .008)
        # Smooth file boundaries; leave headroom for overlapping effect voices.
        fade = min(1, t / .003, max(0, (duration - t) / .025))
        samples.append(value * fade)
    peak = max(abs(s) for s in samples) or 1
    gain = .7 / max(1, peak)
    return b"".join(struct.pack("<h", round(s * gain * 32767)) for s in samples)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, duration) in enumerate(CLIPS):
        with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(synth(name, duration, seed=731 + i))
    print(f"Wrote {len(CLIPS)} original sound effects to {OUT}")


if __name__ == "__main__":
    main()
