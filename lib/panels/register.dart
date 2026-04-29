import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';

const _officialPositions = [
  'Barangay Captain',
  'Barangay Kagawad',
  'SK Chairperson',
  'Barangay Secretary',
  'Barangay Treasurer',
  'BDRRMC Coordinator',
  'BDRRMC Member',
  'Tanod Commander',
  'Barangay Tanod',
  'Health Worker',
];

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> with TickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────
  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late List<Animation<Offset>> _slideAnims;
  late List<Animation<double>> _fadeAnims;
  late Animation<double> _pulse;

  // ── State ─────────────────────────────────────────────────────
  String _role = 'community_member';
  String? _selectedPosition;
  bool _loading = false;
  bool _obscure = true;
  String _msg = '';

  bool get _isOfficial => _role == 'barangay_official';

  // ── Lifecycle ─────────────────────────────────────────────────
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
      7,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _enterCtrl,
              curve: Interval(
                i * 0.08,
                0.55 + i * 0.07,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
    );
    _fadeAnims = List.generate(
      7,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(i * 0.08, 0.55 + i * 0.07, curve: Curves.easeOut),
        ),
      ),
    );
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(_pulseCtrl);
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in [
      _emailCtrl,
      _passwordCtrl,
      _firstNameCtrl,
      _lastNameCtrl,
      _usernameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _positionCtrl,
    ]) {
      c.dispose();
    }
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => SlideTransition(
    position: _slideAnims[i],
    child: FadeTransition(opacity: _fadeAnims[i], child: child),
  );

  // ── Register logic ────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => _msg = '');

    final common = [
      _usernameCtrl.text.trim(),
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    ];

    if (_isOfficial &&
        (_selectedPosition == null || _selectedPosition!.isEmpty)) {
      setState(() => _msg = 'SELECT A POSITION / TITLE');
      return;
    }

    final roleSpecific = _isOfficial
        ? [_positionCtrl.text.trim()]
        : [_phoneCtrl.text.trim(), _addressCtrl.text.trim()];

    if ([...common, ...roleSpecific].any((f) => f.isEmpty)) {
      setState(() => _msg = 'ALL FIELDS ARE REQUIRED');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _msg = 'PASSWORD MIN. 6 CHARACTERS');
      return;
    }

    setState(() => _loading = true);

    final displayName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
    final roleLabel = _isOfficial ? 'BARANGAY OFFICIAL' : 'COMMUNITY MEMBER';

    try {
      if (_isOfficial) {
        await AuthService.registerOfficial(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          position: _positionCtrl.text.trim(),
          role: 'barangay_official',
        );
      } else {
        await AuthService.registerResident(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
      }

      if (!mounted) return;
      setState(() => _loading = false);
      _showSuccessDialog(displayName: displayName, roleLabel: roleLabel);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _msg = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _msg = e.toString().toUpperCase();
      });
    }
  }

  void _showSuccessDialog({
    required String displayName,
    required String roleLabel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.ink.withValues(alpha: 0.88),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.void_,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
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
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.green,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ACCOUNT CREATED',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                displayName.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electric,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your account has been registered with\n'
                'the Del Rosario BDRRMC System.\n'
                'Please sign in to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  height: 1.7,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.electric.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: AppColors.electric.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: AppColors.electric,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ROLE: $roleLabel',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 9,
                        color: AppColors.electric,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.25),
                  ),
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
                      'STATUS: ENROLLMENT COMPLETE',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: _TacticalButton(
                  label: 'PROCEED TO LOGIN',
                  icon: Icons.arrow_forward_rounded,
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
      ),
    );
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
                // ── Brand header ──────────────────────────────────
                _animated(
                  0,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
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
                          child: _HexEmblem(size: 60),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'TRIAGE DEL ROSARIO',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 1,
                              color: AppColors.electric,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'NEW OPERATOR ENROLLMENT',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexMono',
                                  fontSize: 9,
                                  color: AppColors.electric,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 1,
                              color: AppColors.electric,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Form panel ────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.void_,
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _animated(
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
                                  'ACCOUNT REGISTRATION',
                                  style: TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.electric.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Text(
                                    'OPEN ENROLLMENT',
                                    style: TextStyle(
                                      fontFamily: 'IBMPlexMono',
                                      fontSize: 9,
                                      color: AppColors.electric,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Padding(
                            padding: EdgeInsets.only(left: 13),
                            child: Text(
                              'Register to receive early warning notifications\n'
                              'and submit disaster reports for Brgy. Del Rosario.',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMono',
                                fontSize: 10,
                                color: AppColors.textDim,
                                height: 1.6,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── ROLE CLASSIFICATION ─────────────────
                          _animated(2, _SectionHeader('ROLE CLASSIFICATION')),
                          const SizedBox(height: 14),
                          _animated(
                            2,
                            Row(
                              children: [
                                Expanded(
                                  child: _RoleTile(
                                    label: 'COMMUNITY\nMEMBER',
                                    value: 'community_member',
                                    icon: Icons.people_outline,
                                    selected: !_isOfficial,
                                    onTap: () => setState(
                                      () => _role = 'community_member',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _RoleTile(
                                    label: 'BARANGAY\nOFFICIAL',
                                    value: 'barangay_official',
                                    icon: Icons.admin_panel_settings_outlined,
                                    selected: _isOfficial,
                                    onTap: () => setState(
                                      () => _role = 'barangay_official',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── ACCOUNT CREDENTIALS ─────────────────
                          _animated(3, _SectionHeader('ACCOUNT CREDENTIALS')),
                          const SizedBox(height: 14),

                          _animated(
                            3,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('USERNAME'),
                                const SizedBox(height: 6),
                                _TacticalField(
                                  controller: _usernameCtrl,
                                  hint: 'operator_handle',
                                  icon: Icons.alternate_email_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          _animated(
                            3,
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('FIRST NAME'),
                                      const SizedBox(height: 6),
                                      _TacticalField(
                                        controller: _firstNameCtrl,
                                        hint: 'Juan',
                                        icon: Icons.person_outline_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel('LAST NAME'),
                                      const SizedBox(height: 6),
                                      _TacticalField(
                                        controller: _lastNameCtrl,
                                        hint: 'dela Cruz',
                                        icon: Icons.person_outline_rounded,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          _animated(
                            4,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('EMAIL ADDRESS'),
                                const SizedBox(height: 6),
                                _TacticalField(
                                  controller: _emailCtrl,
                                  hint: 'you@email.com',
                                  icon: Icons.email_outlined,
                                  type: TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          _animated(
                            4,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('PASSWORD'),
                                const SizedBox(height: 6),
                                _TacticalField(
                                  controller: _passwordCtrl,
                                  hint: '••••••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscure,
                                  action: TextInputAction.next,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── ROLE-SPECIFIC FIELDS ────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _isOfficial
                                ? _animated(
                                    5,
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionHeader('OFFICIAL DETAILS'),
                                        const SizedBox(height: 14),
                                        _FieldLabel('POSITION / TITLE'),
                                        const SizedBox(height: 6),
                                        _PositionDropdown(
                                          value: _selectedPosition,
                                          onChanged: (v) {
                                            setState(() {
                                              _selectedPosition = v;
                                              _positionCtrl.text = v ?? '';
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 22),
                                      ],
                                    ),
                                  )
                                : _animated(
                                    5,
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionHeader('CONTACT DETAILS'),
                                        const SizedBox(height: 14),
                                        _FieldLabel('PHONE NUMBER'),
                                        const SizedBox(height: 6),
                                        _TacticalField(
                                          controller: _phoneCtrl,
                                          hint: '09XX XXX XXXX',
                                          icon: Icons.phone_outlined,
                                          type: TextInputType.phone,
                                          action: TextInputAction.next,
                                        ),
                                        const SizedBox(height: 14),
                                        _FieldLabel('HOME ADDRESS'),
                                        const SizedBox(height: 6),
                                        _TacticalField(
                                          controller: _addressCtrl,
                                          hint: 'House No., Street, Barangay',
                                          icon: Icons.location_on_outlined,
                                          action: TextInputAction.done,
                                        ),
                                        const SizedBox(height: 22),
                                      ],
                                    ),
                                  ),
                          ),

                          // ── ERROR BANNER ────────────────────────
                          if (_msg.isNotEmpty)
                            _animated(
                              6,
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.red.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.red.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 1),
                                      child: Icon(
                                        Icons.error_outline_rounded,
                                        size: 14,
                                        color: AppColors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _msg,
                                        style: const TextStyle(
                                          fontFamily: 'IBMPlexMono',
                                          color: AppColors.red,
                                          fontSize: 10,
                                          letterSpacing: 0.5,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // ── SUBMIT ──────────────────────────────
                          _animated(
                            6,
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: _loading
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.electric.withValues(
                                          alpha: 0.1,
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
                                      label: 'CREATE ACCOUNT',
                                      icon: Icons.arrow_forward_rounded,
                                      onPressed: _register,
                                      primary: true,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: _TacticalButton(
                              label: 'BACK TO LOGIN',
                              onPressed: () => Navigator.pop(context),
                              primary: false,
                            ),
                          ),
                          const SizedBox(height: 20),

                          Center(
                            child: Text(
                              'BY REGISTERING YOU AGREE TO SHARE CONTACT INFO\n'
                              'WITH BARANGAY DEL ROSARIO BDRRMC FOR EMERGENCY USE.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'IBMPlexMono',
                                fontSize: 8,
                                color: AppColors.textDim,
                                height: 1.8,
                                letterSpacing: 1,
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

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);
  @override
  Widget build(BuildContext context) => Row(
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

class _PositionDropdown extends StatelessWidget {
  final String? value;
  final void Function(String?) onChanged;
  const _PositionDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    isExpanded: true,
    decoration: InputDecoration(
      prefixIcon: const Icon(
        Icons.badge_outlined,
        size: 16,
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
    dropdownColor: AppColors.surface,
    iconEnabledColor: AppColors.textSecondary,
    style: const TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: 13,
      color: AppColors.textPrimary,
    ),
    hint: const Text(
      'Select position...',
      style: TextStyle(
        fontFamily: 'IBMPlexMono',
        color: AppColors.textDim,
        fontSize: 12,
      ),
    ),
    items: _officialPositions
        .map(
          (p) => DropdownMenuItem(
            value: p,
            child: Text(
              p,
              style: const TextStyle(
                fontFamily: 'IBMPlexMono',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
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
  Widget build(BuildContext context) => TextField(
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
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
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
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onPressed,
    onTapDown: (_) => setState(() => _hovered = true),
    onTapUp: (_) => setState(() => _hovered = false),
    onTapCancel: () => setState(() => _hovered = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: widget.primary
            ? (_hovered ? AppColors.electric : AppColors.electricDim)
            : (_hovered ? AppColors.surface : Colors.transparent),
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

class _RoleTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.electric.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: selected ? AppColors.electric : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: selected ? AppColors.electric : AppColors.textDim,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.electric : AppColors.textSecondary,
              letterSpacing: 1.5,
              height: 1.3,
            ),
          ),
          if (selected) ...[
            const SizedBox(height: 6),
            Container(width: 20, height: 2, color: AppColors.electric),
          ],
        ],
      ),
    ),
  );
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
    final p = Paint()
      ..color = AppColors.electric.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const l = 20.0;
    canvas.drawLine(const Offset(16, 16), const Offset(16 + l, 16), p);
    canvas.drawLine(const Offset(16, 16), const Offset(16, 16 + l), p);
    canvas.drawLine(
      Offset(size.width - 16, 16),
      Offset(size.width - 16 - l, 16),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 16, 16),
      Offset(size.width - 16, 16 + l),
      p,
    );
    canvas.drawLine(
      Offset(16, size.height - 16),
      Offset(16 + l, size.height - 16),
      p,
    );
    canvas.drawLine(
      Offset(16, size.height - 16),
      Offset(16, size.height - 16 - l),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height - 16),
      Offset(size.width - 16 - l, size.height - 16),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 16, size.height - 16),
      Offset(size.width - 16, size.height - 16 - l),
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 48)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 48)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
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
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 * 0.9;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (i * 60 - 30) * math.pi / 180;
      i == 0
          ? path.moveTo(cx + r * math.cos(a), cy + r * math.sin(a))
          : path.lineTo(cx + r * math.cos(a), cy + r * math.sin(a));
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