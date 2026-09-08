// flood_risk_card.dart
//
// Drop this widget near the top of your Admin/Resident Dashboard screen,
// above the report list. It calls your FastAPI backend's
// /weather/rain-risk endpoint and shows a Low/Moderate/High/Severe
// flood-risk card based on the incoming rain forecast. When the backend
// flags evacuation_advisory=true (heavy rain expected), it also pops a
// one-time warning dialog.
//
// IMPORTANT: this is an ADVISORY, not an evacuation order. The dialog says
// "monitor barangay officials" on purpose — deciding to actually evacuate
// is a human/official decision, not something the app should declare on
// its own. Keep that wording when you customize this.
//
// Usage in your dashboard screen's build() method:
//   Column(
//     children: [
//       FloodRiskCard(baseUrl: "http://YOUR_BACKEND_HOST:8000"),
//       Expanded(child: ReportsList(...)),   // your existing report list
//     ],
//   )

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class FloodRiskCard extends StatefulWidget {
  final String baseUrl;
  final double? lat;
  final double? lng;

  const FloodRiskCard({
    super.key,
    required this.baseUrl,
    this.lat,
    this.lng,
  });

  @override
  State<FloodRiskCard> createState() => _FloodRiskCardState();
}

class _FloodRiskCardState extends State<FloodRiskCard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _advisoryShownForThisFetch = false;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.25, end: 0.7).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    _fetchRainRisk();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRainRisk() async {
    setState(() {
      _loading = true;
      _error = null;
      _advisoryShownForThisFetch = false;
    });

    try {
      final params = <String, String>{};
      if (widget.lat != null) params['lat'] = widget.lat.toString();
      if (widget.lng != null) params['lng'] = widget.lng.toString();

      final uri = Uri.parse('${widget.baseUrl}/weather/rain-risk')
          .replace(queryParameters: params.isEmpty ? null : params);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _data = parsed;
          _loading = false;
        });
        if (parsed['evacuation_advisory'] == true && mounted) {
          // Wait a frame so the dialog doesn't try to open mid-build.
          WidgetsBinding.instance.addPostFrameCallback((_) => _showEvacuationAdvisory(parsed));
        }
      } else {
        setState(() {
          _error = 'Server error (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Could not reach weather service';
        _loading = false;
      });
    }
  }

  void _showEvacuationAdvisory(Map<String, dynamic> data) {
    if (!mounted || _advisoryShownForThisFetch) return;
    _advisoryShownForThisFetch = true;

    final rainMm = data['expected_rain_mm_next_12h'];
    final action = data['recommended_action'] as String? ??
        'Heavy rainfall expected. Monitor official barangay announcements.';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.void_,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.crisis_alert, color: AppColors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'FLOOD RISK ADVISORY',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.red,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${rainMm ?? "Heavy"}mm of rain expected in the next 12 hours.',
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                action,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'This is a forecast-based advisory, not an official evacuation order. Wait for instructions from barangay officials.',
                  style: TextStyle(
                    fontFamily: 'IBMPlexMono',
                    fontSize: 9.5,
                    color: AppColors.amber,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'GOT IT',
                        style: TextStyle(fontFamily: 'Rajdhani', letterSpacing: 2, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red.withValues(alpha: 0.15),
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      // TODO: point this to your actual Announcements screen/route.
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'ANNOUNCEMENTS',
                        style: TextStyle(fontFamily: 'Rajdhani', letterSpacing: 1, fontWeight: FontWeight.w700),
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
  }

  Color _riskColor(String risk) => switch (risk) {
    'Severe' || 'High' => AppColors.red,
    'Moderate' => AppColors.amber,
    _ => AppColors.green,
  };

  IconData _riskIcon(String risk) => switch (risk) {
    'Severe' => Icons.crisis_alert,
    'High' => Icons.warning_amber_rounded,
    'Moderate' => Icons.cloud_outlined,
    _ => Icons.check_circle_outline,
  };

  String _riskLabel(String risk) => switch (risk) {
    'Severe' => 'SEVERE — EVACUATION ADVISORY',
    _ => '${risk.toUpperCase()} RISK',
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingCard();
    if (_error != null) return _buildErrorCard();
    return _buildRiskCard();
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.void_,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: AppColors.electric, strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          const Text(
            'CHECKING FLOOD RISK…',
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              fontSize: 10,
              color: AppColors.textDim,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: AppColors.void_,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Container(width: 3, color: AppColors.textDim.withValues(alpha: 0.4)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.textDim.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.cloud_off_rounded, color: AppColors.textDim, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FLOOD RISK UNAVAILABLE',
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _error!,
                            style: const TextStyle(
                              fontFamily: 'IBMPlexMono',
                              fontSize: 9.5,
                              color: AppColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _fetchRainRisk,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.electric.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.refresh_rounded, color: AppColors.electric, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard() {
    final risk = _data?['flood_risk'] as String? ?? 'Low';
    final rainMm = (_data?['expected_rain_mm_next_12h'] as num?)?.toDouble() ?? 0.0;
    final note = _data?['note'] as String? ?? '';
    final isSevere = risk == 'Severe';
    final color = _riskColor(risk);

    // Gauge scale headroom: 60mm covers the "Severe" threshold (>=50mm)
    // with a little room to spare, so the bar rarely maxes out flat.
    final fillFactor = (rainMm / 60).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppColors.void_,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: isSevere ? 0.55 : 0.3),
            width: isSevere ? 1.2 : 1,
          ),
          boxShadow: isSevere
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: _glow.value * 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3, color: color)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(_riskIcon(risk), color: color, size: 17),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'FLOOD RISK FORECAST',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _fetchRainRisk,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.electric.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.refresh_rounded, color: AppColors.electric, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Risk badge + rainfall-proxy tag ───────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _riskLabel(risk),
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'RAINFALL FORECAST',
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDim,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Rain amount readout ────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        rainMm.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'mm',
                        style: TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '· NEXT 12H',
                        style: TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 9,
                          color: AppColors.textDim,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Gauge bar ──────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(height: 5, color: AppColors.border),
                        FractionallySizedBox(
                          widthFactor: fillFactor,
                          child: Container(height: 5, color: color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    note,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 9.5,
                      color: AppColors.textDim,
                      height: 1.5,
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
}
