import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'security_scanner.dart';

class AutoScanSnapshot {
  final DateTime timestamp;
  final int score;
  final String riskLevel;

  const AutoScanSnapshot({
    required this.timestamp,
    required this.score,
    required this.riskLevel,
  });
}

class ScanSchedulerService {
  static const _kLastScanTs = 'auto_scan_last_ts';
  static const _kLastScanScore = 'auto_scan_last_score';
  static const _kLastScanRisk = 'auto_scan_last_risk';

  final SecurityScannerService _scanner = SecurityScannerService();
  Timer? _timer;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<void> start({
    Duration interval = const Duration(minutes: 30),
    bool runImmediately = true,
  }) async {
    if (_isRunning) {
      return;
    }
    _isRunning = true;

    if (runImmediately) {
      unawaited(_runQuickScan());
    }

    _timer = Timer.periodic(interval, (_) {
      unawaited(_runQuickScan());
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  Future<AutoScanSnapshot?> getLastSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_kLastScanTs);
    final score = prefs.getInt(_kLastScanScore);
    final risk = prefs.getString(_kLastScanRisk);

    if (ts == null || score == null || risk == null) {
      return null;
    }

    return AutoScanSnapshot(
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      score: score,
      riskLevel: risk,
    );
  }

  Future<void> _runQuickScan() async {
    try {
      final result = await _scanner.runScan(scanType: 'quick');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastScanTs, result.scanTime.millisecondsSinceEpoch);
      await prefs.setInt(_kLastScanScore, result.score);
      await prefs.setString(_kLastScanRisk, result.riskLevel);
    } catch (_) {}
  }
}