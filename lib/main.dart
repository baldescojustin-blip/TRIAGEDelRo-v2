import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'panels/login.dart';
import 'panels/resident_dashboard.dart';
import 'panels/official_dashboard.dart';
import 'panels/intro_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Supabase client
  await Supabase.initialize(
    url: 'https://pxwhqcvbnoqzzozblctj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4d2hxY3Zibm9xenpvemJsY3RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1MzI3MTEsImV4cCI6MjA4NzEwODcxMX0.HQav5ww4qvUVl-UB5JKVW7RkSEH7k50jOdJ0ierUXvE',
  );

  final prefs = await SharedPreferences.getInstance();
  final seenIntro = prefs.getBool('seen_intro') ?? false;
  if (!seenIntro) {
    await prefs.setBool('seen_intro', true);
  }

  runApp(MyApp(showIntro: !seenIntro));
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppColors {
  // ── Enterprise Navy-Violet Theme ──────────────────────────────────────────
  static const ink         = Color(0xFF17172B); // Main background — deep navy-violet
  static const void_       = Color(0xFF252542); // Card background — elevated dark violet
  static const surface     = Color(0xFF2D2D52); // Secondary surface — subtle highlight
  static const border      = Color(0xFF3B3B5E); // Default border
  static const borderHot   = Color(0xFF8B5CF6); // Focused border — bright violet

  static const navy        = Color(0xFF17172B); // Nav / dark elements
  static const electric    = Color(0xFF8B5CF6); // Primary accent & buttons
  static const electricDim = Color(0xFF6D28D9); // Deep primary fill

  static const amber    = Color(0xFFF59E0B); // warning (Critical alerts)
  static const amberDim = Color(0xFF78350F); // warning dim background
  static const red      = Color(0xFFEF4444); // error
  static const redDim   = Color(0xFF7F1D1D);
  static const green    = Color(0xFF10B981); // success
  static const greenDim = Color(0xFF064E3B);
  static const blue     = Color(0xFF3B82F6); // info
  static const blueDim  = Color(0xFF1E3A8A);

  static const textPrimary   = Color(0xFFF8FAFC); // Light text for inside dark cards
  static const textSecondary = Color(0xFFA78BFA); // Soft violet muted text
  static const textDim       = Color(0xFF94A3B8); // Very dim text for secondary info
  static const textInverse   = Color(0xFFFFFFFF); // Pure white text for headers
}

class AppTypography {
  static const display = TextStyle(
    fontFamily: 'Rajdhani',
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 1.5,
  );
  static const mono = TextStyle(
    fontFamily: 'IBMPlexMono',
    color: AppColors.textSecondary,
  );
  static const body = TextStyle(
    fontFamily: 'SourceSans3',
    color: AppColors.textPrimary,
    height: 1.5,
  );
}

class MyApp extends StatelessWidget {
  final bool showIntro;
  const MyApp({super.key, this.showIntro = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLaud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: const ColorScheme.dark( // Set to dark mode base
          primary: AppColors.electric,
          secondary: AppColors.blue,   
          surface: AppColors.void_,
          error: AppColors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: AppColors.textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.textInverse, // White text for dark app bar
          centerTitle: false,
          elevation: 0,
          shadowColor: Color(0x0C000000),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Rajdhani',
            color: AppColors.textInverse, 
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.electric,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.void_,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.electric, width: 1.5),
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Rajdhani',
            letterSpacing: 1,
          ),
          hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
        ),
      ),
      home: showIntro ? const IntroScreen() : const Splash(),
    );
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────
class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _scan;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scan = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      _navigate(const Login());
      return;
    }

    final profile = await AuthService.refreshUserData();

    if (!mounted) return;

    if (profile == null) {
      await AuthService.logout();
      _navigate(const Login());
      return;
    }

    final role = profile['role'] as String? ?? 'community_member';
    final isOfficial = role == 'barangay_official' || role == 'bdrrmc_member';

    if (isOfficial) {
      _navigate(const OfficialDashboard());
    } else {
      _navigate(const ResidentDashboard());
    }
  }

  void _navigate(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            CustomPaint(
              painter: _GridPainter(),
              size: MediaQuery.of(context).size,
            ),
            AnimatedBuilder(
              animation: _scan,
              builder: (_, __) {
                final h = MediaQuery.of(context).size.height;
                return Positioned(
                  top: _scan.value * h,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.electric.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _HexEmblem(size: 90),
                  const SizedBox(height: 32),
                  const Text(
                    'MY LAUD',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textInverse, // Bright white for high contrast
                      letterSpacing: 12,
                      height: 1,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 1.5,
                        color: AppColors.electric,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Triage & Response',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: AppColors.electric,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 1.5,
                        color: AppColors.electric,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const Text(
                      'CITIZEN REPORT TRIAGE SYSTEM',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 10,
                        color: AppColors.amber,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'BDRRMC · BARANGAY DEL ROSARIO · MILAOR',
                    style: TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim, // Dim color looks great on the dark slate background
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 56),
                  const _BootText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootText extends StatefulWidget {
  const _BootText();

  @override
  State<_BootText> createState() => _BootTextState();
}

class _BootTextState extends State<_BootText> {
  int _step = 0;
  final _lines = [
    'CONNECTING TO BDRRMC SERVER...',
    'AUTHENTICATING SESSION...',
    'LOADING INCIDENT DATABASE...',
    'SYSTEM READY',
  ];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    for (var i = 0; i < _lines.length; i++) {
      await Future.delayed(Duration(milliseconds: 600 + i * 200));
      if (mounted) setState(() => _step = i + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(_step, (i) {
        final done = i < _step - 1 || _lines[i] == 'SYSTEM READY';
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                done ? Icons.check : Icons.circle,
                size: 8,
                color: done ? AppColors.green : AppColors.electric,
              ),
              const SizedBox(width: 8),
              Text(
                _lines[i],
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 10,
                  color: done ? AppColors.textPrimary : AppColors.electric, 
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Hex Emblem ───────────────────────────────────────────────────────────────
class _HexEmblem extends StatelessWidget {
  final double size;
  const _HexEmblem({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            painter: _HexPainter(
              fillColor: AppColors.void_,
              strokeColor: AppColors.electric,
              strokeWidth: 1.5,
            ),
            size: Size(size, size),
          ),
          Icon(
            Icons.shield_outlined,
            size: size * 0.42,
            color: AppColors.electric,
          ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const _HexPainter({
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 * 0.9;
    final path = ui.Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.electric.withValues(alpha: 0.05) // Very subtle tech grid
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