import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:supabase_flutter/supabase_flutter.dart';

// Removed auth_service.dart import since Supabase handles this directly now
import 'login.dart';
import 'account_settings.dart';
import 'submit_report.dart';
import 'document_request.dart';
import '../main.dart';

class _Report {
  final String id;
  final String description;
  final String location;
  final double? lat;
  final double? lng;
  final String category;
  final String severity;
  final String status;
  final DateTime submittedAt;

  _Report({
    required this.id,
    required this.description,
    required this.location,
    required this.lat,
    required this.lng,
    required this.category,
    required this.severity,
    required this.status,
    required this.submittedAt,
  });

  factory _Report.fromMap(Map<String, dynamic> m) => _Report(
    id: (m['id'] as String).substring(0, 8).toUpperCase(),
    description: m['description'] ?? '',
    location: m['location'] ?? '',
    lat: (m['lat'] as num?)?.toDouble(),
    lng: (m['lng'] as num?)?.toDouble(),
    category: m['category'] ?? '',
    severity: m['severity'] ?? '',
    status: m['status'] ?? '',
    submittedAt: DateTime.parse(m['submitted_at']),
  );

  bool get hasCoords => lat != null && lng != null;
}

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});
  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  String _username = 'User';
  String _fullName = '';
  List<_Report> _reports = [];
  bool _loadingUser = true;
  bool _loadingReports = true;

  // FAB expand state
  bool _fabExpanded = false;

  late AnimationController _pulseCtrl;
  late AnimationController _fabCtrl;
  late Animation<double> _pulse;
  late Animation<double> _fabAnim;

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

    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabAnim = CurvedAnimation(parent: _fabCtrl, curve: Curves.easeOutCubic);

    _loadUser();
    _loadReports();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fabCtrl.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabCtrl.forward();
    } else {
      _fabCtrl.reverse();
    }
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabCtrl.reverse();
    }
  }

  // --- SUPABASE CHANGE: Fetch real user data from your residents table ---
  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        // Fetch from the 'residents' table using the Auth ID
        final data = await _supabase
            .from('residents')
            .select('username, first_name, last_name')
            .eq('id', userId)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _username = data['username'] ?? 'User';
            _fullName = '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    } finally {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  // --- SUPABASE CHANGE: Added safe type casting for data mapping ---
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
          .limit(50);
          
      setState(() {
        _reports = (data as List<dynamic>)
            .map((r) => _Report.fromMap(r as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      print('Error loading reports: $e');
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  // --- SUPABASE CHANGE: Native Supabase Sign Out ---
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _LogoutDialog(),
    );
    if (confirmed == true) {
      await _supabase.auth.signOut(); // Directly sign out via Supabase
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (_) => false,
      );
    }
  }

  Future<void> _openAccountSettings() async {
    _closeFab();
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
    );
    if (refreshNeeded == true) _loadUser();
  }

  Future<void> _openSubmitReport() async {
    _closeFab();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SubmitReportScreen()),
    );
    _loadReports();
  }

  Future<void> _openDocumentRequest() async {
    _closeFab();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DocumentRequestScreen()),
    );
  }

  void _openReportDetail(_Report report) {
    _closeFab();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ResidentReportDetailScreen(
          report: report,
          severityColor: _severityColor(report.severity),
          statusColor: _statusColor(report.status),
        ),
      ),
    );
  }

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

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'TODAY';
    if (d == yesterday) return 'YESTERDAY';
    final diff = today.difference(d).inDays;
    if (diff < 7) return '${diff}D AGO';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'JUST NOW';
    if (d.inMinutes < 60) return '${d.inMinutes}M AGO';
    if (d.inHours < 24) return '${d.inHours}H AGO';
    return '${d.inDays}D AGO';
  }

  Map<String, List<_Report>> get _groupedReports {
    final groups = <String, List<_Report>>{};
    for (final r in _reports) {
      final label = _dateLabel(r.submittedAt);
      groups.putIfAbsent(label, () => []).add(r);
    }
    return groups;
  }

  int get _pendingCount => _reports.where((r) => r.status == 'Pending').length;
  int get _highCount => _reports.where((r) => r.severity == 'High').length;
  int get _resolvedCount =>
      _reports.where((r) => r.status == 'Resolved').length;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        appBar: AppBar(
          backgroundColor: AppColors.ink,
          elevation: 0,
          titleSpacing: 20,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(painter: _MiniHexPainter()),
              ),
              const SizedBox(width: 10),
              const Text(
                'TRIAGE DEL ROSARIO',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 16,
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
                        color: AppColors.green.withValues(alpha: _pulse.value),
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
              tooltip: 'Account Settings',
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
                        roleLabel: 'COMMUNITY',
                        roleSubLabel: 'MEMBER',
                        roleColor: AppColors.electric,
                        onTap: _openAccountSettings,
                        pulse: _pulse,
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(
                        label: 'SITUATION OVERVIEW',
                        tag: _timeAgo(DateTime.now()),
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
                        label: 'MY INCIDENT LOG',
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
                          : _buildGroupedList(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
        // ── Expandable FAB ───────────────────────────────────────────────────
        floatingActionButton: _ExpandableFAB(
          isExpanded: _fabExpanded,
          fabAnim: _fabAnim,
          onToggle: _toggleFab,
          onSubmitIncident: _openSubmitReport,
          onDocumentRequest: _openDocumentRequest,
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = _groupedReports;
    final keys = groups.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((dateLabel) {
        final items = groups[dateLabel]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Container(width: 2, height: 10, color: AppColors.textDim),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            ...items.map(
              (r) => _IncidentCard(
                report: r,
                severityColor: _severityColor(r.severity),
                statusColor: _statusColor(r.status),
                timeAgo: _timeAgo(r.submittedAt),
                onTap: () => _openReportDetail(r),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Expandable FAB ───────────────────────────────────────────────────────────
class _ExpandableFAB extends StatefulWidget {
  final bool isExpanded;
  final Animation<double> fabAnim;
  final VoidCallback onToggle;
  final VoidCallback onSubmitIncident;
  final VoidCallback onDocumentRequest;

  const _ExpandableFAB({
    required this.isExpanded,
    required this.fabAnim,
    required this.onToggle,
    required this.onSubmitIncident,
    required this.onDocumentRequest,
  });

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Mini FAB: Document Request ────────────────────────────────────
        AnimatedBuilder(
          animation: widget.fabAnim,
          builder: (_, child) => Transform.scale(
            scale: widget.fabAnim.value,
            alignment: Alignment.bottomRight,
            child: Opacity(
              opacity: widget.fabAnim.value,
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.void_,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'DOCUMENT REQUEST',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'fab_doc',
                  mini: true,
                  onPressed: widget.onDocumentRequest,
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: AppColors.electric.withValues(alpha: 0.4),
                    ),
                  ),
                  elevation: 2,
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.electric,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Mini FAB: Submit Incident ─────────────────────────────────────
        AnimatedBuilder(
          animation: widget.fabAnim,
          builder: (_, child) => Transform.scale(
            scale: widget.fabAnim.value,
            alignment: Alignment.bottomRight,
            child: Opacity(
              opacity: widget.fabAnim.value,
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.void_,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    'SUBMIT INCIDENT',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'fab_incident',
                  mini: true,
                  onPressed: widget.onSubmitIncident,
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: AppColors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  elevation: 2,
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: AppColors.red,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Main FAB (toggle) ─────────────────────────────────────────────
        AnimatedBuilder(
          animation: _glow,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppColors.electric.withValues(
                    alpha: widget.isExpanded ? 0 : _glow.value * 0.5,
                  ),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: FloatingActionButton.extended(
            heroTag: 'fab_main',
            onPressed: widget.onToggle,
            backgroundColor: widget.isExpanded
                ? AppColors.surface
                : AppColors.electric,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: widget.isExpanded
                    ? AppColors.border
                    : AppColors.electric,
              ),
            ),
            elevation: widget.isExpanded ? 1 : 4,
            icon: AnimatedRotation(
              turns: widget.isExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                widget.isExpanded ? Icons.close : Icons.add,
                color: widget.isExpanded
                    ? AppColors.textSecondary
                    : Colors.white,
                size: 20,
              ),
            ),
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                widget.isExpanded ? 'CLOSE' : 'ACTIONS',
                key: ValueKey(widget.isExpanded),
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: widget.isExpanded
                      ? AppColors.textSecondary
                      : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Resident Report Detail (read-only) ──────────────────────────────────────
class _ResidentReportDetailScreen extends StatelessWidget {
  final _Report report;
  final Color severityColor;
  final Color statusColor;

  const _ResidentReportDetailScreen({
    required this.report,
    required this.severityColor,
    required this.statusColor,
  });

  String _formatDateTime(DateTime dt) {
    final months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.description_outlined, size: 16, color: AppColors.electric),
            const SizedBox(width: 8),
            Text(
              'RPT-${r.id}',
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(label: r.severity.toUpperCase(), color: severityColor),
                const SizedBox(width: 8),
                _Badge(label: r.category.toUpperCase(), color: AppColors.textDim, filled: false),
                const Spacer(),
                _Badge(label: r.status.toUpperCase(), color: statusColor),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'STATUS IS MANAGED BY BARANGAY OFFICIALS',
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 8,
                  color: AppColors.textDim.withValues(alpha: 0.6),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailRow(icon: Icons.access_time_rounded, label: 'SUBMITTED', value: _formatDateTime(r.submittedAt)),
            const SizedBox(height: 16),
            _DetailSection(
              label: 'INCIDENT DESCRIPTION',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  r.description,
                  style: const TextStyle(fontFamily: 'SourceSans3', fontSize: 14, color: AppColors.textPrimary, height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _DetailSection(
              label: 'LOCATION',
              child: Column(
                children: [
                  if (r.location.isNotEmpty)
                    _DetailRow(icon: Icons.place_outlined, label: 'DESCRIPTION', value: r.location),
                  if (r.hasCoords) ...[
                    if (r.location.isNotEmpty) const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.my_location_rounded,
                      label: 'GPS COORDINATES',
                      value: '${r.lat!.toStringAsFixed(6)}, ${r.lng!.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: latlng.LatLng(r.lat!, r.lng!),
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.triage.delrosario',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: latlng.LatLng(r.lat!, r.lng!),
                                  width: 40,
                                  height: 40,
                                  child: _MapPin(color: severityColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!r.hasCoords && r.location.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_off_outlined, size: 14, color: AppColors.textDim),
                          SizedBox(width: 8),
                          Text('NO LOCATION PROVIDED', style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 10, color: AppColors.textDim, letterSpacing: 1)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DetailSection(
              label: 'REPORT METADATA',
              child: Column(
                children: [
                  _DetailRow(icon: Icons.tag, label: 'REPORT ID', value: 'RPT-${r.id}'),
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.category_outlined, label: 'CATEGORY', value: r.category),
                  const SizedBox(height: 10),
                  _DetailRow(icon: Icons.priority_high_rounded, label: 'SEVERITY', value: r.severity),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _DetailSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(width: 3, height: 12, color: AppColors.electric),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 2.5)),
        ],
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: AppColors.textDim),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 8, color: AppColors.textDim, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 11, color: AppColors.textPrimary, letterSpacing: 0.5)),
        ],
      ),
    ],
  );
}

class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
        ),
        child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
      ),
      Container(width: 2, height: 6, color: color),
    ],
  );
}

// ─── Widgets ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? tag;
  const _SectionLabel({required this.label, this.tag});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 14, color: AppColors.electric),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 2.5)),
      const Spacer(),
      if (tag != null) Text(tag!, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.textDim, letterSpacing: 1)),
    ],
  );
}

