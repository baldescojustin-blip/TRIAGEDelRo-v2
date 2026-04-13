import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'panels/login.dart';
import 'panels/resident_dashboard.dart';
import 'panels/official_dashboard.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Supabase client
  await Supabase.initialize(
    url: 'https://pxwhqcvbnoqzzozblctj.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4d2hxY3Zibm9xenpvemJsY3RqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1MzI3MTEsImV4cCI6MjA4NzEwODcxMX0.HQav5ww4qvUVl-UB5JKVW7RkSEH7k50jOdJ0ierUXvE',
  );

  runApp(const MyApp());
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppColors {
  static const ink = Color(0xFF080C14);
  static const void_ = Color(0xFF0E1420);
  static const surface = Color(0xFF141C2E);
  static const border = Color(0xFF1E2D45);
  static const borderHot = Color(0xFF2A3F5F);

  static const navy = Color(0xFF0D2B55);
  static const electric = Color(0xFF1B6EF3);
  static const electricDim = Color(0xFF1247A8);

  static const amber = Color(0xFFF59E0B);
  static const amberDim = Color(0xFF92600A);
  static const red = Color(0xFFEF3D3D);
  static const redDim = Color(0xFF8B1A1A);
  static const green = Color(0xFF10D97C);
  static const greenDim = Color(0xFF0A7A46);
  static const blue = Color(0xFF4A9EFF);
  static const blueDim = Color(0xFF1A5FA8);

  static const textPrimary = Color(0xFFE8F0FF);
  static const textSecondary = Color(0xFF6B82A8);
  static const textDim = Color(0xFF3D5070);
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
    color: AppColors.textSecondary,
    height: 1.5,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriageDelRo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.ink,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.electric,
          secondary: AppColors.amber,
          surface: AppColors.void_,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.textPrimary,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Rajdhani',
            color: AppColors.textPrimary,
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
      home: const Splash(),
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
                  _HexEmblem(size: 90),
                  const SizedBox(height: 32),
                  const Text(
                    'TRIAGE',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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
                          'Del Rosario',
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
                        color: AppColors.amber.withValues(alpha: 0.4),
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
                      color: AppColors.textDim,
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
                  color: done ? AppColors.textSecondary : AppColors.electric,
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
