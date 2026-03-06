import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../theme/app_theme.dart';
import '../services/security_scanner.dart';
import 'results_screen.dart';

class ScanScreen extends StatefulWidget {
  final String scanType;
  const ScanScreen({super.key, this.scanType = 'full'});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = SecurityScannerService();
  double  _progress   = 0.0;
  String  _statusText = 'جاري التهيئة …';
  bool    _done       = false;

  static const _scanSteps = [
    'فحص مؤشرات كسر الحماية …',
    'تحليل مسارات النظام …',
    'فحص Sandbox …',
    'مراقبة الاتصالات …',
    'تحليل DNS …',
    'فحص VPN …',
    'مراجعة الصلاحيات …',
    'فحص Config Profiles …',
    'كشف MDM …',
    'تحليل الشهادات …',
    'فحص النشاط في الخلفية …',
    'تجميع النتائج …',
  ];

  @override
  void initState() {
    super.initState();
    _scanner.onProgress = (val, msg) {
      if (mounted) setState(() { _progress = val; _statusText = msg; });
    };
    _runScan();
  }

  Future<void> _runScan() async {
    final result = await _scanner.runScan(scanType: widget.scanType);
    if (mounted) {
      setState(() { _done = true; });
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated shield
              _buildShieldAnimation(),
              const SizedBox(height: 40),

              // Title
              Text(
                _done ? 'اكتمل الفحص ✓' : 'جاري الفحص …',
                style: TextStyle(
                  color: _done ? AppTheme.green : AppTheme.fg,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ).animate(key: ValueKey(_done)).fadeIn(duration: 300.ms),

              const SizedBox(height: 12),

              // Status text
              Text(
                _statusText,
                style: const TextStyle(color: AppTheme.fg2, fontSize: 14),
                textAlign: TextAlign.center,
              ).animate(key: ValueKey(_statusText)).fadeIn(duration: 200.ms),

              const SizedBox(height: 36),

              // Progress ring
              CircularPercentIndicator(
                radius: 90,
                lineWidth: 10,
                percent: _progress,
                progressColor: _done ? AppTheme.green : AppTheme.accent,
                backgroundColor: AppTheme.bg3,
                circularStrokeCap: CircularStrokeCap.round,
                center: Text(
                  '${(_progress * 100).toInt()}%',
                  style: TextStyle(
                    color: _done ? AppTheme.green : AppTheme.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Animated steps list
              ..._buildStepsList(),

              const SizedBox(height: 24),

              if (!_done)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style: TextStyle(color: AppTheme.fg2)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShieldAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse rings
        ...List.generate(3, (i) => Container(
          width: 120 + i * 40.0,
          height: 120 + i * 40.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (_done ? AppTheme.green : AppTheme.accent)
                  .withOpacity(0.15 - i * 0.04),
              width: 1.5,
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: Duration(milliseconds: 1800 + i * 300),
          curve: Curves.easeOut,
        )
        .fadeOut(duration: Duration(milliseconds: 1800 + i * 300))),

        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: (_done ? AppTheme.green : AppTheme.accent).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _done ? Icons.check_circle_rounded : Icons.security_rounded,
            size: 52,
            color: _done ? AppTheme.green : AppTheme.accent,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.05, 1.05),
          duration: 1200.ms,
        ),
      ],
    );
  }

  List<Widget> _buildStepsList() {
    final completedCount = (_progress * _scanSteps.length).floor();
    return _scanSteps.asMap().entries.take(6).map((entry) {
      final idx = entry.key;
      final step = entry.value;
      final isComplete = idx < completedCount;
      final isCurrent  = idx == completedCount;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              isComplete ? Icons.check_circle_rounded
                         : (isCurrent ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked),
              size: 16,
              color: isComplete ? AppTheme.green
                                : (isCurrent ? AppTheme.accent : AppTheme.bg3),
            ),
            const SizedBox(width: 8),
            Text(step,
                style: TextStyle(
                  color: isComplete ? AppTheme.fg2
                                    : (isCurrent ? AppTheme.fg : AppTheme.bg3),
                  fontSize: 12,
                )),
          ],
        ),
      ).animate().fadeIn(delay: (idx * 50).ms);
    }).toList();
  }
}
