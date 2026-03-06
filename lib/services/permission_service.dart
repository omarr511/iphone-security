import 'package:flutter/services.dart';
import '../models/finding.dart';

class PermissionService {
  static const _channel = MethodChannel('com.security.checker/permissions');

  static const _sensitivePerms = {
    'microphone':    'الميكروفون — خطر التنصت المباشر',
    'camera':        'الكاميرا — قد تُستخدم للمراقبة',
    'location':      'الموقع — يكشف تنقلاتك',
    'contacts':      'جهات الاتصال — بيانات شخصية حساسة',
    'photos':        'الصور — وصول لذكرياتك',
    'calendar':      'التقويم — كشف مواعيدك',
    'health':        'الصحة — بيانات طبية خاصة',
    'speechRec':     'التعرف على الصوت',
    'bluetooth':     'Bluetooth — تتبع الجهاز',
    'backgroundRefresh': 'تحديث الخلفية — يعمل عند قفل الجهاز',
  };

  Future<List<Finding>> check({bool mdmOnly = false}) async {
    final findings = <Finding>[];
    if (!mdmOnly) {
      findings.addAll(await _checkAppPermissions());
      findings.addAll(await _checkBackgroundActivity());
    }
    findings.addAll(await _checkConfigProfiles());
    findings.addAll(await _checkMdm());
    return findings;
  }

  Future<List<Finding>> _checkAppPermissions() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAppPermissions');
      final data = Map<String, dynamic>.from(result ?? {});

      // Each entry: { bundleId, appName, permissions: [...] }
      final apps = List<Map>.from(data['apps'] ?? []);
      final suspicious = <String>[];

      for (final app in apps) {
        final name = app['appName'] as String? ?? app['bundleId'] ?? '?';
        final perms = List<String>.from(app['permissions'] ?? []);
        final dangerous = perms.where(_sensitivePerms.containsKey).toList();

        if (dangerous.length >= 3) {
          suspicious.add('$name: ${dangerous.map((p) => _sensitivePerms[p]).join(', ')}');
        }
      }

      if (suspicious.isNotEmpty) {
        return [
          Finding(
            severity: Severity.high,
            category: 'تطبيقات بصلاحيات زائدة',
            message: '${suspicious.length} تطبيق يمتلك صلاحيات حساسة متعددة',
            details: {'apps': suspicious.join('\n')},
            timestamp: DateTime.now(),
          )
        ];
      }

      if (apps.isNotEmpty) {
        return [
          Finding(
            severity: Severity.info,
            category: 'الصلاحيات',
            message: 'تمت مراجعة صلاحيات $apps.length تطبيق',
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Finding>> _checkBackgroundActivity() async {
    try {
      final result = await _channel.invokeMethod<Map>('getBackgroundApps');
      final data = Map<String, dynamic>.from(result ?? {});
      final bgApps = List<String>.from(data['apps'] ?? []);

      if (bgApps.isNotEmpty) {
        final highRisk = bgApps.where((name) {
          final n = name.toLowerCase();
          return n.contains('vpn') || n.contains('proxy') || n.contains('remote');
        }).toList();

        return [
          Finding(
            severity: highRisk.isNotEmpty ? Severity.high : Severity.medium,
            category: 'نشاط الخلفية',
            message: '${bgApps.length} تطبيق يعمل في الخلفية',
            details: {
              'apps': bgApps.join(', '),
              if (highRisk.isNotEmpty) 'high_risk': highRisk.join(', '),
            },
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Finding>> _checkConfigProfiles() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConfigProfiles');
      final data = Map<String, dynamic>.from(result ?? {});
      final profiles = List<Map>.from(data['profiles'] ?? []);

      if (profiles.isNotEmpty) {
        final names = profiles
            .map((p) => p['name'] ?? p['identifier'] ?? '?')
            .join(', ');
        return [
          Finding(
            severity: Severity.critical,
            category: 'ملف تعريف تهيئة مثبّت',
            message: '${profiles.length} ملف Configuration Profile — قد يمنح تحكماً كاملاً',
            details: {'profiles': names},
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Finding>> _checkMdm() async {
    try {
      final result = await _channel.invokeMethod<Map>('getMdmStatus');
      final data = Map<String, dynamic>.from(result ?? {});
      final isMdm = data['enrolled'] as bool? ?? false;
      if (isMdm) {
        return [
          Finding(
            severity: Severity.critical,
            category: 'MDM مثبّت',
            message: 'الجهاز خاضع لإدارة MDM — شخص ما يتحكم به عن بعد',
            details: {'server': data['server'] ?? 'غير معروف'},
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
