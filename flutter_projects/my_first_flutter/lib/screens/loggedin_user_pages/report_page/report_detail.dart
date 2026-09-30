import 'package:flutter/material.dart';

import '../../../utils/color_utils.dart';
import '../../../widgets/swipe_back.dart';

class ReportDetailPage extends StatelessWidget {
  final Map<String, String> report;
  // Position-ordered [{key, label, color}] from the reports list screen
  // — drives the timeline below. Falls back to the old fixed 3-step
  // list if this ever arrives empty (e.g. a stale cached navigation),
  // so the page never renders with no steps at all.
  final List<Map<String, String>> statuses;

  const ReportDetailPage({super.key, required this.report, this.statuses = const []});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color pendingColor = Color(0xFFD97706);

  List<Map<String, String>> get _effectiveStatuses => statuses.isNotEmpty
      ? statuses
      : const [
          {'key': 'PENDING', 'label': 'Pending', 'color': '#D97706'},
          {'key': 'UNDER_REVIEW', 'label': 'Under Review', 'color': '#00334D'},
          {'key': 'RESOLVED', 'label': 'Resolved', 'color': '#1A7F4B'},
        ];

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  int _statusStep(String status) {
    final index = _effectiveStatuses.indexWhere((s) => s['label'] == status);
    // Unrecognized status (e.g. cache from before an update) — treat
    // as the first step rather than crashing on a -1 index below.
    return index >= 0 ? index : 0;
  }

  Color _stepColor(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= _effectiveStatuses.length) {
      return Colors.grey.shade300;
    }
    return hexToColor(_effectiveStatuses[stepIndex]['color'], fallback: pendingColor);
  }

  @override
  Widget build(BuildContext context) {
    final String status = report['status'] ?? 'Pending';
    final String ref = report['ref'] ?? '';
    final String type = report['type'] ?? '';
    final String date = report['date'] ?? '';
    final String description = report['description'] ?? '';
    final String location = report['location'] ?? report['region'] ?? '';
    final String reporterName = report['reporter_name'] ?? '';
    final String reporterPhone = report['reporter_phone'] ?? '';
    final String dateOfIncident = report['date_of_incident'] ?? '';
    final int step = _statusStep(status);

    final List<Map<String, dynamic>> steps = [
      for (int i = 0; i < _effectiveStatuses.length; i++)
        {'label': _effectiveStatuses[i]['label'], 'index': i},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Reference Number =====
            Text(
              ref,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 20),

            // ===== Status Section =====
            const Text(
              'STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            // ===== Progress Timeline =====
            Row(
              children: [
                for (int i = 0; i < steps.length; i++) ...[
                  _timelineStep(
                    label: steps[i]['label'],
                    stepIndex: steps[i]['index'],
                    isActive: step >= steps[i]['index'],
                    // A reached FINAL step (e.g. Resolved) counts as
                    // done too, not just steps strictly before the
                    // current one — otherwise the last step you land
                    // on never gets its checkmark, just a plain dot,
                    // even though there's nothing left after it.
                    isDone: step > steps[i]['index'] ||
                        (step == steps[i]['index'] &&
                            steps[i]['index'] == steps.length - 1),
                    isCurrent: step == steps[i]['index'],
                  ),
                  if (i < steps.length - 1)
                    // Colored to match the step being left (e.g.
                    // Pending's amber), not always the same blue
                    // regardless of which segment of the timeline
                    // it is.
                    _timelineLine(
                      isActive: step > i,
                      color: _stepColor(i),
                    ),
                ],
              ],
            ),

            const SizedBox(height: 32),

            // ===== Incident Details =====
            const Text(
              'INCIDENT DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 16),

            _detailRow('Incident Type', type),
            _detailRow(
                'Date of Incident', _formatDate(dateOfIncident)),
            _detailRow('Date Submitted', _formatDate(date)),
            if (location.isNotEmpty) _detailRow('Location', location),

            const SizedBox(height: 28),

            // ===== Description =====
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              description.isNotEmpty
                  ? description
                  : 'No description provided.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Colors.black87,
              ),
            ),

            if (reporterName.isNotEmpty ||
                reporterPhone.isNotEmpty) ...[
              const SizedBox(height: 28),

              // ===== Reporter Details =====
              const Text(
                'REPORTER DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              if (reporterName.isNotEmpty)
                _detailRow('Name', reporterName),
              if (reporterPhone.isNotEmpty)
                _detailRow('Phone', reporterPhone),
            ],

            const SizedBox(height: 32),


          ],
        ),
      ),
      ),
    );
  }

  Widget _timelineStep({
    required String label,
    required int stepIndex,
    required bool isActive,
    required bool isDone,
    required bool isCurrent,
  }) {
    final color = isActive ? _stepColor(stepIndex) : Colors.grey.shade300;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : const Color(0xFFEEEEEE),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 14)
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : Colors.grey.shade400,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineLine({required bool isActive, required Color color}) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          // Matches the color of the step being left (e.g. Pending's
          // amber for the Pending -> Under Review segment) — no
          // two-tone gradient blend between step colors.
          color: isActive ? color : const Color(0xFFE4E6EB),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}