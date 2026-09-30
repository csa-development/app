import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/notification_service.dart';
import '../../utils/color_utils.dart';
import '../main_user_screens/report_incident.dart';
import 'report_page/report_detail.dart';

class LoggedInReport extends StatefulWidget {
  const LoggedInReport({super.key});

  @override
  State<LoggedInReport> createState() => _LoggedInReportState();
}

class _LoggedInReportState extends State<LoggedInReport> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color bgColor = Color(0xFFF8F9FB);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF444444);
  static const Color textHelper = Color(0xFF888888);
  static const Color borderColor = Color(0xFFE4E6EB);

  // ===== Status dot colors =====
  // Fallbacks only, used if the statuses API hasn't loaded yet — once
  // it has, colors come from the server (see _statuses / _dotColor),
  // so a status CERT adds gets a correct color without an app update.
  static const Color pendingDot = Color(0xFFD97706);   // amber
  static const Color resolvedDot = Color(0xFF1A7F4B);  // green — still
      // used for the fixed "Resolved" summary stat box below, which
      // (like its Pending sibling) deliberately stays a fixed pair of
      // boundary states rather than growing a tile per status.

  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  List<Map<String, String>> _reports = [];
  // Position-ordered [{key, label, color}], loaded from the server —
  // drives both the filter chips and each report's status dot color.
  List<Map<String, String>> _statuses = [];

  List<String> get _filters =>
      ['All', ..._statuses.map((s) => s['label']!)];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadReports();

    // Instant refresh the moment a push arrives while this screen is
    // open (e.g. CERT changes this report's status).
    NotificationService.refreshSignal.addListener(_silentReload);

    // Baseline safety net independent of push delivery — a missed or
    // delayed push (poor connection, notification permission denied,
    // etc.) would otherwise mean the status silently goes stale until
    // the user thinks to pull-to-refresh themselves.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentReload(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    NotificationService.refreshSignal.removeListener(_silentReload);
    _pollTimer?.cancel();
    super.dispose();
  }

  // Refreshes data without the full-screen loading skeleton — used for
  // the automatic refreshes above so an update landing while the user
  // is actively reading/scrolling doesn't yank the whole list away
  // and replace it with a shimmer, just for it to reappear a moment
  // later. The manual pull-to-refresh path (_loadReports() below,
  // called directly by RefreshIndicator) keeps its own visible loading
  // state, since that one's a deliberate user action.
  void _silentReload() => _loadReports(silent: true);

  Future<void> _loadReports({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';
    final results = await Future.wait([
      ApiService.getMyReports(accessToken: accessToken),
      ApiService.getIncidentStatuses(accessToken: accessToken),
    ]);
    if (!mounted) return;
    final result = results[0];
    final statusesResult = results[1];

    if (statusesResult['success']) {
      final List statuses = statusesResult['data']['statuses'];
      setState(() {
        _statuses = statuses
            .map((s) => {
                  'key': s['key'].toString(),
                  'label': s['label'].toString(),
                  'color': s['color'].toString(),
                })
            .toList();
      });
    }

    if (result['success']) {
      final List reports = result['data']['reports'];
      setState(() {
        _reports = reports
            .map(
              (r) => {
                'ref': r['reference_number'].toString(),
                'type': r['incident_type'].toString(),
                'date': r['created_at'].toString(),
                'status': r['status'].toString(),
                'status_color': r['status_color']?.toString() ?? '',
                'description': r['description'].toString(),
                'platform': r['platform'].toString(),
                'location': (r['location'] ?? r['region'])?.toString() ?? '',
                'reporter_name': r['reporter_name']?.toString() ?? '',
                'reporter_phone': r['reporter_phone']?.toString() ?? '',
                'date_of_incident':
                    r['date_of_incident']?.toString() ?? '',
              },
            )
            .toList();
      });
    }

    if (!silent) setState(() => _isLoading = false);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
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

  Color _dotColor(Map<String, String> report) =>
      hexToColor(report['status_color'], fallback: pendingDot);

  List<Map<String, String>> get _filteredReports {
    return _reports.where((report) {
      final matchesFilter =
          _selectedFilter == 'All' || report['status'] == _selectedFilter;
      final query = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          (report['type'] ?? '').toLowerCase().contains(query) ||
          (report['ref'] ?? '').toLowerCase().contains(query) ||
          (report['description'] ?? '').toLowerCase().contains(query) ||
          (report['date'] ?? '').toLowerCase().contains(query) ||
          (report['platform'] ?? '').toLowerCase().contains(query) ||
          (report['location'] ?? '').toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  Widget _buildSkeleton() {
    return _Shimmer(
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(height: 28, width: 120),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _skeletonBox(height: 72)),
              const SizedBox(width: 8),
              Expanded(child: _skeletonBox(height: 72)),
              const SizedBox(width: 8),
              Expanded(child: _skeletonBox(height: 72)),
            ],
          ),
          const SizedBox(height: 24),
          _skeletonBox(height: 52),
          const SizedBox(height: 32),
          _skeletonBox(height: 48, radius: 8),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 24),
                child: _skeletonBox(height: 16, width: 60),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _skeletonBox(height: 16, width: 100),
          const SizedBox(height: 16),
          ..._buildSkeletonTiles(),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildSkeletonTiles() {
    return List.generate(
      3,
      (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _skeletonBox(height: 12, width: 140),
                _skeletonBox(height: 12, width: 80),
              ],
            ),
            const SizedBox(height: 10),
            _skeletonBox(height: 14, width: 160),
            const SizedBox(height: 6),
            _skeletonBox(height: 12, width: 100),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({
    double? width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasReports = _reports.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? _buildSkeleton()
            : RefreshIndicator(
                color: Colors.grey.shade400,
                onRefresh: _loadReports,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Header =====
                      const Text(
                        'Reports',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ===== Summary Row =====
                      if (hasReports) ...[
                        Row(
                          children: [
                            _statBox(
                              'Total',
                              _reports.length.toString(),
                              textPrimary,
                            ),
                            const SizedBox(width: 8),
                            _statBox(
                              'Pending',
                              _reports
                                  .where(
                                      (r) => r['status'] == 'Pending')
                                  .length
                                  .toString(),
                              pendingDot,
                            ),
                            const SizedBox(width: 8),
                            _statBox(
                              'Resolved',
                              _reports
                                  .where(
                                      (r) => r['status'] == 'Resolved')
                                  .length
                                  .toString(),
                              resolvedDot,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ===== Report Button =====
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ReportIncidentScreen(),
                              ),
                            );
                            _loadReports();
                          },
                          child: const Text(
                            'REPORT A NEW INCIDENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ===== Empty State =====
                      // "What you can report" (Fraud, Phishing, etc.)
                      // has been removed from here — "How it works"
                      // is now the only content shown before reports
                      // exist.
                      if (!hasReports) ...[
                        const Text(
                          'How it works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _stepRow(
                          '01',
                          'Fill in the details',
                          'Select the incident type, date and a description of what happened.',
                        ),
                        _divider(),
                        _stepRow(
                          '02',
                          'Submit your report',
                          'Your report is submitted securely. A reference number is issued as confirmation.',
                        ),
                        _divider(),
                        _stepRow(
                          '03',
                          'Track your status',
                          'Monitor your report here. Updates reflect as Pending, Under Review or Resolved.',
                        ),

                        const SizedBox(height: 32),
                      ],

                      // ===== Reports List =====
                      if (hasReports) ...[
                        // ===== Search =====
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            style: const TextStyle(
                              fontSize: 15,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                              hintText: 'Search reports',
                              hintStyle: const TextStyle(
                                fontSize: 15,
                                color: Colors.black45,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.black45,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(
                                            () => _searchQuery = '');
                                      },
                                      child: const Icon(Icons.close,
                                          color: Colors.black45, size: 20),
                                    )
                                  : null,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== Filter Tabs =====
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filters.map((filter) {
                              final isSelected =
                                  _selectedFilter == filter;
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _selectedFilter = filter),
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      right: 24),
                                  child: Column(
                                    children: [
                                      Text(
                                        filter,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? primaryBlue
                                              : Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isSelected)
                                        Container(
                                          height: 3,
                                          width: 24,
                                          color: primaryBlue,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ===== My Reports Label =====
                        const Text(
                          'Reports History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_filteredReports.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: Text(
                                'No reports match your search.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textHelper,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._filteredReports.map(
                            (report) => _reportTile(report),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _reportTile(Map<String, String> report) {
    final status = report['status']!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportDetailPage(report: report, statuses: _statuses),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['ref']!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryBlue,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report['type']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(report['date']),
                      style: const TextStyle(
                          fontSize: 12, color: textHelper),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _dotColor(report),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFFCCCCCC),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: textHelper,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFFDDDDDD),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(color: Color(0xFFEEEEEE), height: 1);
  }

  Widget _reportTypeRow(String title, String description) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReportIncidentScreen(preselectedType: title),
          ),
        );
        _loadReports();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: textHelper,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _reportTypeDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF0F0F0),
      indent: 16,
    );
  }
}



class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = _controller.value;
            return LinearGradient(
              colors: const [
                Color(0xFFE3E3E3),
                Color(0xFFF6F6F6),
                Color(0xFFE3E3E3),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 3 * slide, 0),
              end: Alignment(1.0 + 3 * slide, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
