"""Generate the game's original, deterministic music, crowd and sound effects.

Run with Python 3. No third-party recordings, packages or network calls.
Durations match ShotSound in lib/game/audio_cues.dart. This only writes assets;
it does not build or run the Flutter app. All files are mono 22.05 kHz PCM WAV.
"""

from pathlib import Path
import math
import random
import struct
import wave
from array import array

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
CLIPS = [("kick", .18), ("net", .60), ("save", .26), ("post", .55),
         ("wide", .30), ("charge", .70), ("fire_goal", 1.10)]
NEW_CLIPS = [("blocked", .34), ("cheer", 1.40), ("groan", .85),
             ("whistle", .42), ("victory", 1.70), ("full_time", .95)]
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


def pcm(samples, ceiling=.65):
    peak = max(abs(value) for value in samples) or 1
    gain = ceiling / peak
    return b"".join(struct.pack("<h", round(value * gain * 32767))
                    for value in samples)


def frequency(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add_note(samples, start, length, note, gain, kind="pluck", wrap=False):
    """Small additive instruments; no sampled voices or external patches."""
    hz = frequency(note)
    offset = round(start * RATE)
    count = round(length * RATE)
    for i in range(count):
        t = i / RATE
        tail = (count - i) / RATE
        attack = min(1, t / (.08 if kind == "pad" else .006))
        if kind == "pad":
            env = attack * min(1, tail / .18)
            tone = (math.sin(TAU * hz * t) +
                    .24 * math.sin(TAU * hz * 2 * t) +
                    .10 * math.sin(TAU * hz * 3 * t))
        elif kind == "bass":
            env = attack * min(1, tail / .06) * math.exp(-3 * t)
            tone = math.sin(TAU * hz * t) + .20 * math.sin(TAU * hz * 2 * t)
        else:
            env = attack * min(1, tail / .06) * math.exp(-5.5 * t)
            tone = (math.sin(TAU * hz * t) +
                    .30 * math.sin(TAU * hz * 2 * t) +
                    .12 * math.sin(TAU * hz * 4 * t))
        index = offset + i
        if wrap:
            index %= len(samples)
        elif index >= len(samples):
            break
        samples[index] += gain * env * tone


def add_drum(samples, start, kind, gain, rng):
    length = {"kick": .24, "clap": .16, "hat": .07}[kind]
    offset = round(start * RATE)
    phase = low = 0.0
    for i in range(round(length * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += .22 * (noise - low)
        if kind == "kick":
            phase += TAU * (48 + 90 * math.exp(-t * 38)) / RATE
            value = math.sin(phase) * math.exp(-t * 21)
        elif kind == "clap":
            value = (noise - low) * math.exp(-t * 31)
            value *= .5 + .5 * abs(math.sin(190 * t))
        else:
            value = (noise - low) * math.exp(-t * 65)
        samples[(offset + i) % len(samples)] += gain * value * min(1, t / .002)


def soften_seam(samples):
    """Remove edge clicks without changing the exact whole-bar loop duration."""
    count = round(.004 * RATE)
    for i in range(count):
        gain = math.sin(math.pi / 2 * i / count) ** 2
        samples[i] *= gain
        samples[-1 - i] *= gain


def music(name):
    # 120 BPM: an eight-bar menu groove and a four-bar pressure ostinato.
    duration = 16 if name == "menu" else 8
    samples = array('d', [0]) * (duration * RATE)
    rng = random.Random(20260913 if name == "menu" else 20260914)
    if name == "menu":
        # D minor / B flat / F / C, with our own short call-and-response motif.
        chords = [(50, 53, 57), (46, 50, 53), (53, 57, 60), (48, 52, 55)]
        roots = [38, 34, 41, 36]
        melody = [74, 69, 72, 74, 77, 76, 72, 69,
                  74, 77, 81, 77, 72, 76, 79, 76]
        for section, chord in enumerate(chords):
            for note in chord:
                add_note(samples, section * 4, 4.1, note, .038, "pad", wrap=True)
            for beat in range(8):
                add_note(samples, section * 4 + beat * .5, .38,
                         roots[section] + (12 if beat == 7 else 0), .16, "bass")
        for index, note in enumerate(melody):
            start = index * .875 + (index // 4) * .25
            add_note(samples, start, .65, note, .075, wrap=True)
            add_note(samples, start + .25, .55, note, .018, wrap=True)
        for beat in range(32):
            if beat % 4 in (0, 2):
                add_drum(samples, beat * .5, "kick", .19, rng)
            if beat % 4 in (1, 3):
                add_drum(samples, beat * .5, "clap", .065, rng)
            for half in (0, .25):
                add_drum(samples, beat * .5 + half, "hat", .027, rng)
    else:
        # Controlled low pulse and a rising motif; no shrill countdown alarm.
        for note in (50, 57, 64):
            add_note(samples, 0, duration, note, .032, "pad")
        for beat in range(16):
            add_drum(samples, beat * .5, "kick", .19, rng)
            add_drum(samples, beat * .5 + .16, "kick", .09, rng)
            add_note(samples, beat * .5, .36, 38, .13, "bass")
            for half in range(2):
                note = (62, 69, 65, 69, 62, 70, 65, 72)[(beat * 2 + half) % 8]
                add_note(samples, beat * .5 + half * .25, .30, note, .034, wrap=True)
                add_drum(samples, beat * .5 + half * .25, "hat", .017, rng)
    soften_seam(samples)
    return pcm(samples, .58)


def crowd(duration, seed, reaction=None):
    """Filtered noise and vowel-like harmonics suggest a distant animated crowd.

    No words, recorded spectators, real teams or identifiable chants are used.
    """
    rng = random.Random(seed)
    samples = array('d')
    low = mid = slow = 0.0
    voices = [(round(rng.uniform(110, 230) * duration) / duration,
               rng.uniform(0, TAU), rng.choice((2, 3, 4))) for _ in range(7)]
    phase = [v[1] for v in voices]
    for i in range(round(duration * RATE)):
        t = i / RATE
        low += .018 * (rng.uniform(-1, 1) - low)
        noise = rng.uniform(-1, 1)
        mid += .25 * (noise - mid)
        slow += .002 * (noise - slow)
        swell = .65 + .20 * math.sin(TAU * t / duration) + .12 * math.sin(6 * TAU * t / duration)
        value = (mid - slow) * .65 + low * .65
        for j, (hz, offset, speed) in enumerate(voices):
            bend = 1 if reaction is None else (1.06 + .10 * t / duration
                    if reaction == "cheer" else 1.10 - .23 * t / duration)
            phase[j] += TAU * hz * bend / RATE
            envelope = (.5 + .5 * math.sin(TAU * speed * t / duration + offset)) ** 2
            value += .028 * envelope * (math.sin(phase[j]) +
                       .6 * math.sin(phase[j] * 3) + .25 * math.sin(phase[j] * 5))
        if reaction:
            swell = math.sin(math.pi * t / duration) ** (.65 if reaction == "cheer" else .85)
        samples.append(value * swell)
    soften_seam(samples)
    return pcm(samples, .58 if reaction else .42)


def new_effect(name, duration):
    if name in ("cheer", "groan"):
        return crowd(duration, 901 if name == "cheer" else 902, reaction=name)
    samples = array('d', [0]) * round(duration * RATE)
    rng = random.Random(903)
    if name in ("victory", "full_time"):
        notes = (74, 77, 81, 86) if name == "victory" else (74, 69, 62)
        spacing = .15 if name == "victory" else .18
        for index, note in enumerate(notes):
            add_note(samples, index * spacing, duration - index * spacing,
                     note, .16)
        if name == "victory":
            for note in (50, 57, 62, 65):
                add_note(samples, .30, 1.35, note, .045, "pad")
            add_drum(samples, .02, "clap", .12, rng)
    else:
        filtered = phase = 0.0
        for i in range(len(samples)):
            t = i / RATE
            noise = rng.uniform(-1, 1)
            filtered += .20 * (noise - filtered)
            if name == "blocked":
                value = .7 * bell(t, 145, 35) + .35 * bell(t - .03, 215, 28)
                value += .65 * filtered * math.exp(-t * 24)
                value += .10 * (noise - filtered) * math.exp(-t * 14)
            else:
                phase += TAU * (1850 + 38 * math.sin(TAU * 32 * t)) / RATE
                breath = math.sin(math.pi * t / duration) ** .7
                value = (.22 * math.sin(phase) + .07 * filtered) * breath
            samples[i] = value * min(1, t / .005, (duration - t) / .025)
    return pcm(samples, .58)


def write(name, frames):
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Preserve the established seven effects byte for byte.
    for i, (name, duration) in enumerate(CLIPS):
        write(name, synth(name, duration, seed=731 + i))
    for name, duration in NEW_CLIPS:
        write(name, new_effect(name, duration))
    for name in ("menu", "suspense"):
        write(name, music(name))
    write("stadium", crowd(8, 904))
    print(f"Wrote {len(CLIPS) + len(NEW_CLIPS)} effects and 3 original loops to {OUT}")


if __name__ == "__main__":
    main()