class _OperatorCard extends StatelessWidget {
  final String username, fullName, roleLabel, roleSubLabel;
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: _AccentCard(
      accentColor: roleColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48, height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(painter: _MiniHexPainter(fillColor: AppColors.surface, strokeColor: roleColor), size: const Size(48, 48)),
                  Text(username.isNotEmpty ? username[0].toUpperCase() : 'U',
                    style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800, color: roleColor)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@$username', style: const TextStyle(fontFamily: 'Rajdhani', color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  if (fullName.isNotEmpty)
                    Text(fullName.toUpperCase(), style: const TextStyle(fontFamily: 'IBMPlexMono', color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: roleColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(roleLabel, style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: roleColor, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 4),
                Text(roleSubLabel, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 8, color: AppColors.textDim, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontSize: 28, fontWeight: FontWeight.w800, color: color, height: 1)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 8, color: AppColors.textSecondary, letterSpacing: 1.5)),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSubmit;
  const _EmptyState({required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
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
          width: 56, height: 56,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.border)),
          child: const Icon(Icons.inbox_outlined, size: 28, color: AppColors.textDim),
        ),
        const SizedBox(height: 16),
        const Text('NO INCIDENTS LOGGED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary, letterSpacing: 2)),
        const SizedBox(height: 8),
        const Text('Submit an incident report to begin\nmonitoring situational status.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 10, color: AppColors.textSecondary, height: 1.7, letterSpacing: 0.5)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.add, size: 14),
          label: const Text('SUBMIT INCIDENT', style: TextStyle(fontFamily: 'Rajdhani', letterSpacing: 2, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.electric,
            side: const BorderSide(color: AppColors.electric, width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ],
    ),
  );
}

class _IncidentCard extends StatelessWidget {
  final _Report report;
  final Color severityColor, statusColor;
  final String timeAgo;
  final VoidCallback onTap;

  const _IncidentCard({required this.report, required this.severityColor, required this.statusColor, required this.timeAgo, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: onTap,
      child: _AccentCard(
        accentColor: severityColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Badge(label: report.severity.toUpperCase(), color: severityColor),
                  const SizedBox(width: 6),
                  _Badge(label: report.category.toUpperCase(), color: AppColors.textDim, filled: false),
                  if (report.hasCoords) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.location_on, size: 11, color: AppColors.electric.withValues(alpha: 0.7)),
                  ],
                  const Spacer(),
                  Text(timeAgo, style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.textDim, letterSpacing: 0.8)),
                ],
              ),
              const SizedBox(height: 10),
              Text(report.description, style: const TextStyle(fontFamily: 'SourceSans3', fontSize: 13, color: AppColors.textPrimary, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (report.location.isNotEmpty || report.hasCoords) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textDim),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.hasCoords
                            ? '${report.lat!.toStringAsFixed(5)}, ${report.lng!.toStringAsFixed(5)}${report.location.isNotEmpty ? ' · ${report.location}' : ''}'
                            : report.location,
                        style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.textDim, letterSpacing: 0.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('RPT-${report.id}', style: const TextStyle(fontFamily: 'IBMPlexMono', fontSize: 9, color: AppColors.textDim, letterSpacing: 1.2)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 12, color: AppColors.textDim),
                  const Spacer(),
                  _Badge(label: report.status.toUpperCase(), color: statusColor),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _Badge({required this.label, required this.color, this.filled = true});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: color.withValues(alpha: filled ? 0.3 : 0.2)),
    ),
    child: Text(label, style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 8, fontWeight: FontWeight.w600, color: filled ? color : AppColors.textDim, letterSpacing: 1)),
  );
}

