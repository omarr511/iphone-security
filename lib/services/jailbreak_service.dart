import 'dart:io';
import 'package:flutter/services.dart';
import '../models/finding.dart';

/// Detects jailbreak indicators using both Dart-level checks
/// and native platform channel calls to Swift code.
class JailbreakService {
  static const _channel = MethodChannel('com.security.checker/jailbreak');

  // Paths that exist only on jailbroken devices
  static const _jailbreakPaths = [
    '/Applications/Cydia.app',
    '/Applications/Sileo.app',
    '/Applications/Zebra.app',
    '/bin/bash',
    '/bin/sh',
    '/etc/apt',
    '/usr/bin/ssh',
    '/usr/sbin/sshd',
    '/usr/libexec/sftp-server',
    '/var/cache/apt',
    '/var/lib/apt',
    '/var/lib/cydia',
    '/private/var/lib/apt',
    '/private/var/lib/cydia',
    '/private/var/stash',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/usr/bin/cycript',
    '/usr/local/bin/cycript',
    '/usr/lib/libcycript.dylib',
  ];

  static const _suspiciousSchemes = [
    'cydia://', 'sileo://', 'zbra://', 'filza://', 'activator://',
  ];

  Future<List<Finding>> check() async {
    final findings = <Finding>[];

    // 1. File system checks
    findings.addAll(await _checkFilesystem());

    // 2. URL scheme checks
    findings.addAll(await _checkUrlSchemes());

    // 3. Sandbox integrity
    findings.addAll(await _checkSandbox());

    // 4. Native checks via Swift
    findings.addAll(await _nativeChecks());

    return findings;
  }

  // ── File system ──────────────────────────────────────────────
  Future<List<Finding>> _checkFilesystem() async {
    final found = <String>[];
    for (final path in _jailbreakPaths) {
      if (File(path).existsSync()) found.add(path);
    }
    if (found.isEmpty) return [];
    return [
      Finding(
        severity: Severity.critical,
        category: 'كسر الحماية (Jailbreak)',
        message: 'تم اكتشاف ${found.length} ملف/مسار مرتبط بكسر الحماية',
        details: {'files': found.join(', ')},
        timestamp: DateTime.now(),
      )
    ];
  }

  // ── URL schemes ───────────────────────────────────────────────
  Future<List<Finding>> _checkUrlSchemes() async {
    // This check is done via the native platform channel
    try {
      final result = await _channel.invokeMethod<List>('checkUrlSchemes',
          {'schemes': _suspiciousSchemes});
      final detected = result?.cast<String>() ?? [];
      if (detected.isEmpty) return [];
      return [
        Finding(
          severity: Severity.high,
          category: 'كسر الحماية (Jailbreak)',
          message: 'تطبيق مرتبط بكسر الحماية مثبّت: ${detected.join(', ')}',
          details: {'schemes': detected.join(', ')},
          timestamp: DateTime.now(),
        )
      ];
    } catch (_) {
      return [];
    }
  }

  // ── Sandbox integrity ─────────────────────────────────────────
  Future<List<Finding>> _checkSandbox() async {
    final findings = <Finding>[];
    try {
      // Try to write outside sandbox — should fail on stock iOS
      const testPath = '/private/security_test.txt';
      File(testPath).writeAsStringSync('test');
      // If we get here, sandbox is broken
      File(testPath).deleteSync();
      findings.add(Finding(
        severity: Severity.critical,
        category: 'Sandbox مخترق',
        message: 'الجهاز يسمح بالكتابة خارج حدود التطبيق — علامة قوية على كسر الحماية',
        timestamp: DateTime.now(),
      ));
    } catch (_) {
      // Expected on non-jailbroken device — good
    }
    return findings;
  }

  // ── Native Swift checks ───────────────────────────────────────
  Future<List<Finding>> _nativeChecks() async {
    try {
      final result = await _channel.invokeMethod<Map>('deepJailbreakCheck');
      final data = Map<String, dynamic>.from(result ?? {});
      final detected = List<String>.from(data['detected'] ?? []);
      if (detected.isEmpty) return [];
      return [
        Finding(
          severity: Severity.critical,
          category: 'كسر الحماية (Native Check)',
          message: 'الفحص العميق كشف: ${detected.join(' | ')}',
          details: Map<String, dynamic>.from(data),
          timestamp: DateTime.now(),
        )
      ];
    } catch (_) {
      return [];
    }
  }
}
