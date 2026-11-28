
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'providers/app_state.dart';
import 'screens/splash_screen.dart';
import 'services/ad_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyDocverterApp());

  // Initialize Google Test Ads in the background.
  unawaited(_initializeAds());
}

Future<void> _initializeAds() async {
  try {
    await AdService.instance.initialize();
    debugPrint('Google Mobile Ads initialized successfully');
  } catch (e) {
    debugPrint('AdMob initialization error: $e');
  }
}

class MyDocverterApp extends StatefulWidget {
  const MyDocverterApp({super.key});

  @override
  State<MyDocverterApp> createState() => _MyDocverterAppState();
}

class _MyDocverterAppState extends State<MyDocverterApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _appState.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Docverter: PDF Converter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _appState.themeMode,
      home: SplashScreen(
        appState: _appState,
      ),
    );
  }
}
