import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// ─── Document types ───────────────────────────────────────────────────────────
class _DocType {
  final String title;
  final String subtitle;
  final IconData icon;
  const _DocType({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _docTypes = [
  _DocType(
    title: 'Barangay Clearance',
    subtitle: 'Required for job applications and IDs',
    icon: Icons.shield_outlined,
  ),
  _DocType(
    title: 'Certificate of Indigency',
    subtitle: 'For financial, medical, or legal aid',
    icon: Icons.volunteer_activism_outlined,
  ),
  _DocType(
    title: 'Business Permit',
    subtitle: 'New registration or annual renewal',
    icon: Icons.store_outlined,
  ),
  _DocType(
    title: 'Barangay Residency',
    subtitle: 'Proof of residency in the barangay',
    icon: Icons.home_outlined,
  ),
  _DocType(
    title: 'Certificate of Indigence',
    subtitle: 'For scholarship and assistance programs',
    icon: Icons.school_outlined,
  ),
];

// ─── Request model ────────────────────────────────────────────────────────────
class _DocRequest {
  final String id;
  final String rawId;
  final String documentType;
  final String status;
  final String? notes;
  final DateTime createdAt;

  _DocRequest({
    required this.id,
    required this.rawId,
    required this.documentType,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory _DocRequest.fromMap(Map<String, dynamic> m) => _DocRequest(
    id: 'BRG-${(m['id'] as String).substring(0, 4).toUpperCase()}',
    rawId: m['id'] as String,
    documentType: m['document_type'] ?? '',
    status: m['status'] ?? 'Pending',
    notes: m['notes'] as String?,
    createdAt: DateTime.parse(m['created_at']),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class DocumentRequestScreen extends StatefulWidget {
  const DocumentRequestScreen({super.key});

  @override
  State<DocumentRequestScreen> createState() => _DocumentRequestScreenState();
}

class _DocumentRequestScreenState extends State<DocumentRequestScreen>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  List<_DocRequest> _requests = [];
  bool _loadingRequests = true;
  bool _submitting = false;

  late AnimationController _scanCtrl;
  late AnimationController _enterCtrl;
  late Animation<double> _scan;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _scan = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);

    _fadeAnims = List.generate(
      5,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(i * 0.1, 0.6 + i * 0.08, curve: Curves.easeOut),
        ),
      ),
    );
    _slideAnims = List.generate(
      5,
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

    _loadRequests();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Widget _animated(int i, Widget child) => SlideTransition(
    position: _slideAnims[i],
    child: FadeTransition(opacity: _fadeAnims[i], child: child),
  );

  Future<void> _loadRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('document_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(30);
      setState(() {
        _requests = (data as List).map((r) => _DocRequest.fromMap(r)).toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _requestDocument(String documentType) async {
    // Check if there's already a pending/processing request for this doc type
    final existing = _requests.where(
      (r) =>
          r.documentType == documentType &&
          (r.status == 'Pending' || r.status == 'Processing'),
    );
    if (existing.isNotEmpty) {
      _showSnack(
        'YOU ALREADY HAVE AN ACTIVE REQUEST FOR THIS DOCUMENT',
        AppColors.amber,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('document_requests').insert({
        'user_id': userId,
        'document_type': documentType,
        'status': 'Pending',
      });
      await _loadRequests();
      if (!mounted) return;
      _showConfirmDialog(documentType);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'REQUEST FAILED — ${e.toString().toUpperCase()}',
        AppColors.red,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showConfirmDialog(String documentType) {
    showDialog(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.85),
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.green,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'REQUEST SUBMITTED',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                documentType.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electric,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your document request has been submitted to the barangay office. You will be notified once it is ready for pickup.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  height: 1.7,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'STATUS: PENDING PROCESSING',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 9,
                        color: AppColors.amber,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: _TacticalButton(
                  label: 'CLOSE',
                  onPressed: () => Navigator.pop(ctx),
                  primary: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  : color == AppColors.amber
                  ? Icons.info_outline
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

  Color _statusColor(String s) => switch (s) {
    'Ready for Pickup' => AppColors.green,
    'Approved' => AppColors.blue,
    'Processing' => AppColors.amber,
    'Rejected' => AppColors.red,
    _ => AppColors.textSecondary, // Pending
  };

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

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

  Map<String, List<_DocRequest>> get _groupedRequests {
    final groups = <String, List<_DocRequest>>{};
    for (final r in _requests) {
      final label = _dateLabel(r.createdAt);
      groups.putIfAbsent(label, () => []).add(r);
    }
    return groups;
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
              Icons.description_outlined,
              size: 18,
              color: AppColors.electric,
            ),
            SizedBox(width: 8),
            Text(
              'DOCUMENT REQUESTS',
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
                          AppColors.electric.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const IgnorePointer(child: _CornerAccents()),
          RefreshIndicator(
            color: AppColors.electric,
            backgroundColor: AppColors.void_,
            onRefresh: _loadRequests,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ──────────────────────────────────────
                  _animated(
                    0,
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.electric.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.electric.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.electric.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.electric,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Request official barangay documents below. Processing typically takes 1–3 business days. You will be notified when your document is ready.',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMono',
                                fontSize: 10,
                                color: AppColors.textSecondary,
                                height: 1.6,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Available Documents ──────────────────────────────
                  _animated(
                    1,
                    _SectionLabel(
                      label: 'AVAILABLE DOCUMENTS',
                      tag: '${_docTypes.length} TYPES',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _animated(
                    1,
                    Column(
                      children: _docTypes.map((doc) {
                        final hasPending = _requests.any(
                          (r) =>
                              r.documentType == doc.title &&
                              (r.status == 'Pending' ||
                                  r.status == 'Processing'),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AccentCard(
                            accentColor: hasPending
                                ? AppColors.amber
                                : AppColors.electric,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppColors.electric.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: AppColors.electric.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      doc.icon,
                                      color: AppColors.electric,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc.title,
                                          style: const TextStyle(
                                            fontFamily: 'Rajdhani',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          doc.subtitle,
                                          style: const TextStyle(
                                            fontFamily: 'IBMPlexMono',
                                            fontSize: 9,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        if (hasPending) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.amber.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              border: Border.all(
                                                color: AppColors.amber
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: const Text(
                                              'REQUEST IN PROGRESS',
                                              style: TextStyle(
                                                fontFamily: 'IBMPlexMono',
                                                fontSize: 8,
                                                color: AppColors.amber,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _submitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.electric,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : hasPending
                                      ? const Icon(
                                          Icons.hourglass_top_rounded,
                                          color: AppColors.amber,
                                          size: 18,
                                        )
                                      : GestureDetector(
                                          onTap: () =>
                                              _requestDocument(doc.title),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.electric
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                              border: Border.all(
                                                color: AppColors.electric
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: const Text(
                                              'REQUEST',
                                              style: TextStyle(
                                                fontFamily: 'Rajdhani',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.electric,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Request History ──────────────────────────────────
                  _animated(
                    2,
                    _SectionLabel(
                      label: 'REQUEST HISTORY',
                      tag: '${_requests.length} RECORDS',
                    ),
                  ),
                  const SizedBox(height: 12),

                  _loadingRequests
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: AppColors.electric,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _requests.isEmpty
                      ? _animated(3, const _EmptyHistory())
                      : _animated(3, _buildGroupedHistory()),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedHistory() {
    final groups = _groupedRequests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.entries.map((entry) {
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
                    entry.key,
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
                    '${entry.value.length}',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map((r) => _HistoryCard(
              request: r,
              statusColor: _statusColor(r.status),
              formattedDate: _formatDate(r.createdAt),
            )),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

// ─── History Card ─────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final _DocRequest request;
  final Color statusColor;
  final String formattedDate;

  const _HistoryCard({
    required this.request,
    required this.statusColor,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _AccentCard(
        accentColor: statusColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ref: #${request.id}',
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      request.status.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.documentType,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              if (request.notes != null && request.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  request.notes!,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 10,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9,
                      color: AppColors.textDim,
                      letterSpacing: 0.5,
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

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    decoration: BoxDecoration(
      color: AppColors.void_,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 26, color: AppColors.textDim),
        SizedBox(height: 14),
        Text(
          'NO REQUESTS YET',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.textPrimary,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Your document request history\nwill appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontSize: 10,
            color: AppColors.textSecondary,
            height: 1.7,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? tag;
  const _SectionLabel({required this.label, this.tag});

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

// ─── Tactical Button ──────────────────────────────────────────────────────────
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
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 15,
                color: widget.primary
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.primary ? Colors.white : AppColors.textSecondary,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Accent Card ──────────────────────────────────────────────────────────────
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: child,
        ),
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