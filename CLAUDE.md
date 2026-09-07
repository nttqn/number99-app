# CLAUDE.md

Guidance for working in this repo. Same CI/Android/signing pattern as the sibling game repos ([[project_dino_egg_shooter]], [[project_chess_app]]) — see those for the fuller playbook if something here is underspecified.

## What this is

"99 Numbers" — a Flutter number-finding reflex game, rebuilt from the published `com.nttqn.number99` Play Store app (no original source was available). A 9x11 grid holds the numbers 1–99 in random order; the HUD shows a target number and a countdown (shrinks as level rises — see Levels below); tapping the matching cell scores points (more for a faster catch) and advances to the next target. Clearing the whole board doesn't end the run either — it advances the level and deals a fresh reshuffled board (see Levels) — **except on the final level (11)**, where clearing it is the win condition. A run otherwise ends when the countdown hits zero. All-English UI (switched from an initial Vietnamese menu/dialogs on 2026-08-24 for consistency with the HUD, which was always English to match the original screenshot's TIME/SCORE labels and RESTART/HINT/PAUSE button layout).

No native `android/`, `ios/`, or `web/` directory is committed — see "Android project is generated, not committed" and "iOS" below.

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

- **Board**: `List<int>` of 1–99, shuffled once per game (`_newGame`). Cell *index* in the grid is fixed for the game; the *value* at each index is what's shuffled (except see Levels — reshuffled again on every level-up).
- **Round**: `_startRound` picks a random remaining (not-yet-found) number as `_target`, resets a countdown (`_roundSecondsForLevel(_level)`) driven by a 100ms `Timer.periodic`. Timing out calls `_endGame(won: false)`. Clearing the board only calls `_endGame(won: true)` on the final level (11); every other level it's a level-up instead — see Levels.
- **Scoring**: `(10 + (timeLeft / roundSeconds * 90)) * levelMultiplier`, rounded — an instant catch scores ~100 at level 1, scaling up with `_scoreMultiplierForLevel`. This curve (and the wrong-tap/hint behavior below) is a judgment call, not confirmed against the original app's exact numbers — adjust the constants in `game_screen.dart` if the user wants different tuning.
- **Wrong taps**: no penalty, just a brief red flash (`_wrongFlashIndex`).
- **Hints**: budget shrinks by level (`_maxHintsForLevel`) and each use's penalty grows by level (`_hintPenaltyForLevel`) — see Levels.
- **High score**: single key in `shared_preferences` (`SaveService`), since there's only one game mode.

## Levels (`_level`, `game_screen.dart`)

Went through two corrections on 2026-08-24 before landing here:
1. First cut leveled up every 9 finds *within* a board.
2. User corrected it: a level should only advance once the **whole 99-number board** has been cleared — this version made it endless (no win condition, board-clear always just dealt a fresh board and continued).
3. User corrected it again: there should still be a **win screen on completing the final level** — endless was wrong too.

Current design: `_level` is a plain incrementing counter (not derived) bumped inside `_startRound` when `_found.length >= _totalNumbers` (a board clear) — *unless* `_level >= _maxLevel` (11), in which case that same board-clear calls `_endGame(won: true)` instead of advancing further. `_maxLevel = 11` is exactly the level at which `_roundSecondsForLevel` first bottoms out at its 5s floor (`15 - (11-1) = 5`) — chosen because that's the natural point where the difficulty curve stops changing, so continuing further would be identical to level 11 forever.

Three difficulty-scaling mechanics the user picked from a set of suggestions, all pure functions of `_level` at the top of `game_screen.dart`:
- **Round countdown**: `_roundSecondsForLevel` — starts at 15s (`_baseRoundSeconds`), −1s per level, floors at 5s (`_minRoundSeconds`) at level 11.
- **Score multiplier**: `_scoreMultiplierForLevel` — `1 + (level-1)*0.2`, so a level-11 catch is worth up to 3x a level-1 one.
- **Hint budget**: `_maxHintsForLevel` — steps down 3→2→1→0 every 3 levels (levels 1-3: 3 hints, 4-6: 2, 7-9: 1, 10-11: 0). `_hintsLeft` is clamped (`min`, never increased) against the new cap on every level-up, so leveling up can only take hints away, never refill them.
- **Hint penalty**: `_hintPenaltyForLevel` — `10 + (level-1)*5`, so a hint at level 11 costs 60 points instead of 10.

