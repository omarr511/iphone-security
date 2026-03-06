import 'dart:convert';
import 'package:flutter/services.dart' hide NetworkInterface;
import 'package:flutter/services.dart' as services;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/finding.dart';

class NetworkService {
  static const _channel = services.MethodChannel('com.security.checker/network');
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<List<Finding>> scan() async {
    final findings = <Finding>[];
    findings.addAll(await _checkActiveConnections());
    findings.addAll(await _checkVpnStatus());
    findings.addAll(await _checkDnsServers());
    findings.addAll(await _checkNetworkInterface());
    return findings;
  }

  // ── Active connections via native ─────────────────────────────
  Future<List<Finding>> _checkActiveConnections() async {
    try {
      final result = await _channel.invokeMethod<Map>('getActiveConnections');
      final data = Map<String, dynamic>.from(result ?? {});
      final connections = List<Map>.from(data['connections'] ?? []);
      final suspicious = <String>[];

      // Load suspicious domains
      final jsonStr = await services.rootBundle.loadString(
          'assets/data/suspicious_domains.json');
      final domainData = jsonDecode(jsonStr);
      final badDomains = List<String>.from(domainData['suspicious_domains']);

      for (final conn in connections) {
        final remote = (conn['remote'] as String? ?? '').toLowerCase();
        for (final domain in badDomains) {
          if (remote.contains(domain)) {
            suspicious.add('$remote → $domain');
          }
        }
      }

      if (suspicious.isNotEmpty) {
        return [
          Finding(
            severity: Severity.critical,
            category: 'اتصال مشبوه',
            message: 'اتصالات بنطاقات برامج التجسس المعروفة: ${suspicious.length}',
            details: {'connections': suspicious.join('\n')},
            timestamp: DateTime.now(),
          )
        ];
      }

      // Return info finding with connection count
      return [
        Finding(
          severity: Severity.info,
          category: 'الشبكة',
          message: 'فُحص ${connections.length} اتصال — لا اتصالات مشبوهة',
          timestamp: DateTime.now(),
        )
      ];
    } catch (e) {
      return [];
    }
  }

  // ── VPN status ────────────────────────────────────────────────
  Future<List<Finding>> _checkVpnStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getVpnStatus');
      final data = Map<String, dynamic>.from(result ?? {});
      final isVpn = data['isVpn'] as bool? ?? false;
      final vpnName = data['vpnName'] as String? ?? '';
      if (isVpn) {
        return [
          Finding(
            severity: Severity.medium,
            category: 'VPN نشط',
            message: 'يوجد اتصال VPN نشط: $vpnName — قد يُعيد توجيه حركة البيانات',
            details: {'vpn_name': vpnName},
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── DNS servers ───────────────────────────────────────────────
  Future<List<Finding>> _checkDnsServers() async {
    try {
      final result = await _channel.invokeMethod<Map>('getDnsServers');
      final data = Map<String, dynamic>.from(result ?? {});
      final servers = List<String>.from(data['servers'] ?? []);
      final trustedDns = [
        '8.8.8.8', '8.8.4.4',   // Google
        '1.1.1.1', '1.0.0.1',   // Cloudflare
        '208.67.222.222',         // OpenDNS
        '9.9.9.9',                // Quad9
      ];

      final unknownDns = servers.where(
        (s) => !trustedDns.any((t) => s.startsWith(t))
      ).toList();

      if (unknownDns.isNotEmpty) {
        return [
          Finding(
            severity: Severity.medium,
            category: 'DNS مشبوه',
            message: 'يستخدم الجهاز خوادم DNS غير معروفة: ${unknownDns.join(', ')}',
            details: {'dns_servers': unknownDns.join(', ')},
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Network interface info ────────────────────────────────────
  Future<List<Finding>> _checkNetworkInterface() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      if (ssid != null && ssid.isNotEmpty) {
        return [
          Finding(
            severity: Severity.info,
            category: 'الشبكة',
            message: 'متصل بـ WiFi: $ssid',
            timestamp: DateTime.now(),
          )
        ];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Current connection info (for display) ─────────────────────
  Future<Map<String, String>> getConnectionInfo() async {
    final info = <String, String>{};
    try {
      info['ssid']   = await _networkInfo.getWifiName() ?? 'غير متاح';
      info['ip']     = await _networkInfo.getWifiIP() ?? 'غير متاح';
      info['subnet'] = await _networkInfo.getWifiSubmask() ?? 'غير متاح';
      info['gateway']= await _networkInfo.getWifiGatewayIP() ?? 'غير متاح';
    } catch (_) {}
    return info;
  }
}
