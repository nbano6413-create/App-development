# Implementation Plan - Google AdMob Ads Integration

This plan details the policy-compliant, user-friendly integration of Google AdMob ads into **My Docverter: PDF Converter**, including a bottom Adaptive Banner Ad on the Home Screen and a single shared Interstitial Ad Controller for all 18 tools with conservative frequency capping.

## User Review Required

> [!IMPORTANT]
> **AdMob Test IDs**: Official Google AdMob Test Unit IDs will be used during development:
> - Application ID: `ca-app-pub-3940256099942544~3347511713`
> - Banner Test Ad Unit ID: `ca-app-pub-3940256099942544/6300978111`
> - Interstitial Test Ad Unit ID: `ca-app-pub-3940256099942544/1033173712`

> [!NOTE]
> **Policy & Capping Rules**:
> - **Premium Tab**: 100% ad-free experience.
> - **Frequency Capping**: Interstitials require at least 3 successful task completions AND a 2-minute cooldown before eligibility.
> - **No Ads**: No ads during processing, app launch, tool opening, or back navigation.
> - **Fail-Safe**: If an ad fails to load or show, the app instantly proceeds without blocking the user.

## Proposed Changes

### Dependencies & Manifest
#### [MODIFY] [pubspec.yaml](file:///D:/untitled2/pubspec.yaml)
- Add `google_mobile_ads: ^5.2.0`.

#### [MODIFY] [AndroidManifest.xml](file:///D:/untitled2/android/app/src/main/AndroidManifest.xml)
- Add `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-3940256099942544~3347511713"/>`.

### Initialization & Service
#### [NEW] [ad_service.dart](file:///D:/untitled2/lib/services/ad_service.dart)
- Implement singleton `AdService` managing AdMob initialization, banner ad loading, and interstitial preloading/frequency capping (3 tasks + 2 min cooldown).

#### [MODIFY] [main.dart](file:///D:/untitled2/lib/main.dart)
- Initialize `MobileAds.instance.initialize()` inside `main()`.

### UI Integration
#### [MODIFY] [home_screen.dart](file:///D:/untitled2/lib/screens/home_screen.dart)
- Load and display Adaptive Banner Ad at the bottom of the Home Tab with generous spacing.
- Keep Premium Tab completely ad-free.

#### [MODIFY] [tool_detail_screen.dart](file:///D:/untitled2/lib/screens/tool_detail_screen.dart)
- Integrate `AdService.instance.showInterstitialIfEligible` after successful conversion before navigating to result screens across all 18 tools.

## Verification Plan

### Automated Tests & Analysis
- Run `flutter pub get`.
- Run `flutter analyze` (target: 0 issues).
- Run `flutter test` (target: all tests passed).

### Manual Verification
- Verify Home Screen Banner Ad display.
- Verify 3-task completion frequency capping for Interstitial Ads.
- Verify Premium tab remains ad-free.
