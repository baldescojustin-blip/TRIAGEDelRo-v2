import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/triage_service.dart';
import '../main.dart';
import '../config.dart';

const _mlApiBase = kApiBaseUrl;

class _MlResult {
  final String severity;
  final double confidence;
  final Map<String, double> scores;
  final String message;
  final String? languageHint;

  _MlResult({
    required this.severity,
    required this.confidence,
    required this.scores,
    required this.message,
    this.languageHint,
  });

  factory _MlResult.fromJson(Map<String, dynamic> j) => _MlResult(
    severity: j['severity'] ?? 'Unknown',
    confidence: (j['severity_confidence'] ?? 0).toDouble(),
    scores: Map<String, double>.from(
      (j['severity_scores'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ),
    ),
    message: j['message'] ?? '',
    languageHint: j['language_hint'] as String?,
  );
}

// Human-readable label for the language_hint values api.py's
// detect_language_hint() can return.
String _languageHintLabel(String hint) => switch (hint) {
  'bikol' => 'Bikol',
  'bikol-english' => 'Bikol-Eng',
  'tagalog' => 'Filipino',
  'taglish' => 'FIL-Eng',
  'english' => 'English',
  _ => hint,
};

// ─── Categories ───────────────────────────────────────────────────────────────
const _emergencyCategories = [
  'Flooding',
  'Fire',
  'Medical Emergency',
  'Infrastructure Damage',
];

// The vision model (api.py's phase2 classifier) only recognizes
// Earthquake/Fire/Flood/Landslide scenes — it has no training data for
// Medical Emergency or Infrastructure Damage photos. Running AI verification
// on those categories doesn't produce "no answer", it forces a wrong
// Earthquake/Fire/Flood/Landslide guess and always reports a false mismatch.
// So we only run the deep AI check for categories it can actually judge.
const _visionVerifiableCategories = ['Flooding', 'Fire'];

const _minorCategories = [
  'Waste Collection',
  'Noise Complaint',
  'Streetlights',
  'Road Safety',
  'Other',
];

const _severityLevels = ['High', 'Medium', 'Low'];

const _severityDescriptions = {
  'High': 'Life-threatening or immediate danger to persons/property.',
  'Medium': 'Serious issue that needs response but no immediate danger.',
  'Low': 'Minor concern addressable in routine operations.',
};

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  late AnimationController _enterCtrl;
  late AnimationController _scanCtrl;
  late List<Animation<Offset>> _slideAnims;
  late List<Animation<double>> _fadeAnims;
  late Animation<double> _scan;

  bool _isMinorConcern = false; 

  String? _selectedCategory;
  String? _selectedSeverity;
  bool _submitting = false;

  _MlResult? _mlResult;
  bool _classifying = false;
  bool _mlOverridden = false;

  double? _pinnedLat;
  double? _pinnedLng;
  bool _gettingLocation = false;

  // NEW: Image Picker Variables & Pre-verification state
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _verifyingImage = false;
  
