# Party Pack LAN

Couch-style party mini-games for your local network — 2–4 players on Android,
hosted from one phone, joined by everyone else on the same Wi-Fi.

## Games (vertical slice)

| Game | Mode | Goal |
| --- | --- | --- |
| Sumo Push | Free-for-all | Shove rivals off the ring |
| Tug of War | Teams (2v2 / 1v1 / solo vs ghost) | Mash to pull the rope |
| Gem Catch | Free-for-all | Most gems in 45s, dodge bombs |
| Fire Brigade | Co-op vs the blaze | Shrink the fire to beat it |

Sessions run in rounds (2/4/6/8, host picks), with placement-style scoring and
a final podium. Phase-2 roster (Color Chaos, Arena Blitz, Junk Car Racing,
Memory Match) is planned to drop into the same mini-game framework.

## How it works

- One phone **hosts** (authoritative simulation at 60 Hz). Others **discover**
  the lobby over UDP broadcast beacons (port 45678) or enter the host IP.
- Reliable control messages (lobby, rounds, scoring) go over TCP 45679.
  Game inputs flow at 30 Hz and world snapshots at 20 Hz over UDP 45680.
- No internet required — everything stays on the LAN.

## Run it

```bash
flutter run                    # debug on a connected device
flutter build apk --release    # build/app/outputs/flutter-apk/app-release.apk
```

To play: install the APK on 2+ phones on the **same Wi-Fi** (not a guest/
client-isolated network), tap HOST on one, and JOIN on the others — lobbies
appear automatically, or enter the host IP shown on the host's lobby screen.

## Develop

```bash
flutter test     # unit + widget smoke tests (incl. a Flame game boot test)
flutter analyze
```

Sound effects and chiptune loops in `assets/audio/` are synthesized from
scratch by `tool/generate_audio.py` (no external audio licenses). Sprites are
grid-defined pixel art in `lib/pixel/sprites.dart`.
