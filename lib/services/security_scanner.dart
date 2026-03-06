import 'package:device_info_plus/device_info_plus.dart';
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
    return runScan(scanType: 'full');
  }

  Future<ScanResult> runScan({String scanType = 'full'}) async {
    final findings = <Finding>[];
    _progress(0.0, 'جاري تهيئة الفحص …');

    // Device info
    final deviceInfo = await _getDeviceInfo();
    final mode = scanType.toLowerCase();

    if (mode == 'full' || mode == 'quick' || mode == 'jailbreak') {
      _progress(0.12, 'فحص كسر الحماية …');
      findings.addAll(await _jailbreakSvc.check());
    }

    if (mode == 'full' || mode == 'quick' || mode == 'network') {
      _progress(0.35, 'فحص الشبكة والاتصالات …');
      findings.addAll(await _networkSvc.scan(includeRealtimeHeuristics: true));
    }

    if (mode == 'full' || mode == 'quick' || mode == 'permissions' || mode == 'mdm') {
      _progress(0.62, 'فحص الصلاحيات والإدارة …');
      findings.addAll(await _permissionSvc.check(mdmOnly: mode == 'mdm'));
    }

    if (mode == 'full' || mode == 'quick') {
      _progress(0.82, 'فحص النظام …');
      findings.addAll(await _systemChecks());
    }

    _progress(0.92, 'تحليل النتائج …');
    _applyRiskCorrelation(findings);

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
      findings:    _dedupeFindings(findings),
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

      final proxyEnabled = data['proxyEnabled'] as bool? ?? false;
      final proxyHost = data['proxyHost'] as String? ?? '';
      if (proxyEnabled) {
        findings.add(Finding(
          severity: Severity.medium,
          category: 'Proxy نشط',
          message: 'تم اكتشاف إعداد Proxy على الجهاز${proxyHost.isNotEmpty ? ': $proxyHost' : ''} — قد يُستخدم لاعتراض حركة البيانات',
          details: {'proxy': proxyHost},
          timestamp: DateTime.now(),
        ));
      }

      final isDevMode = data['isDeveloperMode'] as bool? ?? false;
      if (isDevMode) {
        findings.add(Finding(
          severity: Severity.info,
          category: 'Developer Mode',
          message: 'وضع المطوّر مفعّل على الجهاز',
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

  void _applyRiskCorrelation(List<Finding> findings) {
    final hasJailbreak = findings.any((f) =>
        f.category.contains('كسر الحماية') || f.category.contains('Sandbox'));
    final hasNetworkThreat = findings.any((f) =>
        f.category.contains('اتصال مشبوه') || f.category.contains('DNS مشبوه'));
    final hasMdm = findings.any((f) => f.category.contains('MDM'));

    if (hasJailbreak && hasNetworkThreat) {
      findings.add(Finding(
        severity: Severity.critical,
        category: 'ترابط تهديدات',
        message: 'كسر حماية + نشاط شبكة مشبوه = احتمالية اختراق متقدم مرتفعة',
        timestamp: DateTime.now(),
      ));
    }

    if (hasMdm && hasNetworkThreat) {
      findings.add(Finding(
        severity: Severity.high,
        category: 'مراقبة مُدارة',
        message: 'وجود MDM مع مؤشرات شبكة مشبوهة يستدعي التحقق الفوري من الجهة المديرة',
        timestamp: DateTime.now(),
      ));
    }
  }

  List<Finding> _dedupeFindings(List<Finding> findings) {
    final seen = <String>{};
    final out = <Finding>[];
    for (final finding in findings) {
      final key = '${finding.severity.label}|${finding.category}|${finding.message}';
      if (seen.add(key)) {
        out.add(finding);
      }
    }
    return out;
  }
}
