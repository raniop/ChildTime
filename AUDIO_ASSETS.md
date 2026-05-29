# Audio Assets — dropping in professional sounds & music

The app ships with **procedural** (code-generated) sounds and music so it's never
silent. To upgrade to **real recorded audio**, just add files with the exact
names below to the app bundle — the app loads them automatically and falls back
to the synth only when a file is missing. **No code changes needed.**

## How to add files (Xcode)
1. Get royalty-free audio (see sources below) and rename each file to the exact
   name in the tables.
2. In Xcode, drag the files into the **`ChildTime/Audio`** group.
3. In the dialog: tick **"Copy items if needed"** and make sure the **ChildTime**
   target is checked under "Add to targets".
4. Build & run — the new audio replaces the synth automatically.

Accepted formats (first found wins): **`.caf`** (smallest), **`.mp3`**, **`.wav`**
(music also allows **`.m4a`**). `.caf`/`.mp3` recommended.

## Sound effects — file names
Each is a short one-shot (~0.2–1.5s). Keep them gentle (kids hold the iPad close).

| File name (any accepted ext) | When it plays |
|---|---|
| `ui_tap`          | button taps |
| `correct_small`   | correct answer |
| `correct_big`     | correct on a gold/super question |
| `wrong_soft`      | wrong answer (keep it soft, never harsh) |
| `streak_up`       | streak +1 / hint used |
| `portal_appear`   | mystery portal opens |
| `level_up`        | level up / wheel prize |
| `chest_open`      | reward chest / shop purchase |
| `companion_cheer` | Tofy celebrates |
| `world_unlock`    | a new world unlocks |

Example: adding `correct_small.mp3` instantly replaces the synth "correct" sound.

## Background music — file name
| File name | Notes |
|---|---|
| `background_music` (`.mp3`/`.m4a`/`.caf`/`.wav`) | Looped softly on the home screen. Use a calm, cheerful, **seamlessly-looping** kids track. The app loops it infinitely and keeps the volume low under the effects. |

If present, it plays instead of the procedural music loop.

## Everything respects the parent toggle
All audio (effects + music) is gated by **Parent Settings → "צלילים פעילים"**, and
music pauses/resumes with the app automatically.

## Where to get kid-friendly royalty-free audio
- **Pixabay Music / SFX** (pixabay.com) — free, no attribution.
- **Mixkit** (mixkit.co), **Uppbeat** (uppbeat.io) — free game/kids tracks & SFX.
- **Freesound** (freesound.org) — huge SFX library (check each license).
- **Zapsplat** (zapsplat.com) — UI/game SFX.
- AI generators: **Suno** (music), **ElevenLabs SFX** (sound effects).

Pick "UI", "game", "casual", "kids", "music box", or "marimba" style packs for a
consistent, friendly feel.
