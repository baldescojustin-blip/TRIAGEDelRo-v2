import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register.dart';
import 'resident_dashboard.dart';
import 'official_dashboard.dart';
import '../main.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late List<Animation<Offset>> _slideAnims;
  late List<Animation<double>> _fadeAnims;
  late Animation<double> _pulse;

  bool _loading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _slideAnims = List.generate(
      6,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _enterCtrl,
              curve: Interval(
                i * 0.1,
                0.6 + i * 0.08,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );
    _fadeAnims = List.generate(
      6,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(i * 0.1, 0.6 + i * 0.08, curve: Curves.easeOut),
        ),
      ),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _anim(int i, Widget child) => SlideTransition(
    position: _slideAnims[i],
    child: FadeTransition(opacity: _fadeAnims[i], child: child),
  );

  Future<void> _login() async {
    setState(() => _error = '');

    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      setState(() => _error = 'ALL FIELDS REQUIRED');
      return;
    }
    setState(() => _loading = true);

    try {
      final role = await AuthService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      final isOfficial = role == 'barangay_official' || role == 'bdrrmc_member';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isOfficial
              ? const OfficialDashboard()
              : const ResidentDashboard(),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'UNEXPECTED ERROR — TRY AGAIN';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          CustomPaint(
            painter: _GridPainter(),
            size: MediaQuery.of(context).size,
          ),
          IgnorePointer(child: const _CornerAccents()),
          SafeArea(
            child: Column(
              children: [
                // ── Brand header ──────────────────────────────────────────
                _anim(
                  0,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.electric.withValues(
                                    alpha: 0.3 * _pulse.value,
                                  ),
                                  blurRadius: 30 * _pulse.value,
                                  spreadRadius: 4 * _pulse.value,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: _HexEmblem(size: 72),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'MY LAUD',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 24,
                              height: 1,
                              color: AppColors.electric,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'TRIAGE & RESPONSE · MILAOR BDRRMC',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexMono',
                                  fontSize: 9,
                                  color: AppColors.electric,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 1,
                              color: AppColors.electric,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Form panel ────────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.void_,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _anim(
                            1,
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 18,
                                  color: AppColors.electric,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'SECURE ACCESS PORTAL',
                                  style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const Spacer(),
                                _SysOnlineBadge(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          _anim(
                            1,
                            const Padding(
                              padding: EdgeInsets.only(left: 13),
                              child: Text(
                                'Enter your credentials to access the system.\nYou will be routed to your dashboard automatically.',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexMono',
                                  fontSize: 10,
                                  color: AppColors.textDim,
                                  height: 1.6,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          _anim(2, const _FieldLabel('EMAIL ADDRESS')),
                          const SizedBox(height: 6),
                          _anim(
                            2,
                            _TacticalField(
                              controller: _emailCtrl,
                              hint: 'your@email.com',
                              icon: Icons.alternate_email_rounded,
                              type: TextInputType.emailAddress,
                              action: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _anim(3, const _FieldLabel('PASSWORD')),
                          const SizedBox(height: 6),
                          _anim(
                            3,
                            _TacticalField(
                              controller: _passwordCtrl,
                              hint: '••••••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              action: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error banner
                          if (_error.isNotEmpty)
                            _anim(
                              3,
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.red.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 14,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: const TextStyle(
                                          fontFamily: 'IBMPlexMono',
                                          fontSize: 10,
                                          color: AppColors.red,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // CTA
                          _anim(
                            4,
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: _loading
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.electric.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppColors.electric.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.electric,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    )
                                  : _TacticalButton(
                                      label: 'ACCESS SYSTEM',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: _login,
                                      primary: true,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          _anim(
                            4,
                            const _Divider(label: 'NEW TO DEL ROSARIO TRIAGE?'),
                          ),
                          const SizedBox(height: 16),

                          _anim(
                            5,
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: _TacticalButton(
                                label: 'REGISTER AS COMMUNITY MEMBER',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Register(),
                                  ),
                                ),
                                primary: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          _anim(
                            5,
                            Center(
                              child: Text(
                                'MILAOR BDRRMC  ·  BARANGAY DEL ROSARIO\nAUTHORIZED PERSONNEL ONLY',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'IBMPlexMono',
                                  fontSize: 9,
                                  color: AppColors.textDim,
                                  height: 1.8,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SysOnlineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withValues(alpha: 0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'SYS ONLINE',
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 9,
            color: AppColors.green,
            letterSpacing: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: AppColors.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 9,
            color: AppColors.textDim,
            letterSpacing: 1.5,
          ),
        ),
      ),
      Expanded(child: Container(height: 1, color: AppColors.border)),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 2,
    ),
  );
}

class _TacticalField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType type;
  final TextInputAction action;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _TacticalField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.type = TextInputType.text,
    this.action = TextInputAction.next,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      textInputAction: action,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: 'IBMPlexMono',
        fontSize: 13,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'IBMPlexMono',
          color: AppColors.textDim,
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.electric, width: 1.5),
        ),
      ),
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
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.primary
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                letterSpacing: 2.5,
              ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: 8),
              Icon(
                widget.icon,
                size: 16,
                color: widget.primary
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────

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
      ..color = AppColors.electric.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const len = 20.0;
    canvas.drawLine(const Offset(16, 16), const Offset(16 + len, 16), paint);
    canvas.drawLine(const Offset(16, 16), const Offset(16, 16 + len), paint);
    canvas.drawLine(
      Offset(size.width - 16, 16),
      Offset(size.width - 16 - len, 16),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 16, 16),
      Offset(size.width - 16, 16 + len),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height - 16),
      Offset(16 + len, size.height - 16),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height - 16),
      Offset(16, size.height - 16 - len),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height - 16),
      Offset(size.width - 16 - len, size.height - 16),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height - 16),
      Offset(size.width - 16, size.height - 16 - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
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

class _HexEmblem extends StatelessWidget {
  final double size;
  const _HexEmblem({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(painter: _HexPainter(), size: Size(size, size)),
        Icon(
          Icons.shield_outlined,
          size: size * 0.42,
          color: AppColors.electric,
        ),
      ],
    ),
  );
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2 * 0.9;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.surface);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.electric
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}