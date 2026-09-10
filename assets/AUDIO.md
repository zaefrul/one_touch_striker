# One-Touch Striker sound effects

The seven WAV files in `audio/` are original procedural effects generated for
this project by `tool/generate_audio.py`. They contain no third-party recordings,
sample packs, speech or music excerpts. They may be used and modified with the
game. The cheering/swell effects are synthetic, not recorded spectators.

Format: mono, 16-bit PCM, 22,050 Hz. Total playback duration: 3.69 seconds.
Clip durations are declared in `ShotSound`; keep them in sync when replacing an
effect so Android low-latency voices return to their preloaded state correctly.

Only the `assets/audio/` directory is bundled by Flutter. This provenance file
and the generator do not add runtime work. Regenerate from the repo root with:

```bash
python3 tool/generate_audio.py
```

No playback or device audio tests were performed during source publication.
