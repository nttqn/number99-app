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

**Status: real signing is wired up, via manual signing** (as of 2026-09-07, once the user got an Apple Developer Program membership — $99/year, paid, human-only enrollment, was a hard blocker before this).

**Automatic signing (`-allowProvisioningUpdates` + an App Store Connect API key) was the first approach and it did not work**, failing two different ways across two live attempts against the real Apple account, both pointing at the same root problem: in a headless CI runner with no device attached and no interactive Xcode session, automatic signing could not reliably be told "this archive is for Distribution, not Development" no matter what `-destination`/`-configuration`/override combination was tried:
1. `error: Communication with Apple failed: Your team has no devices from which to generate a provisioning profile` + `No profiles for 'com.nttqn.number99' were found: ... iOS App Development provisioning profiles`. Development profiles need registered device UDIDs; Distribution ones don't — that mismatch is what the error text actually meant.
2. Adding `CODE_SIGN_IDENTITY="Apple Distribution"` traded that for `Runner has conflicting provisioning settings. Runner is automatically signed for development, but a conflicting code signing identity Apple Distribution has been manually specified` — across *every* target, including the Swift-Package-Manager plugin targets (`google_mobile_ads`, `webview_flutter_wkwebview`, etc. — Flutter's iOS builds now resolve some plugins via SPM, not only CocoaPods), confirming a project-wide destination/context problem rather than a per-target signing quirk. Adding `-destination "generic/platform=iOS"` on top of that (the standard "distribution, not tied to a device" destination) did **not** fix it either — the exact same "no devices" error from attempt 1 came back.

**What actually works: manual signing with a real Distribution certificate + App Store provisioning profile**, the documented pattern for headless/no-device CI (e.g. https://damienaicheh.github.io/flutter/github/actions/2021/04/22/build-sign-flutter-ios-github-actions-en.html). Since there's still no Mac for Keychain Access, the certificate itself was created without one:
1. Generated a CSR + private key locally with plain `openssl req -new -newkey rsa:2048 -nodes` (works on any OS — `MSYS_NO_PATHCONV=1` needed in this Git-Bash-on-Windows environment, otherwise MSYS mangles the leading `/emailAddress=...` subject string into a path).
2. User uploaded the CSR to the Apple Developer portal (Certificates → "+" → Apple Distribution) and downloaded the resulting `.cer`.
3. Converted `.cer` (DER) to PEM (`openssl x509 -inform DER`) and combined it with the original private key into a `.p12` (`openssl pkcs12 -export`), password-protected with a generated password. Verified it opens (`openssl pkcs12 -info`) before handing off the password, same discipline as [[feedback_release_signing_setup]]'s keystore verification.
4. User created an App Store provisioning profile in the portal (Profiles → "+" → App Store → App ID `com.nttqn.number99` → the Distribution cert from step 2 → named it "number99 App Store") and downloaded the `.mobileprovision`. Decoded it locally with `openssl smime -inform DER -verify -noverify` to confirm its embedded bundle ID, name, and — importantly — the *absence* of a `ProvisionedDevices` key (confirming it's really an App Store profile, not Ad Hoc) before trusting it. Its entitlements also confirmed `com.apple.developer.game-center = true`, i.e. the Game Center capability really is enabled on the App ID.

3 secrets drive this: `IOS_DIST_P12_BASE64` (base64 of the `.p12`), `IOS_DIST_P12_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64` (base64 of the `.mobileprovision`). `build-ios`'s `Import signing certificate` step checks for these early and sets a `configured` step output — every step after (cert install, profile install, archive/export, TestFlight upload) is gated on it, so the job cleanly degrades to compile-check-only if they're ever removed. Certificate import uses the `apple-actions/import-codesign-certs@v3` action (handles the temporary-keychain create/unlock/cleanup dance that would otherwise be several `security` CLI calls); the profile is just copied into `~/Library/MobileDevice/Provisioning Profiles/`. The `archive` invocation uses `CODE_SIGN_STYLE=Manual`, `CODE_SIGN_IDENTITY="Apple Distribution"`, `PROVISIONING_PROFILE_SPECIFIER="number99 App Store"` (the profile's exact name — the modern replacement for the older UUID-based `PROVISIONING_PROFILE=`), plus `DEVELOPMENT_TEAM` and `-destination "generic/platform=iOS"`; `ExportOptions.plist` mirrors the same manual signing style and profile mapping. **Not yet confirmed to succeed on a live CI run** — this rewrite hasn't been exercised yet.

The 4 App Store Connect API key secrets from the abandoned automatic-signing attempt (`APPSTORE_API_KEY_P8`/`_KEY_ID`/`_ISSUER_ID`/`_TEAM_ID`) weren't wasted — `APPSTORE_TEAM_ID` is still used for `DEVELOPMENT_TEAM`/`ExportOptions.plist`'s `teamID`, and all 4 are what the **TestFlight upload** step (`xcrun altool --upload-app`) authenticates with. That upload is opt-in, not automatic — a `workflow_dispatch` boolean input (`upload_ios`) gates it, only running on a manual "Run workflow" trigger with the box checked, never on a plain push to `main` (same reasoning as the Android job never auto-uploading the `.aab` to Play Console — submitting a build to App Store Connect should be deliberate). Because there's no Mac to run Transporter or `xcrun altool` locally, this upload step runs `xcrun altool` *inside CI* instead — the `.p8` gets placed at `~/private_keys/AuthKey_<KEY_ID>.p8`, one of `altool`'s own default search paths, so no key-path flag is needed.

**AdMob on iOS has no real App ID yet** — only the Android AdMob app entry exists in the user's account. `Patch Info.plist (AdMob App ID)` falls back to Google's public **iOS** TEST App ID (`ca-app-pub-3940256099942544~1458002511` — note this is a *different* constant than Android's TEST App ID, they're not interchangeable) via an `ADMOB_APP_ID_IOS` secret that isn't set yet. Skipping this patch entirely was not an option: `google_mobile_ads` throws an uncaught `NSException` the moment `MobileAds.instance.initialize()` runs without a `GADApplicationIdentifier` in `Info.plist`, i.e. the app would crash on literally every launch — unlike a missing/placeholder icon, which just looks bad but doesn't crash.

**Launcher icon uses a separate config file, `flutter_launcher_icons_ios.yaml`** (not `pubspec.yaml`'s, which stays `android: true` only) — invoked via `dart run flutter_launcher_icons -f flutter_launcher_icons_ios.yaml`. The first attempt set `ios: true` directly in the shared `pubspec.yaml` config, which broke *both* CI jobs at once: `flutter_launcher_icons` reads whichever config it's pointed at regardless of which job runs it, so with both platforms enabled in one shared file it tried to write iOS icons into the Android job's run (no `ios/` generated there) and Android icons into the iOS job's run (no `android/` generated there) — both failed at "Generate launcher icon" the same way. The separate-file approach keeps each job's icon generation scoped to only the platform it actually has.

**Still not done, for a future pass**: no code-level check that Game Center is actually enabled (only confirmed by inspecting the provisioning profile's entitlements once, above); no App Store Connect app-record automation (the user creates that by hand); the manual-signing rewrite above has **not yet been confirmed to succeed end-to-end** on a real CI run.

**A third real failure this caught (2026-09-07)**: manual signing itself worked for the `Runner` target, but the archive still failed — this time on the *plugin* targets: `google_mobile_ads_google_mobile_ads does not support provisioning profiles ... Set the provisioning profile value to "Automatic"`, same for `shared_preferences_foundation` and `webview_flutter_wkwebview`. Root cause: Flutter 3.24+ defaults iOS plugin resolution to **Swift Package Manager**, which turns each plugin into its own `Package.swift` target — and `xcodebuild`'s command-line `CODE_SIGN_STYLE=Manual`/`PROVISIONING_PROFILE_SPECIFIER=...` overrides apply to *every* target in the project, not just the one being archived, so they landed on these plugin targets too, and SPM package targets categorically don't support having a provisioning profile at all (this is a known, unresolved Apple/Xcode bug when manually signing via `xcodebuild` from the command line, not anything specific to this project — see Apple Developer Forums thread 713276, reported as FB11402077, still open years later). **Fix**: `flutter config --no-enable-swift-package-manager` before `flutter create`, forcing plugin resolution back to CocoaPods (the older, more mature path all Flutter iOS builds used for years before Flutter 3.44 made SPM the default) — this makes plugins resolve as Pods embedded in one aggregate framework that signs normally alongside `Runner`, sidestepping the multi-target signing conflict entirely rather than trying to fix it. This is a Flutter **tool**-level setting, not a project one, so it has to be set on every fresh CI runner (added as its own step, before `flutter create`).

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