// ─── Painters ─────────────────────────────────────────────────────────────────
class _MiniHexPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  _MiniHexPainter({Color? fillColor, Color? strokeColor})
    : fillColor = fillColor ?? AppColors.surface,
      strokeColor = strokeColor ?? AppColors.electric;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2, r = size.width / 2 * 0.88;
    final path = ui.Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final x = cx + r * math.cos(angle), y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(path, Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AccentCard extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final Color bgColor;
  final double radius, accentWidth;

  const _AccentCard({required this.child, required this.accentColor, this.bgColor = AppColors.void_, this.radius = 6, this.accentWidth = 2});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(radius), border: Border.all(color: AppColors.border, width: 1)),
          child: child,
        ),
        Positioned(left: 0, top: 0, bottom: 0, child: Container(width: accentWidth, color: accentColor)),
      ],
    ),
  );
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.void_,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: const BorderSide(color: AppColors.border)),
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
              const Text('CONFIRM SIGN OUT', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Your session will be terminated. Confirm sign out?',
            style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 11, color: AppColors.textSecondary, height: 1.6, letterSpacing: 0.5)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border), foregroundColor: AppColors.textSecondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL', style: TextStyle(fontFamily: 'Rajdhani', letterSpacing: 2, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red.withValues(alpha: 0.15),
                    foregroundColor: AppColors.red,
                    side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    minimumSize: const Size.fromHeight(44),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('SIGN OUT', style: TextStyle(fontFamily: 'Rajdhani', letterSpacing: 2, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}