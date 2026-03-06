import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' as services;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/finding.dart';

class NetworkService {
  static const _channel = services.MethodChannel('com.security.checker/network');
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  Future<List<Finding>> scan({bool includeRealtimeHeuristics = false}) async {
    final findings = <Finding>[];
    findings.addAll(await _checkActiveConnections());
    findings.addAll(await _checkVpnStatus());
    findings.addAll(await _checkProxyStatus());
    findings.addAll(await _checkDnsServers());
    findings.addAll(await _checkNetworkInterface());
    if (includeRealtimeHeuristics) {
      findings.addAll(await _checkConnectivityHeuristics());
    }
    return findings;
  }

  Stream<List<Finding>> watchThreats({
    Duration interval = const Duration(minutes: 2),
  }) {
    return Stream.periodic(interval).asyncMap((_) => scan(includeRealtimeHeuristics: true));
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

  // ── Proxy status ───────────────────────────────────────────────
  Future<List<Finding>> _checkProxyStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getProxyStatus');
      final data = Map<String, dynamic>.from(result ?? {});
      final enabled = data['enabled'] as bool? ?? false;
      if (!enabled) {
        return [];
      }

      final host = data['host'] as String? ?? '';
      final port = data['port']?.toString() ?? '';
      final proxy = [host, port].where((v) => v.isNotEmpty).join(':');

      return [
        Finding(
          severity: Severity.medium,
          category: 'Proxy نشط',
          message: 'تم اكتشاف إعداد Proxy${proxy.isNotEmpty ? ' ($proxy)' : ''} — قد يُعيد توجيه البيانات',
          details: {
            'proxy_host': host,
            'proxy_port': port,
          },
          timestamp: DateTime.now(),
        )
      ];
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
        final cleanSsid = ssid.replaceAll('"', '').trim();
        return [
          Finding(
            severity: Severity.info,
            category: 'الشبكة',
            message: 'متصل بـ WiFi: $cleanSsid',
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
      info['ssid']   = (await _networkInfo.getWifiName() ?? 'غير متاح').replaceAll('"', '');
      info['ip']     = await _networkInfo.getWifiIP() ?? 'غير متاح';
      info['subnet'] = await _networkInfo.getWifiSubmask() ?? 'غير متاح';
      info['gateway']= await _networkInfo.getWifiGatewayIP() ?? 'غير متاح';
      final connectivity = await _connectivity.checkConnectivity();
      info['status'] = switch (connectivity) {
        ConnectivityResult.wifi => 'WiFi',
        ConnectivityResult.mobile => 'Cellular',
        ConnectivityResult.ethernet => 'Ethernet',
        ConnectivityResult.vpn => 'VPN',
        _ => 'Offline',
      };
    } catch (_) {}
    return info;
  }

  Future<List<Finding>> _checkConnectivityHeuristics() async {
    final findings = <Finding>[];
    try {
      final connectivity = await _connectivity.checkConnectivity();
      final status = connectivity;

      if (status == ConnectivityResult.none) {
        findings.add(Finding(
          severity: Severity.info,
          category: 'الاتصال',
          message: 'الجهاز غير متصل بالشبكة حالياً',
          timestamp: DateTime.now(),
        ));
        return findings;
      }

      final ssidRaw = await _networkInfo.getWifiName();
      final ssid = (ssidRaw ?? '').replaceAll('"', '').toLowerCase().trim();

      final weakSsidMarkers = [
        'free',
        'public',
        'open',
        'guest',
        'wifi',
      ];

      if (ssid.isNotEmpty && weakSsidMarkers.any(ssid.contains)) {
        findings.add(Finding(
          severity: Severity.medium,
          category: 'شبكة عامة',
          message: 'شبكة WiFi الحالية تبدو عامة/مفتوحة ($ssid) — يفضّل استخدام VPN موثوق',
          timestamp: DateTime.now(),
        ));
      }
    } catch (_) {}
    return findings;
  }
}
