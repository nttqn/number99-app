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
}
