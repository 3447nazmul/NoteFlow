import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app_config_service.dart';

class AdService {
  final AppConfigService _configService;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  AdService(this._configService) {
    _configService.addListener(_onConfigChanged);
    _loadInterstitialAd();
  }

  void _onConfigChanged() {
    if (_configService.showAds && _interstitialAd == null && !_isInterstitialAdLoading) {
      _loadInterstitialAd();
    }
  }

  void _loadInterstitialAd() {
    if (!_configService.showAds) return;
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    _isInterstitialAdLoading = true;
    final adUnitId = _configService.admobInterstitialId;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint('InterstitialAd loaded.');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              // Pre-load the next ad
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              if (kDebugMode) debugPrint('InterstitialAd failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdLoading = false;
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (!_configService.showAds) return;

    if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      if (kDebugMode) debugPrint('InterstitialAd is not ready yet.');
      _loadInterstitialAd(); // Try loading it again
    }
  }

  void dispose() {
    _configService.removeListener(_onConfigChanged);
    _interstitialAd?.dispose();
  }
}
