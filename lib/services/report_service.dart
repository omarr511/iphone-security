import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/finding.dart';

class ReportService {
  Future<File> generatePdfReport(ScanResult result) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          _header(result),
          pw.SizedBox(height: 12),
          _summary(result),
          pw.SizedBox(height: 16),
          _findingsTable(result.findings),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/security_report_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _header(ScanResult result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0D1117'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'iPhone Security Report',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${_fmtDate(result.scanTime)}',
                style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _riskColor(result.riskLevel),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              '${result.riskLevel} (${result.score}/100)',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          )
        ],
      ),
    );
  }

  pw.Widget _summary(ScanResult result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#D0D7DE')),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Device: ${result.deviceModel}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text('iOS: ${result.iosVersion}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text('Critical: ${result.criticalCount}  |  High: ${result.highCount}  |  Medium: ${result.mediumCount}',
              style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _findingsTable(List<Finding> findings) {
    if (findings.isEmpty) {
      return pw.Text('No findings detected.', style: const pw.TextStyle(fontSize: 11));
    }

    final rows = <List<String>>[
      ['Severity', 'Category', 'Message'],
      ...findings.map((finding) => [
            finding.severity.label,
            finding.category,
            finding.message,
          ]),
    ];

    return pw.TableHelper.fromTextArray(
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F2937')),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(6),
      border: pw.TableBorder.all(color: PdfColor.fromHex('#D0D7DE'), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(1.8),
        2: const pw.FlexColumnWidth(3.5),
      },
    );
  }

  PdfColor _riskColor(String level) {
    switch (level) {
      case 'SAFE':
        return PdfColor.fromHex('#16A34A');
      case 'MEDIUM':
        return PdfColor.fromHex('#CA8A04');
      case 'HIGH':
        return PdfColor.fromHex('#EA580C');
      default:
        return PdfColor.fromHex('#DC2626');
    }
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }
}