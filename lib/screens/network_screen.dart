import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../services/network_service.dart';
import '../models/finding.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _service = NetworkService();
  StreamSubscription<ConnectivityResult>? _connSub;
  bool _loading = false;
  List<Finding> _findings = [];
  Map<String, String> _connInfo = {};
  String _connectivityStatus = '…';

  @override
  void initState() {
    super.initState();
    _refresh();
    _initConnectivityState();
    _connSub = Connectivity().onConnectivityChanged.listen(_onConnChange);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivityState() async {
    final conn = await Connectivity().checkConnectivity();
    if (!mounted) return;
    _onConnChange(conn);
  }

  void _onConnChange(ConnectivityResult result) {
    setState(() {
      _connectivityStatus = result == ConnectivityResult.wifi
          ? 'WiFi'
          : result == ConnectivityResult.mobile
              ? 'بيانات الجوال'
              : result == ConnectivityResult.vpn
                  ? 'VPN'
              : 'غير متصل';
    });
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results  = await Future.wait([
      _service.scan(),
      _service.getConnectionInfo(),
    ]);
    setState(() {
      _findings   = results[0] as List<Finding>;
      _connInfo   = results[1] as Map<String, String>;
      _loading     = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionInfoCard(),
          const SizedBox(height: 16),
          _buildScanButton(),
          const SizedBox(height: 16),
          _buildFindingsList(),
        ],
      ),
    );
  }

  Widget _buildConnectionInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.wifi_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Text('معلومات الشبكة الحالية',
                style: TextStyle(
                    color: AppTheme.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_connectivityStatus,
                  style: const TextStyle(
                      color: AppTheme.green, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 12),
          if (_connInfo.isEmpty)
            const Text('جاري التحميل …',
                style: TextStyle(color: AppTheme.fg2))
          else ...[
            _netRow('📶 SSID',    _connInfo['ssid']    ?? '?'),
            _netRow('🔢 IP',      _connInfo['ip']      ?? '?'),
            _netRow('🌐 Gateway', _connInfo['gateway'] ?? '?'),
            _netRow('🎭 Subnet',  _connInfo['subnet']  ?? '?'),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _netRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.fg2, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.fg, fontSize: 13,
                  fontFamily: 'Courier')),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _refresh,
        icon: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.radar_rounded),
        label: Text(_loading ? 'جاري الفحص …' : 'فحص الاتصالات الآن'),
      ),
    );
  }

  Widget _buildFindingsList() {
    if (_loading) return const SizedBox.shrink();
    if (_findings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.green.withOpacity(0.4)),
        ),
        child: const Column(children: [
          Icon(Icons.check_circle_rounded,
              color: AppTheme.green, size: 40),
          SizedBox(height: 8),
          Text('لا اتصالات مشبوهة',
              style: TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ]),
      ).animate().fadeIn(duration: 400.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('النتائج (${_findings.length})',
            style: const TextStyle(
                color: AppTheme.fg,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        const SizedBox(height: 10),
        ..._findings.asMap().entries.map((e) {
          final f = e.value;
          final color =
              AppTheme.severityColors[f.severity.label] ?? AppTheme.fg2;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.severity.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.category,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(f.message,
                          style: const TextStyle(
                              color: AppTheme.fg2, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate()
           .fadeIn(delay: (e.key * 60).ms, duration: 300.ms)
           .slideX(begin: 0.15);
        }),
      ],
    );
  }
}
