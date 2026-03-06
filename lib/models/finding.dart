enum Severity { critical, high, medium, info, safe }

extension SeverityExt on Severity {
  String get label {
    switch (this) {
      case Severity.critical: return 'CRITICAL';
      case Severity.high:     return 'HIGH';
      case Severity.medium:   return 'MEDIUM';
      case Severity.info:     return 'INFO';
      case Severity.safe:     return 'SAFE';
    }
  }

  String get icon {
    switch (this) {
      case Severity.critical: return '🔴';
      case Severity.high:     return '🟠';
      case Severity.medium:   return '🟡';
      case Severity.info:     return '🔵';
      case Severity.safe:     return '✅';
    }
  }

  int get score {
    switch (this) {
      case Severity.critical: return 40;
      case Severity.high:     return 20;
      case Severity.medium:   return 10;
      case Severity.info:     return 0;
      case Severity.safe:     return 0;
    }
  }
}

class Finding {
  final Severity severity;
  final String   category;
  final String   message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const Finding({
    required this.severity,
    required this.category,
    required this.message,
    this.details = const {},
    required this.timestamp,
  });

  factory Finding.fromMap(Map<String, dynamic> map) => Finding(
    severity:  _parseSeverity(map['severity'] ?? 'INFO'),
    category:  map['category'] ?? '',
    message:   map['message'] ?? '',
    details:   Map<String, dynamic>.from(map['details'] ?? {}),
    timestamp: DateTime.now(),
  );

  static Severity _parseSeverity(String s) {
    switch (s.toUpperCase()) {
      case 'CRITICAL': return Severity.critical;
      case 'HIGH':     return Severity.high;
      case 'MEDIUM':   return Severity.medium;
      case 'SAFE':     return Severity.safe;
      default:         return Severity.info;
    }
  }

  Map<String, dynamic> toMap() => {
    'severity':  severity.label,
    'category':  category,
    'message':   message,
    'details':   details,
    'timestamp': timestamp.toIso8601String(),
  };
}

class ScanResult {
  final List<Finding> findings;
  final DateTime scanTime;
  final String deviceModel;
  final String iosVersion;

  ScanResult({
    required this.findings,
    required this.scanTime,
    required this.deviceModel,
    required this.iosVersion,
  });

  int get score {
    int s = 100;
    for (final f in findings) {
      s -= f.severity.score;
    }
    return s.clamp(0, 100);
  }

  String get riskLevel {
    final s = score;
    if (s >= 80) return 'SAFE';
    if (s >= 60) return 'MEDIUM';
    if (s >= 40) return 'HIGH';
    return 'CRITICAL';
  }

  int get criticalCount => findings.where((f) => f.severity == Severity.critical).length;
  int get highCount => findings.where((f) => f.severity == Severity.high).length;
  int get mediumCount => findings.where((f) => f.severity == Severity.medium).length;
}