The **board reshuffle** the user also picked (to stop spatial memorization) is free — advancing a level always deals an entirely fresh `List.generate(...).shuffle()` board, since board-clear and level-up are the same event; there's no separate "shuffle only the still-unfound cells" helper needed.

**`LevelAnnouncement`** (`lib/widgets/level_announcement.dart`) is the "LEVEL N" zoom-in/hold/zoom-out banner shown on every level start (including level 1, at game start) — a plain-Flutter `AnimationController` + `TweenSequence<double>` port of dino-egg-shooter's `AnnouncementText` Flame component (same 0.3s ease-out to 1.15x → 0.2s ease-in to 1.0x → 1.0s hold → 0.5s ease-in to 0x, 2.0s total), since this app has no Flame game loop to hang a Flame component off of. It's `IgnorePointer`-wrapped and non-blocking — the round timer keeps running underneath it, matching the source behavior. It does **not** show on the win itself — `_GameOverOverlay`'s `won: true` state (trophy icon, "YOU WIN!", `sfx_menu_confirm` instead of `sfx_fail`) is the win feedback.

**Testing note**: verifying a level-up via the web-server/Playwright path is expensive since it needs a *full 99-number clear* — a full brute-force grid sweep (99 clicks) only reliably lands one catch per sweep (tap-lock during the 350ms correct-catch delay skips most of the rest of that sweep), so expect on the order of 90-150+ full-grid sweeps to reliably clear one board, and ~11x that to reach an actual win. The 9-per-level version of the level-up mechanic was confirmed working end-to-end (HUD showed "LV 2", 14s countdown) before the full-clear redesign; the current version has been spot-checked for regressions (game boots, HUD/timer/loss overlay all correct, "Level reached: N" shows) but the actual level-11 win trigger has **not** been exercised live — it's a straightforward `if (_level >= _maxLevel)` check, reviewed carefully but not run to completion, since a real run would take on the order of 1000+ scripted clicks.

## Android project is generated, not committed

`android/`, `web/`, etc. are gitignored. CI's `build-apk.yml` regenerates `android/` via `flutter create --platforms=android .` on every run, then patches in the AdMob App ID, raises `minSdk`/`compileSdk` for `google_mobile_ads`, enables release shrinking with WorkManager keep rules (`tool/proguard-rules-extra.pro`), generates the launcher icon from `assets/icon/icon.png`, and wires up release signing if the 4 keystore secrets are set. This is an exact copy of the dino-egg-shooter workflow — see that repo's CLAUDE.md for the reasoning behind each step (WorkManager R8 stripping crash, Kotlin-DSL-vs-Groovy handling, etc.) if any of it needs changing.

## iOS

Android-only until 2026-08-24, when the user asked about an App Store release. This machine is Windows, so there's no local way to build/test iOS at all (Xcode is macOS-only, and there's no Mac anywhere in this setup) — everything iOS happens through CI on a `macos-latest` GitHub Actions runner, including the actual signing (no local Keychain Access to generate a certificate the traditional way).

