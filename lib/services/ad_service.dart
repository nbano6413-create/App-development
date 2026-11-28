import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService with WidgetsBindingObserver {
  static final AdService instance = AdService._internal();

  AdService._internal();

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void>? _initializationFuture;
  bool _observerAdded = false;
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 6);

  static int get _taskThreshold => kDebugMode ? 1 : 3;

  static Duration get _cooldownDuration =>
      kDebugMode ? Duration.zero : const Duration(minutes: 2);

  int _successfulTaskCount = 0;
  DateTime? _lastInterstitialTime;
  DateTime? _lastFullScreenAdTime;

  bool _isShowingFullScreenAd = false;
  bool get isShowingFullScreenAd => _isShowingFullScreenAd;

  // Ad references
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenAdLoadTime;

  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;
  bool _isAppOpenAdLoading = false;

  VoidCallback? _pendingRewardedOnReward;
  VoidCallback? _pendingRewardedOnDismiss;

  static const String _testDeviceId = '7E4655AA84511F58B209831948984D31';

  // --- Official Google Test Ad Unit IDs (Android) ---
  static const String _testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testNativeAdUnitIdAndroid = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testAppOpenAdUnitIdAndroid = 'ca-app-pub-3940256099942544/9257395921';

  // --- Official Google Test Ad Unit IDs (iOS) ---
  static const String _testBannerAdUnitIdIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAdUnitIdIos = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testNativeAdUnitIdIos = 'ca-app-pub-3940256099942544/3986624511';
  static const String _testRewardedAdUnitIdIos = 'ca-app-pub-3940256099942544/1712485313';
  static const String _testAppOpenAdUnitIdIos = 'ca-app-pub-3940256099942544/5632435107';

  // Ad Unit ID Getters (Always returning official Google test IDs)

  static String get bannerAdUnitId {
    return Platform.isAndroid ? _testBannerAdUnitIdAndroid : _testBannerAdUnitIdIos;
  }

  static String get interstitialAdUnitId {
    return Platform.isAndroid ? _testInterstitialAdUnitIdAndroid : _testInterstitialAdUnitIdIos;
  }

  static String get nativeAdUnitId {
    return Platform.isAndroid ? _testNativeAdUnitIdAndroid : _testNativeAdUnitIdIos;
  }

  static String get rewardedAdUnitId {
    return Platform.isAndroid ? _testRewardedAdUnitIdAndroid : _testRewardedAdUnitIdIos;
  }

  static String get appOpenAdUnitId {
    return Platform.isAndroid ? _testAppOpenAdUnitIdAndroid : _testAppOpenAdUnitIdIos;
  }

  // Initialization

  Future<void> initialize() {
    if (_isDisposed) {
      return Future.error(StateError('AdService has been disposed'));
    }

    return _initializationFuture ??= _initializeAds();
  }

  Future<void> _initializeAds() async {
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: Platform.isAndroid ? <String>[_testDeviceId] : <String>[],
        ),
      );

      await MobileAds.instance.initialize();

      _isInitialized = true;

      if (!_observerAdded) {
        WidgetsBinding.instance.addObserver(this);
        _observerAdded = true;
      }

      debugPrint('Google Mobile Ads SDK initialized successfully (Mode: Official Google Test Ads)');

      if (!_isPremium) {
        preloadInterstitial();
        preloadRewardedAd();
        preloadAppOpenAd();
      }
    } catch (e) {
      debugPrint('AdMob initialization error: $e');
      _initializationFuture = null;
      rethrow;
    }
  }

  // Premium Management

  void setPremium(bool premium) {
    _isPremium = premium;

    if (premium) {
      _interstitialAd?.dispose();
      _interstitialAd = null;

      _rewardedAd?.dispose();
      _rewardedAd = null;

      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenAdLoadTime = null;

      _successfulTaskCount = 0;
      _pendingRewardedOnReward = null;
      _pendingRewardedOnDismiss = null;
    } else if (_isInitialized && !_isDisposed) {
      preloadInterstitial();
      preloadRewardedAd();
      preloadAppOpenAd();
    }
  }

  // App Lifecycle Handling

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPremium || _isDisposed || !_isInitialized) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      debugPrint('App resumed -> Checking App Open Ad eligibility');
      showAppOpenAdIfAvailable();

      preloadInterstitial();
      preloadRewardedAd();
    }
  }

  Duration _getRetryDelay(int attempt) {
    return Duration(
      seconds: _retryDelay.inSeconds * (1 << attempt),
    );
  }

  // App Open Ad Implementation

  bool get _isAppOpenAdAvailable {
    if (_appOpenAd == null || _appOpenAdLoadTime == null) return false;
    // App Open Ads expire after 4 hours per Google guidelines
    final isExpired = DateTime.now().difference(_appOpenAdLoadTime!) > const Duration(hours: 4);
    if (isExpired) {
      debugPrint('App Open Ad expired (>4h). Disposing.');
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenAdLoadTime = null;
      return false;
    }
    return true;
  }

  void preloadAppOpenAd({int attempt = 0}) {
    if (!_isInitialized ||
        _isPremium ||
        _isDisposed ||
        _isAppOpenAdAvailable ||
        _isAppOpenAdLoading) {
      return;
    }

    _isAppOpenAdLoading = true;
    debugPrint('Loading App Open Ad (Attempt ${attempt + 1})...');

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isAppOpenAdLoading = false;
          if (_isPremium || _isDisposed) {
            ad.dispose();
            return;
          }
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
          debugPrint('App Open Ad loaded successfully');
        },
        onAdFailedToLoad: (error) {
          _isAppOpenAdLoading = false;
          _appOpenAd = null;
          _appOpenAdLoadTime = null;
          debugPrint('App Open Ad failed to load: ${error.code} - ${error.message}');

          if (attempt < _maxRetries && !_isPremium && !_isDisposed) {
            final delay = _getRetryDelay(attempt);
            Future.delayed(delay, () {
              if (!_isPremium && !_isDisposed) {
                preloadAppOpenAd(attempt: attempt + 1);
              }
            });
          }
        },
      ),
    );
  }

  void showAppOpenAdIfAvailable() {
    if (_isPremium || _isDisposed || _isShowingFullScreenAd) {
      return;
    }

    if (!_isAppOpenAdAvailable) {
      preloadAppOpenAd();
      return;
    }

    final ad = _appOpenAd!;
    _appOpenAd = null;
    _appOpenAdLoadTime = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingFullScreenAd = true;
        _lastFullScreenAdTime = DateTime.now();
        debugPrint('App Open Ad displayed');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingFullScreenAd = false;
        debugPrint('App Open Ad dismissed');
        ad.dispose();
        preloadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingFullScreenAd = false;
        debugPrint('App Open Ad failed to show: ${error.message}');
        ad.dispose();
        preloadAppOpenAd();
      },
    );

    try {
      ad.show();
    } catch (e) {
      _isShowingFullScreenAd = false;
      debugPrint('App Open Ad show exception: $e');
      ad.dispose();
      preloadAppOpenAd();
    }
  }

  // Interstitial Ad Implementation

  void preloadInterstitial({int attempt = 0}) {
    if (!_isInitialized ||
        _isPremium ||
        _isDisposed ||
        _interstitialAd != null ||
        _isInterstitialLoading) {
      return;
    }

    _isInterstitialLoading = true;
    debugPrint('Loading Interstitial Ad (Attempt ${attempt + 1})...');

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
          debugPrint('Interstitial Ad failed: ${error.code} - ${error.message}');

          if (attempt < _maxRetries && !_isPremium && !_isDisposed) {
            final delay = _getRetryDelay(attempt);
            debugPrint('Retrying Interstitial in ${delay.inSeconds}s');
            Future.delayed(delay, () {
              if (!_isPremium && !_isDisposed) {
                preloadInterstitial(attempt: attempt + 1);
              }
            });
          }
        },
      ),
    );
  }

  void showInterstitialIfEligible(
    BuildContext context,
    VoidCallback onComplete,
  ) {
    if (_isPremium || _isDisposed) {
      onComplete();
      return;
    }

    _successfulTaskCount++;

    final bool isCountEligible = _successfulTaskCount >= _taskThreshold;
    final bool isCooldownPassed = _lastInterstitialTime == null ||
        DateTime.now().difference(_lastInterstitialTime!) >= _cooldownDuration;
    final bool isRecentFullScreen = _lastFullScreenAdTime != null &&
        DateTime.now().difference(_lastFullScreenAdTime!) < const Duration(seconds: 30);

    if (isCountEligible &&
        isCooldownPassed &&
        !isRecentFullScreen &&
        !_isShowingFullScreenAd &&
        _interstitialAd != null) {
      final ad = _interstitialAd!;
      _interstitialAd = null;
      _lastFullScreenAdTime = DateTime.now();

      bool completed = false;

      void finish() {
        if (completed) return;
        completed = true;
        _isShowingFullScreenAd = false;
        _resetFrequencyCounters();
        preloadInterstitial();
        onComplete();
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _isShowingFullScreenAd = true;
          debugPrint('Interstitial Ad displayed');
        },
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('Interstitial Ad dismissed');
          ad.dispose();
          finish();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Interstitial show failed: ${error.message}');
          ad.dispose();
          finish();
        },
      );

      try {
        ad.show();
      } catch (e) {
        debugPrint('Interstitial display exception: $e');
        ad.dispose();
        finish();
      }
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

  // Banner Ad Implementation

  BannerAd? createHomeBannerAd({
    VoidCallback? onAdLoaded,
    VoidCallback? onAdFailed,
  }) {
    if (!_isInitialized || _isPremium || _isDisposed) {
      return null;
    }

    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Banner Ad loaded successfully');
          if (!_isPremium && !_isDisposed) {
            onAdLoaded?.call();
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner Ad failed to load: ${error.code} - ${error.message}');
          ad.dispose();
          onAdFailed?.call();
        },
      ),
    );

    banner.load();
    return banner;
  }

  // Rewarded Ad Implementation

  void preloadRewardedAd({int attempt = 0}) {
    if (!_isInitialized ||
        _isPremium ||
        _isDisposed ||
        _rewardedAd != null ||
        _isRewardedLoading) {
      return;
    }

    _isRewardedLoading = true;
    debugPrint('Loading Rewarded Ad (Attempt ${attempt + 1})...');

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _isRewardedLoading = false;
          if (_isPremium || _isDisposed) {
            ad.dispose();
            return;
          }
          _rewardedAd = ad;
          debugPrint('Rewarded Ad preloaded successfully');

          if (_pendingRewardedOnDismiss != null) {
            _showLoadedRewardedAd();
          }
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          debugPrint('Rewarded Ad failed: ${error.code} - ${error.message}');

          if (attempt < _maxRetries && !_isPremium && !_isDisposed) {
            final delay = _getRetryDelay(attempt);
            Future.delayed(delay, () {
              if (!_isPremium && !_isDisposed) {
                preloadRewardedAd(attempt: attempt + 1);
              }
            });
          } else {
            debugPrint('Rewarded Ad retry limit reached');
            final dismiss = _pendingRewardedOnDismiss;
            _pendingRewardedOnReward = null;
            _pendingRewardedOnDismiss = null;
            dismiss?.call();
          }
        },
      ),
    );
  }

  void showRewardedAd({
    required VoidCallback onRewarded,
    required VoidCallback onAdDismissed,
  }) {
    if (_isPremium || _isDisposed) {
      onAdDismissed();
      return;
    }

    if (_pendingRewardedOnDismiss != null || _isShowingFullScreenAd) {
      debugPrint('A full-screen ad request is already active');
      return;
    }

    _pendingRewardedOnReward = onRewarded;
    _pendingRewardedOnDismiss = onAdDismissed;

    if (_rewardedAd != null) {
      _showLoadedRewardedAd();
    } else {
      debugPrint('Rewarded ad not ready. Preloading now.');
      preloadRewardedAd();
    }
  }

  void _showLoadedRewardedAd() {
    final ad = _rewardedAd;
    if (ad == null || _isPremium || _isDisposed) {
      return;
    }

    _rewardedAd = null;
    bool completed = false;
    bool rewardEarned = false;

    final onReward = _pendingRewardedOnReward;
    final onDismiss = _pendingRewardedOnDismiss;

    _pendingRewardedOnReward = null;
    _pendingRewardedOnDismiss = null;

    void finish() {
      if (completed) return;
      completed = true;
      _isShowingFullScreenAd = false;
      onDismiss?.call();
      if (!_isPremium && !_isDisposed) {
        preloadRewardedAd();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingFullScreenAd = true;
        _lastFullScreenAdTime = DateTime.now();
        debugPrint('Rewarded Ad displayed');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('Rewarded Ad dismissed');
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded Ad show failed: ${error.message}');
        ad.dispose();
        finish();
      },
    );

    try {
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          if (!rewardEarned) {
            rewardEarned = true;
            debugPrint('Reward earned: ${reward.amount} ${reward.type}');
            onReward?.call();
          }
        },
      );
    } catch (e) {
      debugPrint('Rewarded Ad display exception: $e');
      ad.dispose();
      finish();
    }
  }

  // Disposal

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    _interstitialAd?.dispose();
    _interstitialAd = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;

    _appOpenAd?.dispose();
    _appOpenAd = null;
    _appOpenAdLoadTime = null;

    _isInterstitialLoading = false;
    _isRewardedLoading = false;
    _isAppOpenAdLoading = false;
    _isShowingFullScreenAd = false;

    _pendingRewardedOnReward = null;
    _pendingRewardedOnDismiss = null;

    if (_observerAdded) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAdded = false;
    }

    debugPrint('AdService disposed');
  }
}
