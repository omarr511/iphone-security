import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.bg2,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppTheme.border, width: 1.5),
              ),
              child: const Icon(Icons.security_rounded,
                  size: 56, color: AppTheme.accent),
            )
            .animate()
            .fadeIn(duration: 600.ms)
            .scale(begin: const Offset(0.7, 0.7), duration: 600.ms,
                   curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            Text('iPhone Security',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ))
            .animate().fadeIn(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.3, duration: 500.ms),

            const SizedBox(height: 6),

            Text('كاشف الاختراق والتجسس',
                style: const TextStyle(
                  color: AppTheme.fg2, fontSize: 15))
            .animate().fadeIn(delay: 500.ms, duration: 500.ms),

            const SizedBox(height: 60),

            SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.bg3,
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
            )
            .animate().fadeIn(delay: 700.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