**Status: real signing is wired up** (as of 2026-08-24, once the user got an Apple Developer Program membership — $99/year, paid, human-only enrollment, was a hard blocker before this). Uses an **App Store Connect API key** rather than a manually-managed Distribution Certificate + Provisioning Profile — deliberately, since that lets `xcodebuild -allowProvisioningUpdates` create/fetch whatever it needs on its own, sidestepping the "no Mac to run Keychain Access" problem entirely. 4 secrets drive it:
- `APPSTORE_API_KEY_P8` — base64 of the `.p8` private key downloaded from App Store Connect → Users and Access → Integrations → App Store Connect API. **Only downloadable once at creation time** — if it's ever lost, a new key has to be generated (the old one revoked), same one-shot-download rule as most API key flows.
- `APPSTORE_API_KEY_ID` — from the same page (also embedded in the `.p8`'s filename, `AuthKey_<KEY_ID>.p8`).
- `APPSTORE_API_ISSUER_ID` — same page, shared across all keys for the account.
- `APPSTORE_TEAM_ID` — the 10-character Apple Developer Team ID (Apple Developer account → Membership, or top of App Store Connect).

`build-ios` (`.github/workflows/build-apk.yml`) checks for `APPSTORE_API_KEY_P8`/`APPSTORE_API_KEY_ID` early (`Configure App Store Connect API key` step, sets a `configured` step output) — every step after that (icon, archive/export, TestFlight upload) is gated on it, so the job cleanly degrades back to the original compile-check-only behavior if the secrets are ever removed. `xcodebuild archive` + `xcodebuild -exportArchive` use `-authenticationKeyPath`/`-authenticationKeyID`/`-authenticationKeyIssuerID` plus `DEVELOPMENT_TEAM`/`CODE_SIGN_STYLE=Automatic` passed directly as build settings on the command line — no `.pbxproj` patching needed (unlike Android's `tool/patch_signing.js`), since xcodebuild accepts these as plain overrides.

**TestFlight upload is opt-in, not automatic** — a `workflow_dispatch` boolean input (`upload_ios`) gates the final `xcrun altool --upload-app` step, and it only runs when the workflow was manually triggered ("Run workflow" in the Actions tab) with that box checked, never on a plain push to `main`. This mirrors the Android job never auto-uploading the `.aab` to Play Console — submitting a build to App Store Connect is a deliberate, occasional action, not something that should happen on every commit. Because there's no Mac, this upload step runs `xcrun altool` *in CI* rather than the usual Transporter-app-on-a-Mac path — the `.p8` gets placed at `~/private_keys/AuthKey_<KEY_ID>.p8` in the "Configure App Store Connect API key" step specifically because that's one of `altool`'s own default search paths, so the upload step doesn't need to pass a key path at all.

**AdMob on iOS has no real App ID yet** — only the Android AdMob app entry exists in the user's account. `Patch Info.plist (AdMob App ID)` falls back to Google's public **iOS** TEST App ID (`ca-app-pub-3940256099942544~1458002511` — note this is a *different* constant than Android's TEST App ID, they're not interchangeable) via an `ADMOB_APP_ID_IOS` secret that isn't set yet. Skipping this patch entirely was not an option: `google_mobile_ads` throws an uncaught `NSException` the moment `MobileAds.instance.initialize()` runs without a `GADApplicationIdentifier` in `Info.plist`, i.e. the app would crash on literally every launch — unlike a missing/placeholder icon, which just looks bad but doesn't crash.

**Launcher icon uses a separate config file, `flutter_launcher_icons_ios.yaml`** (not `pubspec.yaml`'s, which stays `android: true` only) — invoked via `dart run flutter_launcher_icons -f flutter_launcher_icons_ios.yaml`. The first attempt set `ios: true` directly in the shared `pubspec.yaml` config, which broke *both* CI jobs at once: `flutter_launcher_icons` reads whichever config it's pointed at regardless of which job runs it, so with both platforms enabled in one shared file it tried to write iOS icons into the Android job's run (no `ios/` generated there) and Android icons into the iOS job's run (no `android/` generated there) — both failed at "Generate launcher icon" the same way. The separate-file approach keeps each job's icon generation scoped to only the platform it actually has.

**Still not done, for a future pass**: no Game Center capability confirmation beyond what's set in the Apple Developer portal App ID (no code-level check that it's actually enabled); no App Store Connect app-record automation (the user creates that by hand); this has **not yet been confirmed to produce a real uploadable `.ipa`** — see the archive-failure note below for what the first real attempt actually hit.

**Two real failures this caught (2026-09-07), on the first two live runs against a real Apple account:**
1. `error: Communication with Apple failed: Your team has no devices from which to generate a provisioning profile` + `No profiles for 'com.nttqn.number99' were found: ... iOS App Development provisioning profiles`. With only `CODE_SIGN_STYLE=Automatic` + `DEVELOPMENT_TEAM` set and no explicit destination, `xcodebuild archive` resolved a *Development* signing context on its own (Development profiles need registered device UDIDs; Distribution ones don't — that's the actual tell in the error text).
2. First fix attempt — adding `CODE_SIGN_IDENTITY="Apple Distribution"` — traded that for a *different* failure: `Runner has conflicting provisioning settings. Runner is automatically signed for development, but a conflicting code signing identity Apple Distribution has been manually specified`, across *every* target including the Swift-Package-Manager plugin targets (`google_mobile_ads`, `webview_flutter_wkwebview`, etc. — Flutter's iOS builds resolve some plugins via SPM now, not only CocoaPods). Project-wide, not per-target, which pointed at a destination/context problem rather than a per-target signing setting.

**Actual fix**: add `-destination "generic/platform=iOS"` to the `xcodebuild archive` invocation and drop the `CODE_SIGN_IDENTITY` override entirely. Without a `-destination`, automatic signing apparently can't reliably tell "this is a distribution archive, not tied to any device" from `-configuration Release` alone; `generic/platform=iOS` is the standard destination for exactly that intent, and lets automatic signing resolve straight to Distribution on its own. Confirm on the next run whether this is the actual full fix — if `archive` succeeds but `-exportArchive` hits its own wrong-profile-type error, the same destination flag may be needed there too.

## AdMob

`lib/services/admob_service.dart` uses real ad unit IDs from the user's AdMob account (banner `ca-app-pub-9078637596840810/5513332487`, interstitial `.../4829149216` — same account as [[project_dino_egg_shooter]], different ad units). The AdMob **App ID** (a separate value — the `com.google.android.gms.ads.APPLICATION_ID` Android manifest meta-data / iOS `GADApplicationIdentifier`, driven by the `ADMOB_APP_ID` GitHub secret) is still unset for Android, and not wired up for iOS at all yet (see the iOS section above) — Android CI falls back to Google's public TEST App ID until that secret is added.

## Leaderboard (Google Play Games Services)

`lib/services/leaderboard_service.dart` wraps the `games_services` plugin (Android-only here — no iOS build target). Every call is wrapped in try/catch and no-ops silently on failure, the same defensive pattern as `AdmobService` — a leaderboard problem must never crash or interrupt gameplay. Wired in at: `GameScreen.initState`/`MainMenuScreen.initState` call `signIn()`, `_endGame` calls `submitScore(_score)`, and the menu's "BẢNG XẾP HẠNG" button calls `showLeaderboard()` (shows a SnackBar if it returns `false`, e.g. not signed in / not configured).

**Status**: the app (`com.nttqn.number99`) turned out to already have a Play Games Services project and leaderboard from the original 2014 app — nothing needed creating from scratch, just retrieving the existing IDs. `_androidLeaderboardId` in `leaderboard_service.dart` is filled in (`CgkIst2gm-UKEAIQAA`). Still missing: the **Play Games Services App ID** (numeric, shown on the Play Games Services overview page in Play Console) needs to be set as the `PLAY_GAMES_APP_ID` GitHub secret — unlike AdMob there's no universal test ID to fall back to, so CI's "Patch AndroidManifest.xml" step just omits the `com.google.android.gms.games.APP_ID` meta-data (with a `::warning::`) until that secret exists, and sign-in/submit/show all silently no-op without it.

The release keystore (`number99-release.jks`, see below) is the **original 2014 signing key** for this app, provided by the user — not a freshly generated one. This matters because the app already has a real Play Store listing that keystore is tied to; a fresh keystore would have permanently broken the ability to update it. Its SHA-1 (`8F:3A:10:81:33:DE:15:66:69:2F:7F:C5:E1:36:06:44:11:D4:F0:63`) is what the existing Play Games OAuth client is keyed to.

Default sign-in behavior is used (Play Games auto-prompts on launch) — no `MainActivity.kt` changes were needed for this. If the user ever wants sign-in silenced/optional rather than automatic, see the "Prevent auto sign-in on Android" section of the plugin's docs (needs a `PlayGamesInitProvider` manifest removal + `PlayGamesSdk.initialize()` in `MainActivity.kt`, which *would* need a CI patch step since `android/` is regenerated fresh every build).

Not testable via the web-server / Chrome workflow used for everything else in this repo (`games_services` only supports Android/iOS/macOS) — `LeaderboardService`'s platform gate makes it no-op cleanly there, verified via Playwright (button renders, tap shows the "not available" SnackBar, no console errors), but the actual sign-in/submit/show flow can only be verified on a real Android device once the two placeholders above are filled in.

## Release signing

Set up, but atypically — unlike the other games in this series, this one did **not** get a freshly generated keystore. The user provided the **original 2014 signing key** for the already-published `com.nttqn.number99` app (`number99-release.jks`, gitignored, lives in the project root), because generating a new one would have permanently orphaned the existing Play Store listing (Play Store requires updates to be signed with the exact same key). Alias `nttqn`; verified with the same `keytool -keypasswd` old==new trick from [[feedback_release_signing_setup]] before the `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD`/`KEY_ALIAS`/`KEY_PASSWORD` GitHub secrets were handed off (both before and after a base64 round-trip). SHA-1: `8F:3A:10:81:33:DE:15:66:69:2F:7F:C5:E1:36:06:44:11:D4:F0:63` — this is also what the existing Play Games Services OAuth client is keyed to (see the Leaderboard section above).

If this project ever needs a *new* keystore for some other reason, [[feedback_release_signing_setup]] still has the generation flow — just don't reach for it reflexively here the way earlier games in this series did, since this repo's whole point is continuity with a key that already exists.

## Icon

`assets/icon/icon.png` started as a placeholder generated with PowerShell + `System.Drawing` (no ImageMagick on this machine — see [[user_dev_machine_tooling]]), then replaced with real user-provided art (1254x1254, magnifying glass over the number grid). Swap the file any time; nothing else needs to change (`flutter_launcher_icons` config lives in `pubspec.yaml`, regenerated by CI on every build).

## Sound (`lib/services/sound_service.dart`)

Same `flame_audio` + `AudioPool` pattern as dino-egg-shooter (`lib/services/sound_service.dart` there) — deliberately, per explicit user instruction, to avoid the exact delay/lag bug that pattern was built to fix: `FlameAudio.play()` spins up a new native `AudioPlayer` per call and never disposes it, which is fine for a rare sound but audibly degrades over a session for sounds fired on every tap. `createPool(file, maxPlayers: N)` once at startup + `pool.start()` per play avoids it.

Five effects, sourced from `sound_src/*.wav` (gitignored, only the copies in `assets/audio/` ship) and mapped **by which button was pressed, not by game outcome** — there's no separate "correct" vs "wrong" tap sound, and no separate "win" vs "lose" sound, because only these 5 files exist:
- `sfx_menu_confirm`: forward-moving taps — PLAY, LEADERBOARD, PAUSE (opening it), RESTART (all three: bottom bar, pause overlay, game-over overlay), MENU (exiting to the main menu from either overlay).
- `sfx_menu_back`: backward-moving taps — the pause overlay's RESUME button, and the Android system back button (see the PopScope section above) — both directions of the back-button pause toggle play this, only the on-screen PAUSE/RESUME button's *tap* differs by state (`_paused ? playMenuBack : playMenuConfirm`, since the same button flips between opening and closing pause).
- `sfx_hint`: the HINT button.
- `sfx_select`: any tap on a number cell, whether it turns out right or wrong.
- `sfx_fail`: every `_endGame()` call, win or lose — there's no `sfx_win`, so this is the only "round over" sound available and covers both.

A mute toggle was added 2026-08-24 (initially skipped, then requested) — `enabledNotifier`/`setEnabled`/`shared_preferences` persistence, same as dino-egg-shooter's `SoundService`. Lives as a `Switch` in the pause overlay (`_PauseOverlay`, `game_screen.dart`), not the main menu.

**A `MissingPluginException` on the `xyz.luan/audioplayers.global/events` channel shows up in the browser console during local `flutter run -d web-server` testing** — this is a real gap in `audioplayers`' web support, not a bug in this app or a stale build; it doesn't crash anything (every play call is try/caught) and doesn't matter for shipping, since this app only builds for Android. Don't spend time chasing it.
