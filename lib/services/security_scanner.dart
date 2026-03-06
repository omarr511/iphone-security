import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import '../models/finding.dart';
import 'jailbreak_service.dart';
import 'network_service.dart';
import 'permission_service.dart';

class SecurityScannerService {
  static const _channel = MethodChannel('com.security.checker/system');

  final _jailbreakSvc  = JailbreakService();
  final _networkSvc    = NetworkService();
  final _permissionSvc = PermissionService();

  // Progress callback: 0.0 → 1.0
  Function(double, String)? onProgress;

  Future<ScanResult> runFullScan() async {
    final findings = <Finding>[];
    _progress(0.0, 'جاري تهيئة الفحص …');

    // Device info
    final deviceInfo = await _getDeviceInfo();
    _progress(0.1, 'فحص كسر الحماية …');

    // Jailbreak
    final jbFindings = await _jailbreakSvc.check();
    findings.addAll(jbFindings);
    _progress(0.3, 'فحص الشبكة والاتصالات …');

    // Network
    final netFindings = await _networkSvc.scan();
    findings.addAll(netFindings);
    _progress(0.55, 'فحص الصلاحيات والتطبيقات …');

    // Permissions & profiles
    final permFindings = await _permissionSvc.check();
    findings.addAll(permFindings);
    _progress(0.75, 'فحص النظام …');

    // System checks
    findings.addAll(await _systemChecks());
    _progress(0.9, 'تحليل النتائج …');

    // If no critical/high issues add SAFE finding
    final serious = findings.where(
      (f) => f.severity == Severity.critical || f.severity == Severity.high,
    ).toList();
    if (serious.isEmpty) {
      findings.add(Finding(
        severity: Severity.safe,
        category: 'نتيجة الفحص',
        message: 'لم يتم اكتشاف تهديدات جسيمة',
        timestamp: DateTime.now(),
      ));
    }

    _progress(1.0, 'اكتمل الفحص');

    return ScanResult(
      findings:    findings,
      scanTime:    DateTime.now(),
      deviceModel: deviceInfo['model'] ?? 'Unknown',
      iosVersion:  deviceInfo['version'] ?? '?',
    );
  }

  // ── System checks ─────────────────────────────────────────────
  Future<List<Finding>> _systemChecks() async {
    final findings = <Finding>[];
    try {
      final result = await _channel.invokeMethod<Map>('getSystemInfo');
      final data = Map<String, dynamic>.from(result ?? {});

      // Low storage can be a sign of persistent spyware
      final freeGB = (data['freeStorageGB'] as num?)?.toDouble() ?? 10.0;
      if (freeGB < 0.5) {
        findings.add(Finding(
          severity: Severity.medium,
          category: 'مساحة التخزين',
          message: 'مساحة فارغة منخفضة جداً (${freeGB.toStringAsFixed(1)} GB) — قد يكون سبب تسجيل مخفي',
          timestamp: DateTime.now(),
        ));
      }

      // Unusually high battery drain
      final batteryHealth = (data['batteryHealth'] as num?)?.toInt() ?? 100;
      if (batteryHealth < 50) {
        findings.add(Finding(
          severity: Severity.medium,
          category: 'البطارية',
          message: 'صحة البطارية منخفضة ($batteryHealth%) — قد تعني نشاط خفي',
          timestamp: DateTime.now(),
        ));
      }

      // Untrusted developer certificate
      final untrustedCerts = List<String>.from(data['untrustedCerts'] ?? []);
      for (final cert in untrustedCerts) {
        findings.add(Finding(
          severity: Severity.high,
          category: 'شهادة غير موثوقة',
          message: 'شهادة مطور غريبة مثبّتة: $cert — قد تستخدم للتنصت على HTTPS',
          details: {'cert': cert},
          timestamp: DateTime.now(),
        ));
      }
    } catch (_) {}
    return findings;
  }

  // ── Device info ───────────────────────────────────────────────
  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final info = DeviceInfoPlugin();
      final ios  = await info.iosInfo;
      return {
        'model':   '${ios.name} ${ios.model}',
        'version': ios.systemVersion,
      };
    } catch (_) {
      return {};
    }
  }

  void _progress(double val, String msg) {
    onProgress?.call(val, msg);
  }
}
