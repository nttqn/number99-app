import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob wiring for this app. The ad unit IDs below are Google's public
/// TEST ids — placeholders until this app has its own AdMob account
/// entries. Swap them for real ad unit IDs (and set the ADMOB_APP_ID CI
/// secret, see build-apk.yml) before a Play Store release; see
/// [[feedback_release_signing_setup]] / dino-egg-shooter's admob_service.dart
/// for how a sibling project wired real ones in.
///
/// google_mobile_ads only supports Android/iOS; every entry point here
/// no-ops elsewhere (web, desktop) so the game stays testable in those
/// environments during development.
class AdmobService {
  static const _bannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _interstitialId = 'ca-app-pub-3940256099942544/1033173712';

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
