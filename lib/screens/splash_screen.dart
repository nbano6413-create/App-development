
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../providers/app_state.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  final AppState appState;

  const SplashScreen({
    super.key,
    required this.appState,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  int _taglineIndex = -1;

  final List<String> _taglines = [
    'FAST',
    'SECURE',
    'EASY',
  ];

  @override
  void initState() {
    super.initState();

    // Initial loading: 3 seconds.
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      setState(() {
        _taglineIndex = 0;
      });

      _showNextTagline();
    });
  }

  void _showNextTagline() {
    // FAST and SECURE: 2 seconds pause each.
    if (_taglineIndex < _taglines.length - 1) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;

        setState(() {
          _taglineIndex++;
        });

        _showNextTagline();
      });
    } else {
      // EASY: 1 second, then open Home Screen.
      _timer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              appState: widget.appState,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A35E8),
              Color(0xFF7C4DFF),
              Color(0xFF9D7AFF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Moderate size logo.
              Container(
                width: 175,
                height: 175,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'My Docverter',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'PDF Converter',
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 24),

              // FAST, SECURE, EASY animation.
              SizedBox(
                height: 32,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _taglineIndex == -1
                        ? ' '
                        : _taglines[_taglineIndex],
                    key: ValueKey<int>(_taglineIndex),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'All your PDF tools in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFEDE5FF),
                  ),
                ),
              ),

              const Spacer(),

              // Loading indicator during initial 3 seconds.
              if (_taglineIndex == -1) ...[
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Preparing your documents...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 30),
              ],

              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }
}
