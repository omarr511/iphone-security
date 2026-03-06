import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../theme/app_theme.dart';
import '../services/scan_scheduler_service.dart';
import 'scan_screen.dart';
import 'network_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _deviceModel = 'جهازك';
  String _iosVersion  = '';
  int _selectedTab    = 0;
  final _scheduler    = ScanSchedulerService();
  AutoScanSnapshot? _lastAutoScan;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _startAutoMonitor();
  }

  @override
  void dispose() {
    _scheduler.stop();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      setState(() {
        _deviceModel = info.name;
        _iosVersion  = 'iOS ${info.systemVersion}';
      });
    } catch (_) {}
  }

  Future<void> _startAutoMonitor() async {
    await _scheduler.start(interval: const Duration(minutes: 20));
    await _refreshAutoMonitor();
  }

  Future<void> _refreshAutoMonitor() async {
    final snapshot = await _scheduler.getLastSnapshot();
    if (!mounted) return;
    setState(() {
      _lastAutoScan = snapshot;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.security_rounded,
                size: 22, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('iPhone Security',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  )),
              Text('$_deviceModel · $_iosVersion',
                  style: const TextStyle(
                    color: AppTheme.fg2, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.info_outline,
                color: AppTheme.fg2, size: 20),
            onPressed: _showAbout,
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody() {
    switch (_selectedTab) {
      case 0: return _buildDashboard();
      case 1: return const NetworkScreen();
      default: return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScanCard(),
          const SizedBox(height: 12),
          _buildAutoMonitorCard(),
          const SizedBox(height: 20),
          _buildQuickChecksGrid(),
          const SizedBox(height: 20),
          _buildInfoSection(),
        ],
      ),
    );
  }

  // ── Scan Card ─────────────────────────────────────────────────
  Widget _buildScanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2332), Color(0xFF0D1117)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.shield_rounded,
                size: 42, color: AppTheme.accent),
          )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 2400.ms, color: AppTheme.accent.withOpacity(0.2)),

          const SizedBox(height: 16),
          const Text('فحص أمني شامل',
              style: TextStyle(
                color: AppTheme.fg,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 8),
          const Text(
            'يفحص: Jailbreak · برامج التجسس · الشبكة · الصلاحيات · MDM',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.fg2, fontSize: 13),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ابدأ الفحص الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  // ── Quick checks grid ─────────────────────────────────────────
  Widget _buildQuickChecksGrid() {
    final checks = [
      _CheckItem('Jailbreak', Icons.lock_open_rounded,   AppTheme.red,    _checkJailbreak),
      _CheckItem('الشبكة',    Icons.wifi_rounded,         AppTheme.green,  _checkNetwork),
      _CheckItem('الصلاحيات', Icons.admin_panel_settings, AppTheme.orange, _checkPermissions),
      _CheckItem('MDM',       Icons.business_rounded,     AppTheme.purple, _checkMdm),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('فحوصات سريعة',
            style: TextStyle(
                color: AppTheme.fg,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: checks.asMap().entries.map((entry) {
            return _buildCheckTile(entry.value)
                .animate()
                .fadeIn(delay: (entry.key * 80).ms, duration: 400.ms)
                .slideX(begin: 0.2);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAutoMonitorCard() {
    final snapshot = _lastAutoScan;
    final hasSnapshot = snapshot != null;
    final riskLevel = snapshot?.riskLevel ?? 'SAFE';
    final riskColor = _riskColor(riskLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_moon_rounded, color: riskColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المراقبة الدورية',
                  style: TextStyle(
                    color: AppTheme.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasSnapshot
                      ? 'آخر فحص تلقائي: ${_formatAutoTime(snapshot.timestamp)} • ${snapshot.riskLevel} (${snapshot.score}/100)'
                      : 'مفعّلة — سيتم حفظ أول نتيجة تلقائياً بعد اكتمال أول فحص سريع',
                  style: const TextStyle(color: AppTheme.fg2, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshAutoMonitor,
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.fg2, size: 18),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildCheckTile(_CheckItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(item.icon, color: item.color, size: 26),
            Text(item.label,
                style: const TextStyle(
                    color: AppTheme.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────
  Widget _buildInfoSection() {
    return Container(
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
            const Icon(Icons.info_outline, color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            const Text('ماذا يفحص هذا التطبيق؟',
                style: TextStyle(
                    color: AppTheme.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          ...[
            ('🔓', 'كسر الحماية', 'Cydia, Sileo, Substrate, SSH'),
            ('🌐', 'الاتصالات', 'كشف اتصالات لخوادم التجسس'),
            ('🎙️', 'الصلاحيات', 'الميكروفون، الكاميرا، الموقع'),
            ('📋', 'Config Profiles', 'MDM والملفات المشبوهة'),
            ('🔐', 'الشهادات', 'شهادات HTTPS غير موثوقة'),
          ].map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2,
                        style: const TextStyle(
                            color: AppTheme.fg, fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text(item.$3,
                        style: const TextStyle(
                            color: AppTheme.fg2, fontSize: 11)),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _navItem(0, Icons.dashboard_rounded, 'الرئيسية'),
          _navItem(1, Icons.wifi_tethering_rounded, 'الشبكة'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? AppTheme.accent : AppTheme.fg2,
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: selected ? AppTheme.accent : AppTheme.fg2,
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────
  void _startScan() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  void _checkJailbreak() {
    Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => const ScanScreen(scanType: 'jailbreak')));
  }

  void _checkNetwork() {
    setState(() => _selectedTab = 1);
  }

  void _checkPermissions() {
    Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => const ScanScreen(scanType: 'permissions')));
  }

  void _checkMdm() {
    Navigator.push(context,
        MaterialPageRoute(
          builder: (_) => const ScanScreen(scanType: 'mdm')));
  }

  void _showAbout() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('iPhone Security Checker'),
        content: const Text(
          'يعمل بالكامل على الجهاز بدون اتصال بالإنترنت.\n'
          'للاستخدام الشخصي فقط.\n\n'
          'v1.0.0',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('حسناً'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return AppTheme.red;
      case 'HIGH':
        return AppTheme.orange;
      case 'MEDIUM':
        return AppTheme.yellow;
      default:
        return AppTheme.green;
    }
  }

  String _formatAutoTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d/$mo $h:$m';
  }
}

class _CheckItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CheckItem(this.label, this.icon, this.color, this.onTap);
}
