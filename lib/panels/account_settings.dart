import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'login.dart';

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

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  late AnimationController _enterCtrl;
  late AnimationController _scanCtrl;
  late List<Animation<Offset>> _slideAnims;
  late List<Animation<double>> _fadeAnims;
  late Animation<double> _scan;

  bool _loading = true;
  bool _saving = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;
  String? _userId;
  String _role = 'community_member';
  String? _selectedPosition;

  bool get _isOfficial =>
      _role == 'barangay_official' || _role == 'bdrrmc_member';

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _slideAnims = List.generate(
      6,
      (i) =>
          Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _enterCtrl,
              curve: Interval(
                i * 0.08,
                0.6 + i * 0.07,
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
          curve: Interval(i * 0.08, 0.6 + i * 0.07, curve: Curves.easeOut),
        ),
      ),
    );
    _scan = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);

    _loadUserData();
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _usernameCtrl,
      _phoneCtrl,
      _addressCtrl,
      _positionCtrl,
      _emailCtrl,
      _newPasswordCtrl,
      _confirmPassCtrl,
    ])
      c.dispose();
    _enterCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => SlideTransition(
    position: _slideAnims[i],
    child: FadeTransition(opacity: _fadeAnims[i], child: child),
  );

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _userId = user.id;
    _emailCtrl.text = user.email ?? '';

    try {
      final userRow = await _supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      _role = (userRow['role'] as String?) ?? 'community_member';

      if (_isOfficial) {
        final row = await _supabase
            .from('officials')
            .select('first_name, last_name, username, position')
            .eq('id', user.id)
            .single();
        _firstNameCtrl.text = row['first_name'] ?? '';
        _lastNameCtrl.text = row['last_name'] ?? '';
        _usernameCtrl.text = row['username'] ?? '';
        final pos = row['position'] as String? ?? '';
        _positionCtrl.text = pos;
        _selectedPosition = _officialPositions.contains(pos) ? pos : null;
      } else {
        final row = await _supabase
            .from('residents')
            .select('first_name, last_name, username, phone_number, address')
            .eq('id', user.id)
            .single();
        _firstNameCtrl.text = row['first_name'] ?? '';
        _lastNameCtrl.text = row['last_name'] ?? '';
        _usernameCtrl.text = row['username'] ?? '';
        _phoneCtrl.text = row['phone_number'] ?? '';
        _addressCtrl.text = row['address'] ?? '';
      }
    } catch (_) {
      final cached = AuthService.getUserData();
      if (cached != null) {
        _role = cached['role'] ?? 'community_member';
        _firstNameCtrl.text = cached['first_name'] ?? '';
        _lastNameCtrl.text = cached['last_name'] ?? '';
        _usernameCtrl.text = cached['username'] ?? '';
        _phoneCtrl.text = cached['phone_number'] ?? '';
        _addressCtrl.text = cached['address'] ?? '';
        final pos = cached['position'] as String? ?? '';
        _positionCtrl.text = pos;
        _selectedPosition = _officialPositions.contains(pos) ? pos : null;
      }
    }

    if (mounted) {
      setState(() => _loading = false);
      _enterCtrl.forward();
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isOfficial) {
        await AuthService.updateOfficialProfile(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          position: _positionCtrl.text.trim(),
        );
      } else {
        await AuthService.updateResidentProfile(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          username: _usernameCtrl.text.trim(),
          phoneNumber: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
        );
      }

      if (_newPasswordCtrl.text.isNotEmpty) {
        await _supabase.auth.updateUser(
          UserAttributes(password: _newPasswordCtrl.text),
        );
        _newPasswordCtrl.clear();
        _confirmPassCtrl.clear();
      }

      if (!mounted) return;
      _showSnack('PROFILE UPDATED SUCCESSFULLY', AppColors.green);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('ERROR: ${e.toString().toUpperCase()}', AppColors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    setState(() => _saving = true);
    try {
      await _supabase.from('reports').delete().eq('user_id', _userId!);
      if (_isOfficial) {
        await _supabase.from('officials').delete().eq('id', _userId!);
      } else {
        await _supabase.from('residents').delete().eq('id', _userId!);
      }
      await _supabase.from('users').delete().eq('id', _userId!);
      try {
        await _supabase.rpc('delete_user', params: {'user_id': _userId});
      } catch (_) {}
      await AuthService.logout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'DELETION FAILED: ${e.toString().toUpperCase()}',
        AppColors.red,
      );
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.void_,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: color.withValues(alpha: 0.6), width: 1),
        ),
        content: Row(
          children: [
            Icon(
              color == AppColors.green
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 10,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.85),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(4),
                  border: Border(
                    left: const BorderSide(color: AppColors.red, width: 3),
                    top: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.2),
                    ),
                    right: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.2),
                    ),
                    bottom: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.red, size: 16),
                    SizedBox(width: 10),
                    Text(
                      'CONFIRM ACCOUNT TERMINATION',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'This action is permanent and cannot be undone. Your account, all associated reports, and personal data will be permanently purged from the database.',
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.3,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        backgroundColor: AppColors.red.withValues(alpha: 0.15),
                        foregroundColor: AppColors.red,
                        side: BorderSide(
                          color: AppColors.red.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size.fromHeight(44),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'PURGE ACCOUNT',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          letterSpacing: 1.5,
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
    if (confirmed == true) await _deleteAccount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.manage_accounts_outlined,
              size: 18,
              color: AppColors.electric,
            ),
            SizedBox(width: 8),
            Text(
              'ACCOUNT SETTINGS',
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
                child: IgnorePointer(
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
                ),
              );
            },
          ),
          IgnorePointer(child: const _CornerAccents()),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.electric,
                    strokeWidth: 2,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Avatar card ───────────────────────────────
                        _animated(
                          0,
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.electric.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 24,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          painter: _HexPainter(),
                                          size: const Size(72, 72),
                                        ),
                                        Text(
                                          _usernameCtrl.text.isNotEmpty
                                              ? _usernameCtrl.text[0]
                                                    .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontFamily: 'Rajdhani',
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.electric,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '@${_usernameCtrl.text}',
                                  style: const TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.electric.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: AppColors.electric.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _isOfficial
                                        ? 'BARANGAY OFFICIAL'
                                        : 'REGISTERED RESIDENT',
                                    style: const TextStyle(
                                      fontFamily: 'IBMPlexMono',
                                      fontSize: 9,
                                      color: AppColors.electric,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _emailCtrl.text,
                                  style: const TextStyle(
                                    fontFamily: 'IBMPlexMono',
                                    fontSize: 10,
                                    color: AppColors.textDim,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        _animated(0, _dividerRow('MODIFY CREDENTIALS')),
                        const SizedBox(height: 24),

                        _animated(
                          1,
                          const _SectionHeader('PROFILE INFORMATION'),
                        ),
                        const SizedBox(height: 14),

                        _animated(
                          1,
                          Row(
                            children: [
                              Expanded(
                                child: _TacticalFormField(
                                  controller: _firstNameCtrl,
                                  label: 'FIRST NAME',
                                  hint: 'Juan',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'REQUIRED'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TacticalFormField(
                                  controller: _lastNameCtrl,
                                  label: 'LAST NAME',
                                  hint: 'dela Cruz',
                                  icon: Icons.person_outline_rounded,
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'REQUIRED'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        _animated(
                          2,
                          _TacticalFormField(
                            controller: _usernameCtrl,
                            label: 'USERNAME',
                            hint: 'operator_handle',
                            icon: Icons.alternate_email_rounded,
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'REQUIRED' : null,
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (_isOfficial) ...[
                          _animated(
                            2,
                            _TacticalDropdownField(
                              label: 'POSITION / TITLE',
                              value: _selectedPosition,
                              items: _officialPositions,
                              icon: Icons.badge_outlined,
                              onChanged: (v) {
                                setState(() {
                                  _selectedPosition = v;
                                  _positionCtrl.text = v ?? '';
                                });
                              },
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'REQUIRED' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ] else ...[
                          _animated(
                            2,
                            _TacticalFormField(
                              controller: _phoneCtrl,
                              label: 'PHONE NUMBER',
                              hint: '09XX XXX XXXX',
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _animated(
                            2,
                            _TacticalFormField(
                              controller: _addressCtrl,
                              label: 'HOME ADDRESS',
                              hint: 'House No., Street, Barangay',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        _animated(
                          2,
                          _TacticalFormField(
                            controller: _emailCtrl,
                            label: 'EMAIL ADDRESS',
                            hint: 'you@email.com',
                            icon: Icons.email_outlined,
                            readOnly: true,
                            helperText: 'EMAIL CANNOT BE CHANGED',
                          ),
                        ),
                        const SizedBox(height: 28),

                        _animated(3, const _SectionHeader('CHANGE PASSWORD')),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.only(left: 11, bottom: 14),
                          child: Text(
                            'Leave blank to keep your current password.',
                            style: TextStyle(
                              fontFamily: 'IBMPlexMono',
                              fontSize: 10,
                              color: AppColors.textDim,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        _animated(
                          3,
                          _TacticalFormField(
                            controller: _newPasswordCtrl,
                            label: 'NEW PASSWORD',
                            hint: '••••••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: !_showNewPass,
                            suffix: IconButton(
                              icon: Icon(
                                _showNewPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _showNewPass = !_showNewPass),
                            ),
                            validator: (v) {
                              if (v != null && v.isNotEmpty && v.length < 6) {
                                return 'MIN. 6 CHARACTERS';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        _animated(
                          4,
                          _TacticalFormField(
                            controller: _confirmPassCtrl,
                            label: 'CONFIRM PASSWORD',
                            hint: '••••••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: !_showConfirmPass,
                            suffix: IconButton(
                              icon: Icon(
                                _showConfirmPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(
                                () => _showConfirmPass = !_showConfirmPass,
                              ),
                            ),
                            validator: (v) {
                              if (_newPasswordCtrl.text.isNotEmpty &&
                                  v != _newPasswordCtrl.text) {
                                return 'PASSWORDS DO NOT MATCH';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 28),

                        _animated(
                          4,
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: _saving
                                ? _loadingBox()
                                : _TacticalButton(
                                    label: 'SAVE CHANGES',
                                    icon: Icons.save_outlined,
                                    onPressed: _saveChanges,
                                    primary: true,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        _animated(
                          5,
                          const _SectionHeader('DANGER ZONE', danger: true),
                        ),
                        const SizedBox(height: 14),

                        _animated(
                          5,
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.red.withValues(
                                        alpha: 0.7,
                                      ),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'TERMINATE ACCOUNT',
                                      style: TextStyle(
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.red,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Permanently purge your account and all associated reports from the database. This operation cannot be reversed.',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexMono',
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: _TacticalButton(
                                    label: 'DELETE MY ACCOUNT',
                                    icon: Icons.delete_forever_outlined,
                                    onPressed: _saving ? () {} : _confirmDelete,
                                    primary: false,
                                    danger: true,
                                  ),
                                ),
                              ],
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

  Widget _dividerRow(String label) => Row(
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

  Widget _loadingBox() => Container(
    decoration: BoxDecoration(
      color: AppColors.electric.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppColors.electric.withValues(alpha: 0.3)),
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
  );
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool danger;
  const _SectionHeader(this.label, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.electric;
    return Row(
      children: [
        Container(width: 3, height: 14, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: danger ? AppColors.red : AppColors.textPrimary,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

class _TacticalDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final IconData icon;
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;

  const _TacticalDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          validator: validator,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
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
              borderSide: const BorderSide(
                color: AppColors.electric,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: AppColors.red.withValues(alpha: 0.6),
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.red, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 9,
              color: AppColors.red,
              letterSpacing: 0.5,
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
          items: items
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
        ),
      ],
    );
  }
}

class _TacticalFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool readOnly;
  final Widget? suffix;
  final String? helperText;
  final String? Function(String?)? validator;

  const _TacticalFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.readOnly = false,
    this.suffix,
    this.helperText,
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
          obscureText: obscure,
          readOnly: readOnly,
          validator: validator,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 13,
            color: readOnly ? AppColors.textSecondary : AppColors.textPrimary,
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
            fillColor: readOnly ? AppColors.ink : AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: readOnly
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.electric,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: AppColors.red.withValues(alpha: 0.6),
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: AppColors.red, width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 9,
              color: AppColors.red,
              letterSpacing: 0.5,
            ),
            helperText: helperText,
            helperStyle: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 9,
              color: AppColors.textDim,
              letterSpacing: 0.5,
            ),
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
  final bool danger;

  const _TacticalButton({
    required this.label,
    required this.onPressed,
    this.icon,
    required this.primary,
    this.danger = false,
  });

  @override
  State<_TacticalButton> createState() => _TacticalButtonState();
}

class _TacticalButtonState extends State<_TacticalButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.danger ? AppColors.red : AppColors.electric;
    final accentDim = widget.danger ? AppColors.redDim : AppColors.electricDim;
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: widget.primary
              ? (_pressed ? accent : accentDim)
              : (_pressed
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.primary ? accent : accent.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 15,
                color: widget.primary ? Colors.white : accent,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.primary ? Colors.white : accent,
                letterSpacing: 2.5,
              ),
            ),
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
      ..color = AppColors.electric.withValues(alpha: 0.2)
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