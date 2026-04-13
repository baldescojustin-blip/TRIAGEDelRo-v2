// triage_service.dart
// Add this file to your Flutter project under lib/services/
//
// This connects your Flutter prototype to the Python ML API.
//
// Setup:
//   1. Add to pubspec.yaml under dependencies:
//        http: ^1.2.0
//   2. Run: flutter pub get
//   3. Import and use TriageService in your screens.

import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── CONFIG ──────────────────────────────────────────────────────────────────
// Change this to your actual server IP when deploying.
// For local testing on Android emulator: use 10.0.2.2 instead of localhost
// For iOS simulator or real device on same WiFi: use your PC's local IP e.g. 192.168.1.x
const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator default

// ─── RESPONSE MODEL ──────────────────────────────────────────────────────────
class ClassificationResult {
  final String reportText;
  final String severity;
  final double severityConfidence;
  final Map<String, double> severityScores;
  final String message;

  ClassificationResult({
    required this.reportText,
    required this.severity,
    required this.severityConfidence,
    required this.severityScores,
    required this.message,
  });

  factory ClassificationResult.fromJson(Map<String, dynamic> json) {
    return ClassificationResult(
      reportText: json['report_text'] ?? '',
      severity: json['severity'] ?? 'Unknown',
      severityConfidence: (json['severity_confidence'] ?? 0).toDouble(),
      severityScores: Map<String, double>.from(
        (json['severity_scores'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      message: json['message'] ?? '',
    );
  }

  // Convenience: color code for severity (use in your UI widgets)
  String get severityEmoji {
    switch (severity) {
      case 'Critical': return '🔴';
      case 'High':     return '🟠';
      case 'Medium':   return '🟡';
      case 'Low':      return '🟢';
      default:         return '⚪';
    }
  }
}

// ─── SERVICE CLASS ────────────────────────────────────────────────────────────
class TriageService {
  static final TriageService _instance = TriageService._internal();
  factory TriageService() => _instance;
  TriageService._internal();

  /// Classify a single citizen report.
  /// Call this when a user submits a new report in your Flutter app.
  ///
  /// Example usage in your widget:
  ///   final result = await TriageService().classifyReport(reportText);
  ///   print(result.severity); // "Critical"
  Future<ClassificationResult> classifyReport(String reportText) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/classify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'report_text': reportText}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ClassificationResult.fromJson(data);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Fail gracefully — return Unknown so app doesn't crash
      print('TriageService error: $e');
      return ClassificationResult(
        reportText: reportText,
        severity: 'Unknown',
        severityConfidence: 0,
        severityScores: {},
        message: 'Classification unavailable. Please review manually.',
      );
    }
  }

  /// Check if the ML API is running.
  Future<bool> isApiHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXAMPLE: How to use TriageService in your existing Flutter screen
// ─────────────────────────────────────────────────────────────────────────────
//
// In your report submission screen (e.g. submit_report_screen.dart):
//
// import 'package:your_app/services/triage_service.dart';
//
// class _SubmitReportScreenState extends State<SubmitReportScreen> {
//   final _controller = TextEditingController();
//   ClassificationResult? _result;
//   bool _loading = false;
//
//   Future<void> _submitReport() async {
//     setState(() => _loading = true);
//
//     final result = await TriageService().classifyReport(_controller.text);
//
//     setState(() {
//       _result = result;
//       _loading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(children: [
//         TextField(controller: _controller, decoration: InputDecoration(labelText: 'I-type ang iyong ulat')),
//         ElevatedButton(
//           onPressed: _loading ? null : _submitReport,
//           child: _loading ? CircularProgressIndicator() : Text('Isumite'),
//         ),
//         if (_result != null) ...[
//           Text('${_result!.severityEmoji} Severity: ${_result!.severity}'),
//           Text('Confidence: ${_result!.severityConfidence.toStringAsFixed(1)}%'),
//           Text(_result!.message),
//         ]
//       ]),
//     );
//   }
// }