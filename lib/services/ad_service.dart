import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'feature_settings.dart';

class AdService {
  AdService._();
  static final instance = AdService._();


  bool _initialized = false;
  int _navigationCount = 0;
  DateTime? _lastInterstitialAt;
  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;

  bool get supported {
    if (kIsWeb) return false;
    final hasIds = defaultTargetPlatform == TargetPlatform.iOS
        ? (AdConfig.iosBannerId.isNotEmpty && AdConfig.iosInterstitialId.isNotEmpty)
        : (AdConfig.androidBannerId.isNotEmpty && AdConfig.androidInterstitialId.isNotEmpty);
    return hasIds && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
  }

  String get bannerAdUnitId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? AdConfig.iosBannerId
        : AdConfig.androidBannerId;
  }

  String get interstitialAdUnitId {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? AdConfig.iosInterstitialId
        : AdConfig.androidInterstitialId;
  }

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  void _loadInterstitial() {
    if (!supported || !_initialized || _loadingInterstitial) return;
    if (_interstitialAd != null) return;

    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void onUserNavigation() {
    if (!supported) return;
    _navigationCount++;

    final now = DateTime.now();
    final recentlyShown = _lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!).inSeconds < 120;

    if (_navigationCount < 4 || recentlyShown) {
      _loadInterstitial();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    _navigationCount = 0;
    _lastInterstitialAt = now;
    _interstitialAd = null;
    ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}

class KcnAdBanner extends StatefulWidget {
  const KcnAdBanner({super.key, this.margin = const EdgeInsets.symmetric(vertical: 8)});

  final EdgeInsets margin;

  @override
  State<KcnAdBanner> createState() => _KcnAdBannerState();
}

class _KcnAdBannerState extends State<KcnAdBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdService.instance.supported) return;

    final banner = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() => _loaded = false);
        },
      ),
    );
    _banner = banner;
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _banner == null) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: FeatureSettings.instance.isEnabled('adMobEnabled'),
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? true;
        if (!enabled) return const SizedBox.shrink();

        return Padding(
          padding: widget.margin,
          child: Center(
            child: SizedBox(
              width: _banner!.size.width.toDouble(),
              height: _banner!.size.height.toDouble(),
              child: AdWidget(ad: _banner!),
            ),
          ),
        );
      },
    );
  }}
