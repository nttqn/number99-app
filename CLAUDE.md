# CLAUDE.md

Guidance for working in this repo. Same CI/Android/signing pattern as the sibling game repos ([[project_dino_egg_shooter]], [[project_chess_app]]) — see those for the fuller playbook if something here is underspecified.

## What this is

"99 Numbers" — a Flutter number-finding reflex game, rebuilt from the published `com.nttqn.number99` Play Store app (no original source was available). A 9x11 grid holds the numbers 1–99 in random order; the HUD shows a target number and a 10-second countdown; tapping the matching cell scores points (more for a faster catch) and advances to the next target. The round — and the game — ends when the countdown hits zero; the game is won when all 99 numbers have been found. Vietnamese-language UI, matching the original screenshot's HUD labels (TIME/SCORE) and button layout (RESTART/HINT/PAUSE).

No native `android/` or `web/` directory is committed — see "Android project is generated, not committed" below.

## Commands

```
flutter pub get
flutter analyze
flutter test
flutter create --platforms=web .   # only needed once, locally, to test in a browser (web/ is gitignored)
flutter run -d web-server --web-port 8765 --release   # fastest way to eyeball changes without an Android device
```

Real APK/AAB builds happen in CI only: push to `main` (or trigger `workflow_dispatch`) runs `.github/workflows/build-apk.yml`.

## Game logic (`lib/screens/game_screen.dart`)

Single `StatefulWidget` holds all game state — no separate state-management package, the game is simple enough that it isn't warranted. Key mechanics:

- **Board**: `List<int>` of 1–99, shuffled once per game (`_newGame`). Cell *index* in the grid is fixed for the game; the *value* at each index is what's shuffled.
- **Round**: `_startRound` picks a random remaining (not-yet-found) number as `_target`, resets a 10.0s countdown driven by a 100ms `Timer.periodic`. Timing out calls `_endGame(won: false)`; finding the last number calls `_endGame(won: true)`.
- **Scoring**: `10 + (timeLeft / roundSeconds * 90)`, rounded — an instant catch scores ~100, a last-moment catch scores ~10. This is a judgment call (the original app's exact formula is unknown); adjust the constants in `game_screen.dart` if the user wants a different curve.
- **Wrong taps**: no penalty, just a brief red flash (`_wrongFlashIndex`) — this was a design choice made without a confirmed spec from the user, since the original didn't specify one. Revisit if they ask for a penalty (e.g. losing time).
- **Hints**: limited to 3 per game (`_maxHints`), highlights the target cell yellow for ~1s. Also a design choice not confirmed against the original — the original might have unlimited hints; ask before assuming this is final.
- **High score**: single key in `shared_preferences` (`SaveService`), since there's only one game mode.

## Android project is generated, not committed

`android/`, `web/`, etc. are gitignored. CI's `build-apk.yml` regenerates `android/` via `flutter create --platforms=android .` on every run, then patches in the AdMob App ID, raises `minSdk`/`compileSdk` for `google_mobile_ads`, enables release shrinking with WorkManager keep rules (`tool/proguard-rules-extra.pro`), generates the launcher icon from `assets/icon/icon.png`, and wires up release signing if the 4 keystore secrets are set. This is an exact copy of the dino-egg-shooter workflow — see that repo's CLAUDE.md for the reasoning behind each step (WorkManager R8 stripping crash, Kotlin-DSL-vs-Groovy handling, etc.) if any of it needs changing.

## AdMob

`lib/services/admob_service.dart` currently uses **Google's public TEST ad unit IDs**, not real ones — this app doesn't have its own AdMob account entries yet. Before a real release: create a banner + interstitial ad unit for this app in the AdMob console, swap the two `_bannerId`/`_interstitialId` constants, and set the `ADMOB_APP_ID` GitHub secret (see the "Patch AndroidManifest.xml" CI step).

## Release signing

Not yet set up for this app (no `.jks` generated). When the user is ready to publish, follow [[feedback_release_signing_setup]] — the exact flow (keytool location, non-interactive generation command, delivery/verification steps) that worked for dino-egg-shooter and chess-app.

## Icon

`assets/icon/icon.png` was generated with PowerShell + `System.Drawing` (a simple "99" numeral on a green card/gradient) since this machine has no ImageMagick — see [[user_dev_machine_tooling]]. Replace it with real art any time; nothing else needs to change (`flutter_launcher_icons` config lives in `pubspec.yaml`).
