import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/finding.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  final ScanResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _riskColor {
    switch (widget.result.riskLevel) {
      case 'SAFE':     return AppTheme.green;
      case 'MEDIUM':   return AppTheme.yellow;
      case 'HIGH':     return AppTheme.orange;
      default:         return AppTheme.red;
    }
  }

  String get _riskArabic {
    switch (widget.result.riskLevel) {
      case 'SAFE':     return 'الجهاز آمن ✅';
      case 'MEDIUM':   return 'خطر متوسط 🟡';
      case 'HIGH':     return 'خطر عالٍ 🟠';
      default:         return 'خطر حرج 🔴';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('نتائج الفحص'),
        backgroundColor: AppTheme.bg,
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareReport,
            tooltip: 'تصدير التقرير',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.fg2,
          tabs: const [
            Tab(text: 'الملخص'),
            Tab(text: 'التفاصيل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildDetailsTab(),
        ],
      ),
    );
  }

  // ── Summary tab ───────────────────────────────────────────────
  Widget _buildSummaryTab() {
    final r = widget.result;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Risk score circle
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _riskColor.withOpacity(0.4), width: 1.5),
            ),
            child: Column(children: [
              CircularPercentIndicator(
                radius: 80,
                lineWidth: 12,
                percent: r.score / 100,
                progressColor: _riskColor,
                backgroundColor: AppTheme.bg3,
                circularStrokeCap: CircularStrokeCap.round,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${r.score}',
                        style: TextStyle(
                          color: _riskColor,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        )),
                    const Text('/100',
                        style: TextStyle(
                            color: AppTheme.fg2, fontSize: 13)),
                  ],
                ),
              )
              .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 16),
              Text(_riskArabic,
                  style: TextStyle(
                    color: _riskColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ))
              .animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 6),
              Text(
                'تاريخ الفحص: ${_formatDate(r.scanTime)}',
                style: const TextStyle(color: AppTheme.fg2, fontSize: 12),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Counters
          Row(children: [
            _counterCard('حرج 🔴', r.criticalCount, AppTheme.red),
            const SizedBox(width: 8),
            _counterCard('عالٍ 🟠', r.highCount, AppTheme.orange),
            const SizedBox(width: 8),
            _counterCard('متوسط 🟡', r.mediumCount, AppTheme.yellow),
          ])
          .animate().fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: 16),

          // Device info card
          _buildDeviceCard(),
        ],
      ),
    );
  }

  Widget _counterCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: color, fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.fg2, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
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
          const Text('معلومات الجهاز',
              style: TextStyle(
                  color: AppTheme.fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 10),
          _infoRow('📱 الجهاز', widget.result.deviceModel),
          _infoRow('🔧 iOS', widget.result.iosVersion),
          _infoRow('🕐 الفحص', _formatDate(widget.result.scanTime)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.fg2, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(color: AppTheme.fg, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Details tab ───────────────────────────────────────────────
  Widget _buildDetailsTab() {
    final findings = widget.result.findings;
    if (findings.isEmpty) {
      return const Center(
        child: Text('لا توجد نتائج',
            style: TextStyle(color: AppTheme.fg2)),
      );
    }

    // Sort by severity
    final sorted = List<Finding>.from(findings)
      ..sort((a, b) => a.severity.score.compareTo(b.severity.score) * -1);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildFindingCard(sorted[i])
          .animate()
          .fadeIn(delay: (i * 40).ms, duration: 300.ms)
          .slideX(begin: 0.15),
    );
  }

  Widget _buildFindingCard(Finding f) {
    final color = AppTheme.severityColors[f.severity.label] ?? AppTheme.fg2;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${f.severity.icon} ${f.severity.label}',
                  style: TextStyle(
                      color: color, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(f.category,
                  style: const TextStyle(
                      color: AppTheme.fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(f.message,
              style: const TextStyle(
                  color: AppTheme.fg2, fontSize: 13, height: 1.4)),
          if (f.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 8),
            ...f.details.entries.map((e) => Text(
              '${e.key}: ${e.value}',
              style: const TextStyle(
                  color: AppTheme.fg2, fontSize: 11,
                  fontFamily: 'Courier'),
            )),
          ],
        ],
      ),
    );
  }

  // ── Export / Share ────────────────────────────────────────────
  Future<void> _shareReport() async {
    final r = widget.result;
    final buffer = StringBuffer();
    buffer.writeln('═' * 40);
    buffer.writeln('تقرير أمان iPhone Security Checker');
    buffer.writeln('═' * 40);
    buffer.writeln('الجهاز : ${r.deviceModel}');
    buffer.writeln('iOS    : ${r.iosVersion}');
    buffer.writeln('الفحص  : ${_formatDate(r.scanTime)}');
    buffer.writeln('النتيجة: $_riskArabic (${r.score}/100)');
    buffer.writeln('─' * 40);
    for (final f in r.findings) {
      buffer.writeln('${f.severity.icon} [${f.severity.label}] ${f.category}');
      buffer.writeln('   ${f.message}');
    }
    buffer.writeln('═' * 40);

    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/security_report.txt');
      await file.writeAsString(buffer.toString());
      await Share.shareXFiles([XFile(file.path)],
          text: 'تقرير فحص الأمان من iPhone Security Checker');
    } catch (e) {
      await Share.share(buffer.toString(),
          subject: 'تقرير فحص الأمان');
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')} '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
