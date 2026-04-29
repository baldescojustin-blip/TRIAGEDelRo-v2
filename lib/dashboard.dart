import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'panels/login.dart';
import 'panels/account_settings.dart';
import 'panels/submit_report.dart';
import 'main.dart';

class _Report {
  final String id;
  final String description;
  final String category;
  final String severity;
  final String status;
  final DateTime submittedAt;

  _Report({
    required this.id,
    required this.description,
    required this.category,
    required this.severity,
    required this.status,
    required this.submittedAt,
  });

  factory _Report.fromMap(Map<String, dynamic> m) => _Report(
    id: (m['id'] as String).substring(0, 8).toUpperCase(),
    description: m['description'] ?? '',
    category: m['category'] ?? '',
    severity: m['severity'] ?? '',
    status: m['status'] ?? '',
    submittedAt: DateTime.parse(m['submitted_at']),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  String _username = 'User';
  String _fullName = '';
  String _role = 'community_member';
  List<_Report> _reports = [];
  bool _loadingUser = true;
  bool _loadingReports = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadUser();
    _loadReports();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _loadUser() {
    final data = AuthService.getUserData();
    setState(() {
      if (data != null) {
        _username = data['username'] ?? 'User';
        _fullName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
            .trim();
        _role = data['role'] ?? 'community_member';
      }
      _loadingUser = false;
    });
  }

  Future<void> _loadReports() async {
    setState(() => _loadingReports = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('reports')
          .select()
          .eq('user_id', userId)
          .order('submitted_at', ascending: false)
          .limit(20);
      setState(() {
        _reports = (data as List).map((r) => _Report.fromMap(r)).toList();
      });
    } catch (_) {
      // silently fail
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
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
                    'CONFIRM SIGN OUT',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Your session will be terminated. Confirm sign out?',
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
                        backgroundColor: AppColors.red.withOpacity(0.15),
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        minimumSize: const Size.fromHeight(44),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'SIGN OUT',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          letterSpacing: 2,
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
    if (confirmed == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
    }
  }

  Future<void> _openAccountSettings() async {
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
    if (refreshNeeded == true) _loadUser();
  }

  Future<void> _openSubmitReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitReportScreen()),
    );
    _loadReports();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  Color _severityColor(String s) => switch (s) {
    'High' => AppColors.red,
    'Medium' => AppColors.amber,
    _ => AppColors.green,
  };

