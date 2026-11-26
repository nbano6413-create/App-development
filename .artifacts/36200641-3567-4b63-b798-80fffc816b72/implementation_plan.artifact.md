# Implementation Plan - Android Configuration & AdMob Audit & Verification

Audit and verify the complete Android configuration, `AndroidManifest.xml`, `MainActivity.kt`, `ListTileNativeAdFactory.kt`, and `AdService` (`ad_service.dart`) to ensure stable AdMob test ads integration, native ad factories, and error-free build verification.

## User Review Required

> [!IMPORTANT]
> - **Zero Disruption:** PDF tools, OCR, and existing UI will remain completely untouched.
> - **Robustness:** Bounded retry logic with exponential backoff in `AdService` ensures transient network/DNS issues are handled gracefully without infinite loops.

## Proposed Verification & Build Steps

1. Run `flutter clean`
2. Run `flutter pub get`
3. Run `flutter analyze`
4. Build Android Debug APK (`flutter build apk --debug`)
