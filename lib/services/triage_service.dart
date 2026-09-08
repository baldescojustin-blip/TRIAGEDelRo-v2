import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

// ─── CONFIG ──────────────────────────────────────────────────────────────────
const String _baseUrl = kApiBaseUrl;

// ─── RESPONSE MODELS ─────────────────────────────────────────────────────────
class ClassificationResult {
  final String reportText;
  final String severity;
  final double severityConfidence;
  final Map<String, double> severityScores;
  final String message;
  final String? languageHint;

  ClassificationResult({
    required this.reportText,
    required this.severity,
    required this.severityConfidence,
    required this.severityScores,
    required this.message,
    this.languageHint,
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
      languageHint: json['language_hint'] as String?,
    );
  }

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

class ImageVerificationResult {
  final bool isValidPhoto;
  final String? detectedCategory;
  final bool requiresManualReview;
  final String verdict;

  ImageVerificationResult({
    required this.isValidPhoto,
    this.detectedCategory,
    required this.requiresManualReview,
    required this.verdict,
  });

  factory ImageVerificationResult.fromJson(Map<String, dynamic> json) {
    return ImageVerificationResult(
      isValidPhoto: json['is_valid_report_photo'] ?? false,
      detectedCategory: json['detected_disaster_category'],
      requiresManualReview: json['requires_human_review'] ?? true,
      verdict: json['verdict'] ?? '',
    );
  }
}

// ─── SERVICE CLASS ────────────────────────────────────────────────────────────
class TriageService {
  static final TriageService _instance = TriageService._internal();
  factory TriageService() => _instance;
  TriageService._internal();

  /// Classify a single citizen report via the RoBERTa text model.
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

  /// Send an image to the MobileNetV3 multi-stage models for verification.
  /// [reportedCategory] is optional — pass null when there's no category
  /// selected yet (e.g. photo-first flow) so the backend just detects what's
  /// in the photo instead of comparing it against a category and reporting
  /// a false "mismatch".
  Future<ImageVerificationResult?> verifyImage(List<int> imageBytes, String fileName, String? reportedCategory) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/verify-image'));
      if (reportedCategory != null) {
        request.fields['reported_category'] = reportedCategory;
      }
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));

      var response = await request.send().timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResult = jsonDecode(responseData);
        return ImageVerificationResult.fromJson(jsonResult);
      } else {
        print('Image verification failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('TriageService verifyImage error: $e');
      return null;
    }
  }

  /// Dispatches Email notifications via the backend if severity is High.
  /// TODO (future work): SMS dispatch is not yet implemented — email only for now.
  Future<void> sendHighSeverityAlert({
    required String category,
    required String severity,
    required String description,
    String? location,
    double? lat,
    double? lng,
    String? imageUrl,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/notify-high'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'severity': severity,
          'description': description,
          'location': location,
          'lat': lat,
          'lng': lng,
          'image_url': imageUrl,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Failed to trigger background high alerts: $e');
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