  bool _isValidPhoto = true;
  String? _detectedImageCategory;
  bool _requiresManualReview = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _slideAnims = List.generate(
      10,
      (i) => Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(
            (i * 0.06).clamp(0.0, 1.0),
            (0.6 + i * 0.05).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
    _fadeAnims = List.generate(
      10,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(
            (i * 0.06).clamp(0.0, 1.0),
            (0.6 + i * 0.05).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );
    _scan = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _locationCtrl.dispose();
    _enterCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => SlideTransition(
    position: _slideAnims[i],
    child: FadeTransition(opacity: _fadeAnims[i], child: child),
  );

  Color _severityColor(String s) => switch (s) {
    'High' || 'Critical' => AppColors.red,
    'Medium' => AppColors.amber,
    _ => AppColors.green,
  };

  IconData _severityIcon(String s) => switch (s) {
    'High' || 'Critical' => Icons.warning_rounded,
    'Medium' => Icons.report_problem_outlined,
    _ => Icons.check_circle_outline,
  };

  IconData _categoryIcon(String c) => switch (c) {
    'Flooding' => Icons.water_rounded,
    'Fire' => Icons.local_fire_department_rounded,
    'Medical Emergency' => Icons.medical_services_outlined,
    'Infrastructure Damage' => Icons.construction_rounded,
    'Waste Collection' => Icons.delete_outline_rounded,
    'Noise Complaint' => Icons.volume_up_outlined,
    'Streetlights' => Icons.lightbulb_outline_rounded,
    'Road Safety' => Icons.shield_outlined,
    _ => Icons.more_horiz_rounded,
  };

  void _switchReportType(bool isMinor) {
    if (_isMinorConcern == isMinor) return;
    setState(() {
      _isMinorConcern = isMinor;
      _selectedCategory = null; 
      _mlResult = null; 
      _selectedImage = null; // Clear image when switching context
      
      if (isMinor) {
        _selectedSeverity = 'Low'; 
      } else {
        _selectedSeverity = null;
      }
    });
  }

  // --- UPDATED: HUMAN-IN-THE-LOOP OVERRIDE LOGIC ---
  Future<void> _handleImageSelected(XFile file) async {
    setState(() {
      _verifyingImage = true;
      _selectedImage = null; // Hide current while analyzing
    });

    try {
      final bytes = await file.readAsBytes();
      final fileName = file.name;
      
      // Run the deep AI image check when either:
      //  - no category is picked yet (photo-first flow — detect it fresh so
      //    we can auto-fill the category chip), or
      //  - the user already picked a category the vision model actually
      //    covers (Flooding, Fire) — cross-check the photo against it.
      // Medical Emergency / Infrastructure Damage have no matching vision
      // class, so a category already set to one of those skips AI entirely
      // rather than forcing a guaranteed-wrong verdict.
      final shouldRunVision = !_isMinorConcern &&
          (_selectedCategory == null || _visionVerifiableCategories.contains(_selectedCategory));

      if (shouldRunVision) {
        final verification = await TriageService().verifyImage(bytes, fileName, _selectedCategory);
        if (!mounted) return; // user navigated away while this was in flight

        if (verification != null) {
          if (!verification.isValidPhoto) {
            // Turn off the loading spinner before showing the prompt
            setState(() => _verifyingImage = false);

            // SHOW OVERRIDE DIALOG
            final proceed = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Dialog(
                backgroundColor: AppColors.void_,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 3, height: 18, color: AppColors.amber),
                          const SizedBox(width: 10),
                          const Text(
                            'AI WARNING',
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.amber,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "My Laud's AI couldn't confidently match this photo to a known disaster type (Fire or Flood). You can still attach it — a barangay official will review it manually before it's confirmed.",
                        style: TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.6,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text(
                                'CANCEL',
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.amber.withValues(alpha: 0.15),
                                foregroundColor: AppColors.amber,
                                side: BorderSide(
                                  color: AppColors.amber.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'YES, ATTACH',
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            if (!mounted) return;

            // If user clicks "YES, ATTACH", we accept the photo but flag it
            if (proceed == true) {
              setState(() {
                _isValidPhoto = false;
                _detectedImageCategory = 'Unknown';
                _requiresManualReview = true;
                _selectedImage = file;
              });
            }
            return; // Exit the function since we handled the flow here
          } else {
            // Normal behavior if the AI successfully recognizes it
            _isValidPhoto = verification.isValidPhoto;
            _detectedImageCategory = verification.detectedCategory;
            _requiresManualReview = verification.requiresManualReview;

            // AUTO-FILL CATEGORY: no category was picked yet and the photo
            // was recognized as one the app actually supports — select it
            // automatically. Still just a suggestion: the category chips
            // stay tappable, so the resident (or an official reviewing
            // later) can override it like any other AI suggestion.
            if (_selectedCategory == null &&
                verification.detectedCategory != null &&
                _emergencyCategories.contains(verification.detectedCategory)) {
              setState(() => _selectedCategory = verification.detectedCategory);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.void_,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: AppColors.electric, width: 1),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.electric, size: 14),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'CATEGORY AUTO-DETECTED: ${verification.detectedCategory!.toUpperCase()} — tap another chip to change it',
                            style: const TextStyle(
                              fontFamily: 'IBMPlexMono',
                              fontSize: 9,
                              color: AppColors.electric,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
          }
        }
      }

      setState(() {
        _selectedImage = file;
      });
    } catch (e) {
      _showError('IMAGE VERIFICATION FAILED. PLEASE TRY AGAIN.');
    } finally {
      if (mounted && _verifyingImage) setState(() => _verifyingImage = false);
    }
  }

  Future<void> _showImageSourceActionSheet() async {
    // No category required up front — attaching a photo of Fire/Flooding
    // now auto-detects and fills the category via _handleImageSelected.
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.void_,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.electric),
              title: const Text('TAKE A PHOTO', style: TextStyle(fontFamily: 'Rajdhani', color: AppColors.textPrimary)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (pickedFile != null) await _handleImageSelected(pickedFile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.electric),
              title: const Text('CHOOSE FROM GALLERY', style: TextStyle(fontFamily: 'Rajdhani', color: AppColors.textPrimary)),
              onTap: () async {
                Navigator.of(ctx).pop();
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (pickedFile != null) await _handleImageSelected(pickedFile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _classifyDescription() async {
    if (_isMinorConcern) return; 

    final text = _descriptionCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _classifying = true;
      _mlOverridden = false;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_mlApiBase/classify'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'report_text': text}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = _MlResult.fromJson(jsonDecode(response.body));
        setState(() {
          _mlResult = result;
          final mlSev = result.severity == 'Critical' ? 'High' : result.severity;
          if (_severityLevels.contains(mlSev)) {
            _selectedSeverity = mlSev;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _classifying = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('LOCATION SERVICES ARE DISABLED. ENABLE GPS AND TRY AGAIN.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('LOCATION PERMISSION DENIED');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('LOCATION PERMISSION PERMANENTLY DENIED. ENABLE IN DEVICE SETTINGS.');
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {
          position = null;
        }
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            ),
          );
        } catch (_) {
          position = null;
        }
      }

      if (position == null) {
        _showError('UNABLE TO ACQUIRE LOCATION. TRY AGAIN IN A FEWER SECONDS OR MOVING OUTSIDE.');
        return;
      }

      final resolvedPosition = position;
      setState(() {
        _pinnedLat = resolvedPosition.latitude;
        _pinnedLng = resolvedPosition.longitude;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.void_,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: AppColors.green, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.green, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'LOCATION PINNED: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 9,
                    color: AppColors.green,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('timeout') || msg.contains('timeoutexception')) {
        _showError('GPS SIGNAL TIMEOUT — MOVE TO AN OPEN AREA OR ENABLE WIFI/MOBILE DATA.');
      } else {
        _showError('LOCATION ERROR: ${e.toString().toUpperCase()}');
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _pinnedLat = null;
      _pinnedLng = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showError('SELECT A CATEGORY');
      return;
    }
    if (_selectedSeverity == null) {
      _showError('SELECT A SEVERITY LEVEL');
      return;
    }

    setState(() => _submitting = true);
    try {
      final hasDesc = _descriptionCtrl.text.trim().isNotEmpty;
      final hasGps = _pinnedLat != null;
      if (!hasGps && !hasDesc) {
        _showError('PIN A GPS LOCATION OR ENTER AN INCIDENT DESCRIPTION');
        setState(() => _submitting = false);
        return;
      }

      if (!_isMinorConcern && _mlResult == null && hasDesc) {
        await _classifyDescription();
      }

      String? imageUrl;

      // Upload the already verified image to Supabase
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final fileExt = _selectedImage!.name.split('.').last;
        final storageFileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await _supabase.storage.from('report_images').uploadBinary(
          storageFileName, 
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt'),
        );
        imageUrl = _supabase.storage.from('report_images').getPublicUrl(storageFileName);
      }

      final user = _supabase.auth.currentUser;
      final userData = AuthService.getUserData();

      // Save full record to Supabase Database
      await _supabase.from('reports').insert({
        'user_id': user?.id,
        'description': _descriptionCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'lat': _pinnedLat,
        'lng': _pinnedLng,
        'category': _selectedCategory,
        'severity': _selectedSeverity,
        'status': 'Pending',
        'barangay': userData?['barangay'] ?? 'Del Rosario',
        'report_type': _isMinorConcern ? 'Minor Concern' : 'Emergency',
        'image_url': imageUrl,
        'is_valid_photo': _selectedImage != null ? _isValidPhoto : null,
        'detected_image_category': _selectedImage != null ? _detectedImageCategory : null,
        'requires_manual_review': _selectedImage != null ? _requiresManualReview : null,
        'language_hint': _mlResult?.languageHint,
        // Preserves what the AI actually suggested, separate from the final
        // 'severity' above — lets officials see when/if a human overrode it.
        'ml_severity': _mlResult?.severity,
        'ml_confidence': _mlResult?.confidence,
        'ml_overridden': _mlResult != null ? _mlOverridden : null,
      });

      // TRIGGER HIGH SEVERITY EMAIL DISPATCH (SMS not yet implemented — future work)
      if (_selectedSeverity == 'High') {
        TriageService().sendHighSeverityAlert(
          category: _selectedCategory!,
          severity: _selectedSeverity!,
          description: _descriptionCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          lat: _pinnedLat,
          lng: _pinnedLng,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _showError('TRANSMISSION FAILED — ${e.toString().toUpperCase()}');
    } finally {
      if (mounted) setState(() {
        _submitting = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.void_,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.6), width: 1),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 14),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 10,
                  color: AppColors.red,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.void_,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.green, size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isMinorConcern ? 'CONCERN LOGGED' : 'REPORT TRANSMITTED',
                    style: const TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_mlResult != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _severityColor(_mlResult!.severity).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: _severityColor(_mlResult!.severity).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 11, color: _severityColor(_mlResult!.severity)),
                          const SizedBox(width: 6),
                          Text(
                            'ML TRIAGE: ${_mlResult!.severity.toUpperCase()} · ${_mlResult!.confidence.toStringAsFixed(1)}% CONFIDENCE',
                            style: TextStyle(
                              fontFamily: 'IBMPlexMono',
                              fontSize: 9,
                              color: _severityColor(_mlResult!.severity),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_pinnedLat != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.electric.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: AppColors.electric.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 10, color: AppColors.electric),
                            const SizedBox(width: 4),
                            Text(
                              'GPS: ${_pinnedLat!.toStringAsFixed(4)}, ${_pinnedLng!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontFamily: 'IBMPlexMono',
                                fontSize: 9,
                                color: AppColors.electric,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'STATUS: PENDING REVIEW',
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 9,
                            color: AppColors.green,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isMinorConcern 
                      ? 'Your concern has been logged for community review. Officials will assign a resolution schedule.'
                      : 'Your report has been received and is pending triage. Barangay officials are notified immediately.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      height: 1.7,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: _TacticalButton(
                      label: 'BACK TO DASHBOARD',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      primary: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = _isMinorConcern ? _minorCategories : _emergencyCategories;

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: AppColors.electric),
            SizedBox(width: 8),
            Text(
              'SUBMIT REPORT',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), size: MediaQuery.of(context).size),
          AnimatedBuilder(
            animation: _scan,
            builder: (_, __) {
              final h = MediaQuery.of(context).size.height;
              return Positioned(
                top: _scan.value * h,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppColors.electric.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const _CornerAccents(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  _animated(
                    0,
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.void_,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TacticalTab(
                              label: 'EMERGENCY',
                              icon: Icons.warning_amber_rounded,
                              isActive: !_isMinorConcern,
                              onTap: () => _switchReportType(false),
                            ),
                          ),
                          Expanded(
                            child: _TacticalTab(
                              label: 'MINOR CONCERN',
                              icon: Icons.lightbulb_outline_rounded,
                              isActive: _isMinorConcern,
                              onTap: () => _switchReportType(true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _animated(1, const _SectionHeader('CATEGORY')),
                  const SizedBox(height: 14),
                  _animated(
                    1,
                    GridView.count(
                      crossAxisCount: _isMinorConcern ? 3 : 2, 
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: _isMinorConcern ? 1.5 : 2.7,
                      children: activeCategories.map((cat) {
                        final selected = _selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.electric.withValues(alpha: 0.1) : AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: selected ? AppColors.electric : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: _isMinorConcern 
                            ? Column( 
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _categoryIcon(cat),
                                    size: 20,
                                    color: selected ? AppColors.electric : AppColors.textDim,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'IBMPlexMono',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? AppColors.electric : AppColors.textSecondary,
                                      letterSpacing: 0.6,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              )
                            : Row( 
                                children: [
                                  Icon(
                                    _categoryIcon(cat),
                                    size: 16,
                                    color: selected ? AppColors.electric : AppColors.textDim,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cat.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexMono',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? AppColors.electric : AppColors.textSecondary,
                                        letterSpacing: 0.6,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _animated(2, const _SectionHeader('DESCRIPTION')),
                  const SizedBox(height: 4),
                  _animated(
                    2,
                    Padding(
                      padding: const EdgeInsets.only(left: 11, bottom: 14),
                      child: Text(
                        _isMinorConcern 
                        ? 'Describe the issue in detail (location, time, severity).'
                        : 'Describe the incident — ML triage will auto-suggest a severity level.',
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 10,
                          color: AppColors.textDim,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  _animated(
                    2,
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus && _descriptionCtrl.text.trim().isNotEmpty) {
                          _classifyDescription();
                        }
                      },
                      child: _TacticalTextField(
                        controller: _descriptionCtrl,
                        label: _pinnedLat != null ? 'DESCRIPTION (OPTIONAL)' : 'DESCRIPTION',
                        hint: _pinnedLat != null
                            ? 'Describe the situation… (optional if GPS pinned)'
                            : 'Describe the situation…',
                        icon: Icons.edit_note_rounded,
                        maxLines: 5,
                        maxLength: 500,
                        validator: (v) {
                          if (_pinnedLat != null) {
                            if (v != null && v.trim().isNotEmpty && v.trim().length < 5) {
                              return 'DESCRIPTION IS TOO SHORT';
                            }
                            return null;
                          }
                          if (v == null || v.trim().isEmpty) {
                            return 'DESCRIPTION IS REQUIRED (OR PIN YOUR GPS LOCATION)';
                          }
                          if (v.trim().length < 10) return 'DESCRIPTION IS TOO SHORT';
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _animated(3, const _SectionHeader('EVIDENCE (OPTIONAL)')),
                  const SizedBox(height: 14),
                  _animated(
                    3,
                    _verifyingImage
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.electric.withValues(alpha: 0.5)),
                          ),
                          child: const Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.electric),
                              SizedBox(height: 16),
                              Text(
                                'AI VERIFYING IMAGE...',
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.electric,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _selectedImage == null
                        ? GestureDetector(
                            onTap: _showImageSourceActionSheet,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.none),
                              ),
                              child: CustomPaint(
                                painter: _DashedBorderPainter(),
                                child: const Column(
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, color: AppColors.electric, size: 32),
                                    SizedBox(height: 12),
                                    Text(
                                      'TAP TO ATTACH PHOTO',
                                      style: TextStyle(
                                        fontFamily: 'Rajdhani',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.electric, width: 2),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: kIsWeb
                                      ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                                      : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.void_.withValues(alpha: 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: AppColors.red, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),

                  if (!_isMinorConcern) ...[
                    _animated(
                      4,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: _classifying ? null : _classifyDescription,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_classifying)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(color: AppColors.electric, strokeWidth: 1.5),
                                    )
                                  else
                                    const Icon(Icons.auto_awesome, size: 13, color: AppColors.electric),
                                  const SizedBox(width: 8),
                                  Text(
                                    _classifying ? 'ANALYZING...' : 'AUTO-CLASSIFY SEVERITY',
                                    style: const TextStyle(
                                      fontFamily: 'Rajdhani',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.electric,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_mlResult != null) ...[
                            const SizedBox(height: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _severityColor(_mlResult!.severity).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _severityColor(_mlResult!.severity).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome, size: 11, color: _severityColor(_mlResult!.severity)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ML TRIAGE RESULT',
                                        style: TextStyle(
                                          fontFamily: 'IBMPlexMono',
                                          fontSize: 9,
                                          color: _severityColor(_mlResult!.severity),
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (_mlResult!.languageHint != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.electric.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(2),
                                            border: Border.all(color: AppColors.electric.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            _languageHintLabel(_mlResult!.languageHint!).toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: 'IBMPlexMono',
                                              fontSize: 8,
                                              color: AppColors.electric,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      if (_mlOverridden)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.amber.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(2),
                                            border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                                          ),
                                          child: const Text(
                                            'OVERRIDDEN',
                                            style: TextStyle(
                                              fontFamily: 'IBMPlexMono',
                                              fontSize: 8,
                                              color: AppColors.amber,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        _mlResult!.severity.toUpperCase(),
                                        style: TextStyle(
                                          fontFamily: 'Rajdhani',
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: _severityColor(_mlResult!.severity),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${_mlResult!.confidence.toStringAsFixed(1)}% CONFIDENCE',
                                        style: const TextStyle(
                                          fontFamily: 'IBMPlexMono',
                                          fontSize: 9,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ..._mlResult!.scores.entries.where((e) => e.key != 'Critical').map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 52,
                                          child: Text(
                                            e.key.toUpperCase(),
                                            style: const TextStyle(
                                              fontFamily: 'IBMPlexMono',
                                              fontSize: 8,
                                              color: AppColors.textDim,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Stack(
                                            children: [
                                              Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: AppColors.border,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: (e.value / 100).clamp(0, 1),
                                                child: Container(
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: _severityColor(e.key),
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${e.value.toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            fontFamily: 'IBMPlexMono',
                                            fontSize: 8,
                                            color: AppColors.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    _animated(4, const _SectionHeader('SEVERITY LEVEL')),
                    const SizedBox(height: 4),
                    _animated(
                      4,
                      Padding(
                        padding: const EdgeInsets.only(left: 11, bottom: 14),
                        child: Text(
                          _mlResult != null
                              ? 'ML has suggested a level. You may override below.'
                              : 'Select the severity that best describes the situation.',
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 10,
                            color: AppColors.textDim,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    _animated(
                      4,
                      Column(
                        children: _severityLevels.map((sev) {
                          final selected = _selectedSeverity == sev;
                          final color = _severityColor(sev);
                          final isMlSuggested = _mlResult != null &&
                              (_mlResult!.severity == sev ||
                                  (_mlResult!.severity == 'Critical' && sev == 'High'));
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedSeverity = sev;
                              if (_mlResult != null && !isMlSuggested) {
                                _mlOverridden = true;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: selected ? color.withValues(alpha: 0.07) : AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: selected ? color : AppColors.border,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: color.withValues(alpha: 0.3)),
                                    ),
                                    child: Icon(_severityIcon(sev), color: color, size: 16),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              sev.toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: 'Rajdhani',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: selected ? color : AppColors.textPrimary,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                            if (isMlSuggested) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppColors.electric.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                                child: const Text(
                                                  'ML',
                                                  style: TextStyle(
                                                    fontFamily: 'IBMPlexMono',
                                                    fontSize: 7,
                                                    color: AppColors.electric,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          _severityDescriptions[sev]!,
                                          style: const TextStyle(
                                            fontFamily: 'IBMPlexMono',
                                            fontSize: 9,
                                            color: AppColors.textDim,
                                            height: 1.5,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected) Icon(Icons.check_rounded, color: color, size: 16),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  _animated(5, const _SectionHeader('LOCATION')),
                  const SizedBox(height: 14),
                  _animated(
                    5,
                    _pinnedLat != null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Icon(Icons.location_on, color: AppColors.green, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'GPS LOCATION PINNED',
                                        style: TextStyle(
                                          fontFamily: 'Rajdhani',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.green,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      Text(
                                        '${_pinnedLat!.toStringAsFixed(6)}, ${_pinnedLng!.toStringAsFixed(6)}',
                                        style: const TextStyle(
                                          fontFamily: 'IBMPlexMono',
                                          fontSize: 9,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _clearLocation,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Icon(Icons.close, size: 14, color: AppColors.red),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: _gettingLocation ? null : _getCurrentLocation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_gettingLocation)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(color: AppColors.electric, strokeWidth: 2),
                                    )
                                  else
                                    const Icon(Icons.my_location_rounded, size: 16, color: AppColors.electric),
                                  const SizedBox(width: 10),
                                  Text(
                                    _gettingLocation ? 'ACQUIRING GPS SIGNAL...' : 'PIN MY CURRENT LOCATION',
                                    style: const TextStyle(
                                      fontFamily: 'Rajdhani',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.electric,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _animated(
                    5,
                    _TacticalTextField(
                      controller: _locationCtrl,
                      label: _pinnedLat != null ? 'LOCATION DESCRIPTION (OPTIONAL)' : 'LOCATION DESCRIPTION',
                      hint: _pinnedLat != null
                          ? 'e.g. Purok 3, near the bridge (optional)'
                          : 'e.g. Purok 3, near the bridge',
                      icon: Icons.location_on_outlined,
                      validator: (v) {
                        if (_pinnedLat != null) return null;
                        if (v == null || v.trim().isEmpty) {
                          return 'PIN GPS LOCATION OR ENTER A LOCATION DESCRIPTION';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  _animated(
                    6,
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _submitting
                          ? Container(
                              decoration: BoxDecoration(
                                color: AppColors.electric.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.electric.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: AppColors.electric, strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'TRANSMITTING...',
                                      style: TextStyle(
                                        fontFamily: 'Rajdhani',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.electric,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _TacticalButton(
                              label: _isMinorConcern ? 'SUBMIT CONCERN' : 'TRANSMIT REPORT',
                              icon: Icons.send_rounded,
                              onPressed: _submit,
                              primary: true,
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Widgets ─────────────────────────────────────────────────────────

class _TacticalTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TacticalTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.electric.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 14, 
              color: isActive ? AppColors.electric : AppColors.textDim
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.electric : AppColors.textDim,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(6)));

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double distance = 0.0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: AppColors.electric),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

class _TacticalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;

  const _TacticalTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 9,
            color: AppColors.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'IBMPlexMono', color: AppColors.textDim, fontSize: 12),
            prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            alignLabelWithHint: true,
            counterStyle: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.textDim),
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.electric, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppColors.red.withValues(alpha: 0.6))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
            errorStyle: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.red, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }
}

class _TacticalButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool primary;

  const _TacticalButton({
    required this.label,
    required this.onPressed,
    this.icon,
    required this.primary,
  });

  @override
  State<_TacticalButton> createState() => _TacticalButtonState();
}

class _TacticalButtonState extends State<_TacticalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: widget.primary
              ? (_pressed ? AppColors.electric : AppColors.electricDim)
              : (_pressed ? AppColors.surface : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.primary ? AppColors.electric : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 15, color: widget.primary ? AppColors.textPrimary : AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.primary ? AppColors.textPrimary : AppColors.textSecondary,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerAccents extends StatelessWidget {
  const _CornerAccents();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CornerPainter(), size: MediaQuery.of(context).size);
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.electric.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 20.0;
    canvas.drawLine(const Offset(16, 16), const Offset(16 + len, 16), paint);
    canvas.drawLine(const Offset(16, 16), const Offset(16, 16 + len), paint);
    canvas.drawLine(Offset(size.width - 16, 16), Offset(size.width - 16 - len, 16), paint);
    canvas.drawLine(Offset(size.width - 16, 16), Offset(size.width - 16, 16 + len), paint);
    canvas.drawLine(Offset(16, size.height - 16), Offset(16 + len, size.height - 16), paint);
    canvas.drawLine(Offset(16, size.height - 16), Offset(16, size.height - 16 - len), paint);
    canvas.drawLine(Offset(size.width - 16, size.height - 16), Offset(size.width - 16 - len, size.height - 16), paint);
    canvas.drawLine(Offset(size.width - 16, size.height - 16), Offset(size.width - 16, size.height - 16 - len), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.25)
      ..strokeWidth = 0.5;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}