
import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService with WidgetsBindingObserver {
  static final AdService instance = AdService._internal();

  AdService._internal();

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void>? _initializationFuture;
  bool _observerAdded = false;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 6);

  static const int _taskThreshold = 3;
  static const Duration _cooldownDuration = Duration(minutes: 2);

  int _successfulTaskCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime? _lastFullScreenAdTime;

  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;

  bool _isInterstitialLoading = false;
  bool _isDisposed = false;

  // Official Google test device ID suggested by the SDK.
  static const String _testDeviceId =
      '7E4655AA84511F58B209831948984D31';

  // Official Google Test Ad Unit IDs.

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    return 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return 'ca-app-pub-3940256099942544/4411468910';
  }

  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    return 'ca-app-pub-3940256099942544/3986624511';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    return 'ca-app-pub-3940256099942544/1712485313';
  }

  static String get appOpenAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/9257395921';
    }
    return 'ca-app-pub-3940256099942544/5575463023';
  }

  // Initialization

  Future<void> initialize() {
    return _initializationFuture ??= _initializeAds();
  }

  Future<void> _initializeAds() async {
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: Platform.isAndroid
              ? <String>[_testDeviceId]
              : <String>[],
        ),
      );

      await MobileAds.instance.initialize();

      if (!_observerAdded) {
        WidgetsBinding.instance.addObserver(this);
        _observerAdded = true;
      }

      debugPrint('AdMob initialized successfully');
      debugPrint('AdMob test device configured: $_testDeviceId');

      if (!_isPremium) {
        preloadInterstitial();
      }
    } catch (e) {
      debugPrint('AdMob initialization error: $e');
      _initializationFuture = null;
      rethrow;
    }
  }

  // Premium

  void setPremium(bool premium) {
    _isPremium = premium;

    if (premium) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _successfulTaskCount = 0;
    } else {
      preloadInterstitial();
    }
  }

  // App lifecycle

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPremium || _isDisposed) return;

    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed');
      preloadInterstitial();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('App paused');
    }
  }

  // Retry delay: 6, 12, 24 seconds.

  Duration _getRetryDelay(int attempt) {
    return Duration(seconds: _retryDelay.inSeconds * (1 << attempt));
  }

  // Interstitial

  void preloadInterstitial({int attempt = 0}) {
    if (_isPremium ||
        _isDisposed ||
        _interstitialAd != null ||
        _isInterstitialLoading) {
      return;
    }

    _isInterstitialLoading = true;

    debugPrint('Loading interstitial ad. Attempt ${attempt + 1}');

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isInterstitialLoading = false;

          if (_isPremium || _isDisposed) {
            ad.dispose();
            return;
          }

          _interstitialAd = ad;
          debugPrint('Interstitial Ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;

          debugPrint(
            'Interstitial failed: ${error.code} - ${error.message}',
          );

          if (attempt < _maxRetries &&
              !_isPremium &&
              !_isDisposed) {
            final delay = _getRetryDelay(attempt);

            debugPrint(
              'Retrying interstitial in ${delay.inSeconds} seconds',
            );

            Future.delayed(delay, () {
              if (!_isPremium && !_isDisposed) {
                preloadInterstitial(attempt: attempt + 1);
              }
            });
          } else {
            debugPrint('Interstitial retry limit reached');
          }
        },
      ),
    );
  }

  void showInterstitialIfEligible(
      BuildContext context,
      VoidCallback onComplete,
      ) {
    if (_isPremium) {
      onComplete();
      return;
    }

    _successfulTaskCount++;

    final bool isCountEligible =
        _successfulTaskCount >= _taskThreshold;

    final bool isCooldownPassed =
        _lastInterstitialTime == null ||
            DateTime.now().difference(_lastInterstitialTime!) >=
                _cooldownDuration;

    final bool isRecentFullScreen =
        _lastFullScreenAdTime != null &&
            DateTime.now().difference(_lastFullScreenAdTime!) <
                const Duration(seconds: 30);

    if (isCountEligible &&
        isCooldownPassed &&
        !isRecentFullScreen &&
        _interstitialAd != null) {
      final ad = _interstitialAd!;
      _interstitialAd = null;

      _lastFullScreenAdTime = DateTime.now();

      ad.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _resetFrequencyCounters();
              preloadInterstitial();
              onComplete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial show error: ${error.message}');
              ad.dispose();
              _resetFrequencyCounters();
              preloadInterstitial();
              onComplete();
            },
          );

      ad.show();
    } else {
      if (isCountEligible && _interstitialAd == null) {
        preloadInterstitial();
      }

      onComplete();
    }
  }

  void _resetFrequencyCounters() {
    _successfulTaskCount = 0;
    _lastInterstitialTime = DateTime.now();
  }

  // Banner

  BannerAd? createHomeBannerAd({
    VoidCallback? onAdLoaded,
  }) {
    if (_isPremium || _isDisposed) return null;

    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner Ad loaded successfully');

          if (!_isPremium && onAdLoaded != null) {
            onAdLoaded();
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'Banner failed: ${error.code} - ${error.message}',
          );
          ad.dispose();
        },
      ),
    );

    banner.load();
    return banner;
  }

  // Rewarded Ad

  void showRewardedAd({
    required VoidCallback onRewarded,
    required VoidCallback onAdDismissed,
    int attempt = 0,
  }) {
    if (_isPremium || _isDisposed) {
      onAdDismissed();
      return;
    }

    debugPrint('Loading rewarded ad. Attempt ${attempt + 1}');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_isPremium || _isDisposed) {
            ad.dispose();
            onAdDismissed();
            return;
          }

          debugPrint('Rewarded Ad loaded successfully');

          bool completed = false;

          void finish() {
            if (completed) return;
            completed = true;
            onAdDismissed();
          }

          ad.fullScreenContentCallback =
              FullScreenContentCallback(
                onAdDismissedFullScreenContent: (ad) {
                  ad.dispose();
                  finish();
                },
                onAdFailedToShowFullScreenContent: (ad, error) {
                  debugPrint(
                    'Rewarded show failed: ${error.message}',
                  );
                  ad.dispose();
                  finish();
                },
              );

          ad.show(
            onUserEarnedReward: (
                AdWithoutView ad,
                RewardItem reward,
                ) {
              onRewarded();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint(
            'Rewarded failed: ${error.code} - ${error.message}',
          );

          if (attempt < _maxRetries &&
              !_isPremium &&
              !_isDisposed) {
            final delay = _getRetryDelay(attempt);

            debugPrint(
              'Retrying rewarded ad in ${delay.inSeconds} seconds',
            );

            Future.delayed(delay, () {
              if (!_isPremium && !_isDisposed) {
                showRewardedAd(
                  onRewarded: onRewarded,
                  onAdDismissed: onAdDismissed,
                  attempt: attempt + 1,
                );
              }
            });
          } else {
            debugPrint('Rewarded retry limit reached');
            onAdDismissed();
          }
        },
      ),
    );
  }

  // Dispose

  void dispose() {
    _isDisposed = true;

    _interstitialAd?.dispose();
    _interstitialAd = null;

    _appOpenAd?.dispose();
    _appOpenAd = null;

    _isInterstitialLoading = false;

    if (_observerAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAdded = false;
    }

    debugPrint('AdService disposed');
  }
}