  Color _statusColor(String s) => switch (s) {
    'Resolved' => AppColors.green,
    'Ongoing' => AppColors.blue,
    _ => AppColors.textSecondary,
  };

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 60) return '${d.inMinutes}M AGO';
    if (d.inHours < 24) return '${d.inHours}H AGO';
    return '${d.inDays}D AGO';
  }

  int get _pendingCount => _reports.where((r) => r.status == 'Pending').length;
  int get _highCount => _reports.where((r) => r.severity == 'High').length;
  int get _resolvedCount =>
      _reports.where((r) => r.status == 'Resolved').length;

  // Role display helpers
  String get _roleLabel =>
      _role == 'barangay_official' ? 'BRGY OFFICIAL' : 'COMMUNITY';
  String get _roleSubLabel =>
      _role == 'barangay_official' ? 'BDRRMC OFFICER' : 'MEMBER';
  Color get _roleColor =>
      _role == 'barangay_official' ? AppColors.amber : AppColors.electric;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(painter: _MiniHexPainter()),
            ),
            const SizedBox(width: 10),
            const Text(
              'TRIAGENAGA',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withOpacity(_pulse.value),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.manage_accounts_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Account',
            onPressed: _openAccountSettings,
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_outlined,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loadingUser
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.electric,
                strokeWidth: 2,
              ),
            )
          : RefreshIndicator(
              color: AppColors.electric,
              backgroundColor: AppColors.void_,
              onRefresh: _loadReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OperatorCard(
                      username: _username,
                      fullName: _fullName,
                      roleLabel: _roleLabel,
                      roleSubLabel: _roleSubLabel,
                      roleColor: _roleColor,
                      onTap: _openAccountSettings,
                      pulse: _pulse,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(
                      label: 'SITUATION OVERVIEW',
                      tag: 'LAST UPDATED ${_timeAgo(DateTime.now())}',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatTile(
                          label: 'PENDING',
                          value: '$_pendingCount',
                          color: AppColors.amber,
                          icon: Icons.pending_actions_outlined,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'CRITICAL',
                          value: '$_highCount',
                          color: AppColors.red,
                          icon: Icons.warning_amber_rounded,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'RESOLVED',
                          value: '$_resolvedCount',
                          color: AppColors.green,
                          icon: Icons.task_alt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionLabel(
                      label: 'INCIDENT LOG',
                      tag: '${_reports.length} RECORDS',
                    ),
                    const SizedBox(height: 12),
                    _loadingReports
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(
                                color: AppColors.electric,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _reports.isEmpty
                        ? _EmptyState(onSubmit: _openSubmitReport)
                        : Column(
                            children: _reports
                                .map(
                                  (r) => _IncidentCard(
                                    report: r,
                                    severityColor: _severityColor(r.severity),
                                    statusColor: _statusColor(r.status),
                                    timeAgo: _timeAgo(r.submittedAt),
                                  ),
                                )
                                .toList(),
                          ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      floatingActionButton: _SubmitFAB(onPressed: _openSubmitReport),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? tag;
  const _SectionLabel({required this.label, this.tag});

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
        const Spacer(),
        if (tag != null)
          Text(
            tag!,
            style: const TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 9,
              color: AppColors.textDim,
              letterSpacing: 1,
            ),
          ),
      ],
    );
  }
}

class _OperatorCard extends StatelessWidget {
  final String username;
  final String fullName;
  final String roleLabel;
  final String roleSubLabel;
  final Color roleColor;
  final VoidCallback onTap;
  final Animation<double> pulse;

  const _OperatorCard({
    required this.username,
    required this.fullName,
    required this.roleLabel,
    required this.roleSubLabel,
    required this.roleColor,
    required this.onTap,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _AccentCard(
        accentColor: AppColors.electric,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: _MiniHexPainter(
                        fillColor: AppColors.surface,
                        strokeColor: AppColors.electric,
                      ),
                      size: const Size(48, 48),
                    ),
                    Text(
                      username.isNotEmpty ? username[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.electric,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(
                        fontFamily: 'Rajdhani',
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    if (fullName.isNotEmpty)
                      Text(
                        fullName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMono',
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
              // Dynamic role badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: roleColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 9,
                        color: roleColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    roleSubLabel,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 8,
                      color: AppColors.textDim,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'IBMPlexMono',
                fontSize: 8,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyState({required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.void_,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 28,
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO INCIDENTS LOGGED',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Submit an incident report to begin\nmonitoring situational status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 10,
              color: AppColors.textSecondary,
              height: 1.7,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.add, size: 14),
            label: const Text(
              'SUBMIT INCIDENT',
              style: TextStyle(
                fontFamily: 'Rajdhani',
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.electric,
              side: const BorderSide(color: AppColors.electric, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final _Report report;
  final Color severityColor;
  final Color statusColor;
  final String timeAgo;

  const _IncidentCard({
    required this.report,
    required this.severityColor,
    required this.statusColor,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AccentCard(
        accentColor: severityColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(
                    label: report.severity.toUpperCase(),
                    color: severityColor,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    label: report.category.toUpperCase(),
                    color: AppColors.textDim,
                    filled: false,
                  ),
                  const Spacer(),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                report.description,
                style: const TextStyle(
                  fontFamily: 'SourceSans3',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'RPT-${report.id}',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  _Badge(
                    label: report.status.toUpperCase(),
                    color: statusColor,
                    filled: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Badge({required this.label, required this.color, this.filled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withOpacity(filled ? 0.3 : 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBMPlexMono',
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: filled ? color : AppColors.textDim,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SubmitFAB extends StatefulWidget {
  final VoidCallback onPressed;
  const _SubmitFAB({required this.onPressed});

  @override
  State<_SubmitFAB> createState() => _SubmitFABState();
}

class _SubmitFABState extends State<_SubmitFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppColors.electric.withOpacity(_glow.value * 0.5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: FloatingActionButton.extended(
        onPressed: widget.onPressed,
        backgroundColor: AppColors.electric,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        icon: const Icon(
          Icons.add_circle_outline,
          color: Colors.white,
          size: 18,
        ),
        label: const Text(
          'SUBMIT INCIDENT',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────

class _MiniHexPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;

  _MiniHexPainter({
    this.fillColor = AppColors.surface,
    this.strokeColor = AppColors.electric,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 * 0.88;
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── _AccentCard ──────────────────────────────────────────────────────────────
// Replaces non-uniform Border (different left color) + borderRadius combos,
// which Flutter does not support. Uses a Stack with a separate left bar.
class _AccentCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final Color bgColor;
  final double radius;
  final double accentWidth;

  const _AccentCard({
    required this.child,
    required this.accentColor,
    this.bgColor = AppColors.void_,
    this.radius = 6,
    this.accentWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          // Full card background + uniform border
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: child,
          ),
          // Left accent bar on top
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: accentWidth, color: accentColor),
          ),
        ],
      ),
    );
  }
}