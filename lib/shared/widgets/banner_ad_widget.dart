import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../services/app_config_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  late AppConfigService _configService;

  @override
  void initState() {
    super.initState();
    _configService = context.read<AppConfigService>();
    _configService.addListener(_onConfigChanged);
    _loadAd();
  }

  void _onConfigChanged() {
    if (mounted) {
      if (_configService.showAds && _bannerAd == null) {
        _loadAd();
      } else if (!_configService.showAds && _bannerAd != null) {
        _bannerAd?.dispose();
        setState(() {
          _bannerAd = null;
          _isLoaded = false;
        });
      }
    }
  }

  void _loadAd() {
    if (!_configService.showAds) return;

    _bannerAd = BannerAd(
      adUnitId: _configService.admobBannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _configService.removeListener(_onConfigChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_configService.showAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
