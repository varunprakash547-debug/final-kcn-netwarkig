class AdConfig {
  const AdConfig._();

  // Production AdMob IDs are intentionally empty until the real KCN
  // AdMob app/unit IDs are supplied by the owner.
  // Do not ship Google's sample/test IDs in production builds.
  static const androidAppId = '';
  static const iosAppId = '';
  static const androidBannerId = '';
  static const iosBannerId = '';
  static const androidInterstitialId = '';
  static const iosInterstitialId = '';
}
