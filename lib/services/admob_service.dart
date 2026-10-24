import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wiring for this app. Real ad unit IDs (same AdMob account as
/// dino-egg-shooter, different ad units) — **platform-specific**, since
/// AdMob ad units are tied to a single platform's app entry and an
/// Android-created ID silently fails to serve on iOS (and vice versa). The
/// AdMob **App ID** (used in AndroidManifest.xml's meta-data /
/// Info.plist's GADApplicationIdentifier, separate from these ad unit IDs)
/// is set via the ADMOB_APP_ID/ADMOB_APP_ID_IOS GitHub secrets in
/// build-apk.yml.
///
/// google_mobile_ads only supports Android/iOS; every entry point here
/// no-ops elsewhere (web, desktop) so the game stays testable in those
/// environments during development.
class AdmobService {
  static const _androidBannerId = 'ca-app-pub-9078637596840810/5513332487';
  static const _androidInterstitialId =
      'ca-app-pub-9078637596840810/4829149216';
  static const _iosBannerId = 'ca-app-pub-9078637596840810/8238701170';
  static const _iosInterstitialId = 'ca-app-pub-9078637596840810/3860472463';

  static String get _bannerId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosBannerId
      : _androidBannerId;

  static String get _interstitialId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _iosInterstitialId
      : _androidInterstitialId;

  // Rewarded ad units (revive / extra hint, v1.3.0).
  static const _androidRewardedId = 'ca-app-pub-9078637596840810/4721117207';
  static const _iosRewardedId = 'ca-app-pub-9078637596840810/3408035537';

  static String get _rewardedId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosRewardedId
      : _androidRewardedId;

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_isSupported) return;
    await MobileAds.instance.initialize();
  }

  static BannerAd? createBanner({
    AdSize size = AdSize.banner,
    void Function()? onLoaded,
  }) {
    if (!_isSupported) return null;
    final banner = BannerAd(
      adUnitId: _bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  static InterstitialAd? _interstitial;

  /// Starts loading an interstitial in the background so it's ready by the
  /// time [showInterstitial] is called (e.g. on the game-over screen).
  static void preloadInterstitial() {
    if (!_isSupported) return;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready, then starts loading
  /// the next one. No-ops silently if none is ready — never blocks play.
  static void showInterstitial() {
    if (!_isSupported) return;
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadInterstitial();
      },
    );
    ad.show();
  }

  static RewardedAd? _rewarded;

  /// Whether a rewarded ad is loaded and [showRewarded] would show one —
  /// the revive/extra-hint offers only appear when this is true.
  static bool get rewardedReady => _rewarded != null;

  static void preloadRewarded() {
    if (!_isSupported || _rewarded != null) return;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Shows the preloaded rewarded ad. Completes with whether the player
  /// earned the reward (watched to the end), once the ad is dismissed —
  /// the game stays paused until then.
  static Future<bool> showRewarded() {
    final ad = _rewarded;
    if (!_isSupported || ad == null) return Future.value(false);
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }
}
