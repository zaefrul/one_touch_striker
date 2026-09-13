# Stadium audio milestone — 13 September 2026

Published on `feat/stage-challenges` for the owner's local validation. This
milestone supplies audio assets and integration source. It is not a measured
performance improvement or a verified device playback result.

## What players hear

| Situation | Sound |
| --- | --- |
| Home, stage map, rewards, drills and stage briefing | Original upbeat menu loop |
| Active match | Distant stadium crowd, growing with stage level and streak |
| One chance left, or 8 seconds or less in a timed round | Suspense pulse |
| 4 seconds or less | Stronger suspense level |
| Kick / goal / Fire goal / post / wide | Existing distinct contact effects |
| Keeper save / defender block | Separate glove thud and harder deflection |
| Goal / unsuccessful shot | Cheer / sympathetic crowd groan |
| Attempt begins | Short whistle |
| Stage cleared or perfect practice drill | Victory flourish |
| Other finished or manually ended attempt | Short full-time cadence |
| Results screen | Quieter menu music under the final sting |

Practice uses a quieter crowd bed and physical shot effects. It has no pressure
music or crowd judgment of individual shots, because a goal can still miss a
drill's technique/target requirement. A legal shot released before zero keeps
its pressure music while flying; meeting the objective stops the suspense.

## Controls and saved settings

The header speaker remains a one-tap master mute. **AUDIO MIX** is available
on Home and in the pause panel, with separate **Music**, **Shot effects** and
**Crowd** switches. Music includes the menu and suspense loops; Crowd includes
the ambience and reactions. Master mute preserves those individual choices.

The existing `sound` preference is retained. The three optional Boolean keys
`audio_music`, `audio_effects` and `audio_crowd` default to true for older saves.
Audio is gated until saved settings load. The new keys load independently of
stars and records; writes use the existing serialized persistence queue.
Changing the mix from pause leaves the match paused.

The game retains `respectSilence: true` and mixes with other apps' audio.
On iPhone, check Silent Mode as well as media volume and the in-game switches
if nothing is audible. An unsupported or failed player does not block gameplay.

## Timing and lifecycle

- A pure `MatchSoundtrack` reads the simulation's typed `ShotFailure`, result
  serial and attempt ID. Display text no longer determines the miss sound.
  Repeated refreshes cannot replay the start whistle, result cue or finish sting.
- Thirteen short effects each reuse a preloaded low-latency player. Three loop
  players use media playback and native looping. No new player is allocated
  on a shot, and none polls playback position on display frames.
- Loop changes use cancellable 180 ms volume ramps. At a steady level there is
  no fade timer and no per-frame platform audio call. Muting a channel, pausing
  or backgrounding cancels pending transitions and queues a hard stop.
- Effects stop on navigation; loops transition to the new scene. The newest
  crowd reaction replaces the previous reaction so cheers do not accumulate.
- Loading keeps the latest desired scene; an old scene cannot start when a
  slow asset finishes preparing. Missed one-shot cues are dropped, not replayed
  after loading, unmuting or resuming.
- Returning to a foreground menu restores its loop. An interrupted match stays
  paused until the player resumes. Loops restart at their beginning after a
  hard stop. Disposal waits for pending commands and releases all players.

The implementation uses the existing `audioplayers: ^6.8.1` dependency and the
existing `assets/audio/` bundle entry. No new package or platform permissions
were added. API behavior was checked against the publisher's
[AudioPlayer documentation](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPlayer-class.html)
and [ReleaseMode documentation](https://pub.dev/documentation/audioplayers/latest/audioplayers/ReleaseMode.html).

## Local handoff

Source review and WAV metadata checks were performed. The generated pack is
about 1.8 MB before packaging, with original provenance and a reproducible
standard-library Python generator in [assets/AUDIO.md](assets/AUDIO.md).

Regression test **source** covers typed cue routing, event deduplication,
pressure thresholds, crowd progression, saved mix settings and lifecycle
integration through silent audio injection. Those tests were not executed.
Native command timing and sound quality still need real-device validation.

For the owner's next local playtest:

1. Launch with sound on, then relaunch with master mute and each channel off
   separately. Confirm no startup burst before saved mute is read.
2. Stay on Home for at least 40 seconds. Listen for loop clicks/gaps, then
   enter/retry/leave stages quickly and confirm only the current scene plays.
3. Score, go wide, hit a post, get saved and hit a defender. Confirm reactions
   match the visible outcome and the crowd does not cover the contact sound.
4. Reach one chance left and the 8/4-second thresholds. Check that the pressure
   layer adds tension without becoming tiring or masking the shot.
5. Pause, open Audio Mix, mute/unmute quickly, lock the phone and return. All
   audio should stop while paused; the match must require Resume on return.
6. Compare phone speaker and headphones on Android and iPhone. Listen for
   clipping and loop seams, and note any first-shot or scene-change stutter.

Browser autoplay rules may prevent music before the first user gesture; this
mobile audio milestone does not add a browser-specific unlock flow. Playback
of external music and handling of calls/Bluetooth also need device checks.

No analyzer, tests, builds, app runs or GitHub Actions were executed. The
branch's workflow remains manual-only. No APK is produced by this publication.
