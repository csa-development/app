import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/bookmark_service.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';

class CampaignDetailPage extends StatefulWidget {
  final Map<String, dynamic> campaign;

  const CampaignDetailPage({super.key, required this.campaign});

  @override
  State<CampaignDetailPage> createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage>
    with SingleTickerProviderStateMixin {
  static const Color primaryBlue = Color(0xFF00334D);

  late TabController _tabController;
  bool _isLoading = true;
  bool _isBookmarked = false;
  Map<String, dynamic> _detail = {};

  // ===== Registration / ticket state =====
  bool _registered = false;
  bool _isRegistering = false;
  bool _isCheckingRegistration = true;
  String? _checkInCode;
  bool _checkedIn = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetail();
    _loadBookmarkState();
    _checkRegistration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarkState() async {
    final isBookmarked = await BookmarkService.isBookmarked(
      'campaign',
      widget.campaign['id'].toString(),
    );
    if (!mounted) return;
    setState(() => _isBookmarked = isBookmarked);
  }

  Future<void> _toggleBookmark() async {
    final nowBookmarked =
        await BookmarkService.toggle('campaign', widget.campaign);
    if (!mounted) return;
    setState(() => _isBookmarked = nowBookmarked);
    showTopToast(
      context,
      nowBookmarked ? 'Campaign bookmarked' : 'Bookmark removed',
      isError: false,
      backgroundColor: nowBookmarked ? null : Colors.black54,
      icon: nowBookmarked ? null : Icons.info_outline,
    );
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getCampaignDetail(
      campaignId: widget.campaign['id'],
    );
    if (result['success']) {
      setState(() {
        _detail = Map<String, dynamic>.from(result['data']['campaign']);
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _shareCampaign() {
    final String title = widget.campaign['title'] ?? '';
    Share.share('$title\n\nFind out more on the CSA App');
  }

  // Registration stays open until the campaign's end date (or start
  // date, if it has no end date) has fully passed. Fails open (treats
  // the campaign as still open) if the date can't be parsed.
  bool get _hasEnded {
    final dateStr = _detail['end_date_iso'] ?? _detail['start_date_iso'];
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return DateTime.now().isAfter(date.add(const Duration(days: 1)));
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkRegistration() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null) {
      setState(() => _isCheckingRegistration = false);
      return;
    }

    final campaignId = widget.campaign['id'];
    if (campaignId == null) {
      setState(() => _isCheckingRegistration = false);
      return;
    }

    final result = await ApiService.checkCampaignRegistration(
      accessToken: accessToken,
      campaignId: campaignId,
    );

    if (result['success']) {
      setState(() {
        _registered = result['data']['registered'] ?? false;
        _checkInCode = result['data']['check_in_code'];
        _checkedIn = result['data']['checked_in'] ?? false;
      });
    }

    if (mounted) setState(() => _isCheckingRegistration = false);
  }

  Future<void> _toggleRegistration() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null) {
      showTopToast(context, 'Please login to register interest');
      return;
    }

    final campaignId = widget.campaign['id'];
    if (campaignId == null) return;

    setState(() => _isRegistering = true);

    if (_registered) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'Remove Registration',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Are you sure you want to remove your registration for this event?',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Colors.black45)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('REMOVE',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isRegistering = false);
        return;
      }

      final result = await ApiService.unregisterCampaignInterest(
        accessToken: accessToken,
        campaignId: campaignId,
      );

      if (result['success']) {
        setState(() {
          _registered = false;
          _checkInCode = null;
          _checkedIn = false;
        });
        if (!context.mounted) return;
        showTopToast(
          context,
          'Registration removed',
          isError: false,
          backgroundColor: Colors.black54,
          icon: Icons.info_outline,
        );
      } else {
        if (!context.mounted) return;
        showTopToast(
          context,
          result['error'] ?? 'Failed to remove registration',
        );
      }
    } else {
      final result = await ApiService.registerCampaignInterest(
        accessToken: accessToken,
        campaignId: campaignId,
      );

      if (result['success']) {
        final String? newCode = result['data']['check_in_code'];
        setState(() {
          _registered = true;
          _checkInCode = newCode;
          _checkedIn = result['data']['checked_in'] ?? false;
        });
        if (!context.mounted) return;

        if (newCode != null) {
          _showCheckInCodeDialog(newCode);
        } else {
          showTopToast(
            context,
            'Successfully registered interest',
            isError: false,
          );
        }
      } else {
        if (!context.mounted) return;
        showTopToast(
          context,
          result['error'] ?? 'Failed to register interest',
        );
      }
    }

    setState(() => _isRegistering = false);
  }

  void _showCheckInCodeDialog(String code) {
    final String title = widget.campaign['title'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'REGISTRATION SUCCESSFUL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re registered for $title',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CHECK-IN CODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                splashColor: Colors.black.withValues(alpha: 0.06),
                highlightColor: Colors.black.withValues(alpha: 0.04),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showTopToast(context, 'Code copied', isError: false);
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE4E6EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryBlue,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.copy_outlined,
                          size: 18, color: Colors.black45),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Present this code at the reception desk when you arrive. '
                'A copy has also been sent to your email.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wrapped in SafeArea (bottom only) so the button sits above the
  // phone's own gesture/nav bar instead of being drawn underneath it
  // on edge-to-edge Android devices.
  Widget _registerFooter() {
    return SafeArea(
      top: false,
      child: Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF8F9FB).withValues(alpha: 0),
            const Color(0xFFF8F9FB),
          ],
          stops: const [0, 0.35],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: _isRegistering ? null : _toggleRegistration,
          child: _isRegistering
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _registered ? 'UNREGISTER' : 'REGISTER FOR EVENT',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
      ),
    );
  }

  Widget _registeredPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _checkedIn ? Icons.verified : Icons.check_circle,
            size: 14,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            _checkedIn ? 'Checked In' : 'Registered',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Title moved into _overviewTab() (reads its own copy from
    // widget.campaign) — no longer needed here in the image header.
    final String? imageUrl = widget.campaign['image'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: EdgeSwipeBack(
        child: _isLoading
          ? _buildSkeleton()
          : Stack(
              children: [
                NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: primaryBlue,
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: Center(
                    child: _floatingIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  actions: [
                    Center(
                      child: _floatingIconButton(
                        icon: _isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        iconColor: _isBookmarked ? primaryBlue : Colors.white,
                        onTap: _toggleBookmark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(
                        child: _floatingIconButton(
                          icon: Icons.share_outlined,
                          onTap: _shareCampaign,
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(color: primaryBlue),
                              )
                            : Container(color: primaryBlue),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),

                        // "Registered" / "Checked In" chip, bottom-right
                        // of the image — raised above the TabBar (which
                        // is pinned to the very bottom of this same
                        // expanded area) so it no longer sits on top of
                        // the Speakers/Gallery tab labels.
                        if (!_isCheckingRegistration && _registered)
                          Positioned(
                            right: 16,
                            bottom: 52,
                            child: _registeredPill(),
                          ),

                        // Category badge only here now — the title
                        // itself moved into the Overview tab (see
                        // _overviewTab), so it reads as page content
                        // instead of being overlaid on the image.
                        if ((_detail['category_display'] ?? '').isNotEmpty)
                          Positioned(
                            bottom: 60,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _detail['category_display'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Schedule'),
                      Tab(text: 'Speakers'),
                      Tab(text: 'Gallery'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _wrapWithRefresh(_overviewTab()),
                  _wrapWithRefresh(_scheduleTab()),
                  _wrapWithRefresh(_speakersTab()),
                  _wrapWithRefresh(_galleryTab()),
                ],
              ),
            ),
                if (!_isCheckingRegistration && !_hasEnded)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _registerFooter(),
                  ),
              ],
            ),
      ),
    );
  }

  Widget _wrapWithRefresh(Widget child) {
    return RefreshIndicator(
      color: Colors.grey.shade400,
      onRefresh: _loadDetail,
      child: child,
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _skeletonBox(height: 260, radius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(height: 14, width: 100),
                const SizedBox(height: 12),
                _skeletonBox(height: 24, width: double.infinity),
                const SizedBox(height: 24),
                _skeletonBox(height: 16, width: double.infinity),
                const SizedBox(height: 10),
                _skeletonBox(height: 16, width: double.infinity),
                const SizedBox(height: 10),
                _skeletonBox(height: 16, width: 220),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBox({double? width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Future<void> _openLocation() async {
    final lat = _detail['latitude'];
    final lng = _detail['longitude'];
    final String location = _detail['location'] ?? '';
    final String query = (lat != null && lng != null) ? '$lat,$lng' : location;
    if (query.trim().isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _overviewTab() {
    final String title = widget.campaign['title'] ?? '';
    final String description = _detail['description'] ?? '';
    final String targetAudience = _detail['target_audience'] ?? '';
    final String location = _detail['location'] ?? '';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (location.isNotEmpty) ...[
            GestureDetector(
              onTap: _openLocation,
              child: _infoRow(Icons.location_on_outlined, 'Venue', location),
            ),
            const SizedBox(height: 12),
          ],
          if (targetAudience.isNotEmpty) ...[
            _infoRow(Icons.people_outline, 'Target Audience', targetAudience),
            const SizedBox(height: 12),
          ],
          // ===== Saved check-in code (shown inline when reopening a
          // campaign you're already registered for) =====
          if (!_isCheckingRegistration &&
              _registered &&
              _checkInCode != null) ...[
            GestureDetector(
              onTap: () => _showCheckInCodeDialog(_checkInCode!),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E6EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _checkedIn
                          ? Icons.verified_outlined
                          : Icons.qr_code_2_outlined,
                      color: Colors.black54,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHECK-IN CODE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _checkInCode!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.black45, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          const Text(
            'About This Event',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _scheduleTab() {
    final List schedule = List.from(_detail['schedule'] ?? []);
    final String startDate = _detail['start_date'] ?? '';
    final String endDate = _detail['end_date'] ?? '';
    final String dates =
        endDate.isNotEmpty ? '$startDate — $endDate' : startDate;
    final String location = _detail['location'] ?? '';

    if (schedule.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dates.isNotEmpty) ...[
              _infoRow(Icons.calendar_today_outlined, 'Dates', dates),
              const SizedBox(height: 12),
            ],
            if (location.isNotEmpty) ...[
              GestureDetector(
                onTap: _openLocation,
                child: _infoRow(
                    Icons.location_on_outlined, 'Location', location),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 260,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule_outlined,
                        size: 48, color: Colors.black26),
                    const SizedBox(height: 12),
                    const Text(
                      'No schedule available yet',
                      style:
                          TextStyle(fontSize: 14, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dates.isNotEmpty) ...[
            _infoRow(Icons.calendar_today_outlined, 'Dates', dates),
            const SizedBox(height: 12),
          ],
          if (location.isNotEmpty) ...[
            GestureDetector(
              onTap: _openLocation,
              child:
                  _infoRow(Icons.location_on_outlined, 'Location', location),
            ),
            const SizedBox(height: 16),
          ],
          ...schedule.map<Widget>((week) {
          final int weekNum = week['week'] ?? 1;
          final List sessions = List.from(week['sessions'] ?? []);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Week $weekNum',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              ...sessions.map<Widget>((session) => _sessionTile(session)),

              // ===== Spacing tightened: 20 -> 12 =====
              const SizedBox(height: 12),
            ],
          );
          }),
        ],
      ),
    );
  }

  // Backend sends session times as 24-hour "HH:MM"; render as 12-hour
  // with AM/PM for display.
  String _formatTime12Hour(String time24) {
    if (time24.isEmpty) return time24;
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    final int? hour = int.tryParse(parts[0]);
    final String minute = parts[1];
    if (hour == null) return time24;

    final String period = hour >= 12 ? 'PM' : 'AM';
    int hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return '$hour12:$minute $period';
  }

  Widget _sessionTile(Map session) {
    final String startTime = session['start_time'] ?? '';
    final String endTime = session['end_time'] ?? '';
    final String sessionTitle = session['session_title'] ?? '';
    final String speaker = session['speaker'] ?? '';
    final String venue = session['venue'] ?? '';
    final String day = session['day'] ?? '';
    final String? sessionDate = session['date'];
    final String timeRange = endTime.isNotEmpty
        ? '${_formatTime12Hour(startTime)} — ${_formatTime12Hour(endTime)}'
        : _formatTime12Hour(startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.isNotEmpty)
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontSize: 12,
                    color: primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                if (speaker.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    speaker,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (venue.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.black87),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          venue,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined,
                color: Colors.black87, size: 20),
            tooltip: 'Add session to calendar',
            onPressed: () => _addSessionToCalendar(
              title: sessionTitle,
              venue: venue,
              day: day,
              startTime: startTime,
              endTime: endTime,
              sessionDate: sessionDate,
            ),
          ),
        ],
      ),
    );
  }

  void _addSessionToCalendar({
    required String title,
    required String venue,
    required String day,
    required String startTime,
    required String endTime,
    String? sessionDate,
  }) {
    DateTime? start;

    if (sessionDate != null && sessionDate.isNotEmpty) {
      try {
        start = DateTime.parse(sessionDate);
      } catch (_) {
        start = null;
      }
    }

    if (start == null) {
      final campaignStart = _detail['start_date'];
      if (campaignStart != null) {
        try {
          start = DateTime.parse(campaignStart);
        } catch (_) {
          start = null;
        }
      }
    }

    if (start == null) {
      showTopToast(
        context,
        'A date isn\'t available for this session yet',
        isError: false,
        backgroundColor: Colors.black54,
        icon: Icons.info_outline,
      );
      return;
    }

    final startParts = _parseTimeOfDay(startTime);
    if (startParts != null) {
      start = DateTime(
          start.year, start.month, start.day, startParts.$1, startParts.$2);
    }

    DateTime end = start.add(const Duration(hours: 1));
    final endParts = _parseTimeOfDay(endTime);
    if (endParts != null) {
      end = DateTime(
          start.year, start.month, start.day, endParts.$1, endParts.$2);
    }

    final calendarEvent = Event(
      title: title,
      description: day.isNotEmpty ? 'Session day: $day' : '',
      location: venue,
      startDate: start,
      endDate: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
    );

    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  (int, int)? _parseTimeOfDay(String time) {
    if (time.isEmpty) return null;
    try {
      final cleaned = time.trim().toUpperCase();
      final isPm = cleaned.contains('PM');
      final isAm = cleaned.contains('AM');
      final digitsOnly =
          cleaned.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = digitsOnly.split(':');
      if (parts.length < 2) return null;
      int hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return (hour, minute);
    } catch (_) {
      return null;
    }
  }

  Widget _speakersTab() {
    final List speakers = List.from(_detail['speakers'] ?? []);

    if (speakers.isEmpty) {
      return _emptyState(Icons.person_outline, 'No speakers added yet');
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: speakers.map<Widget>((speaker) {
          final String name = speaker['name'] ?? '';
          final String title = speaker['title'] ?? '';
          final String organisation = speaker['organisation'] ?? '';
          final String bio = speaker['bio'] ?? '';
          final String? photo = speaker['photo'];

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4E6EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: photo != null
                      ? Image.network(
                          photo,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 60,
                            height: 60,
                            color: const Color(0xFFE8EEF8),
                            child: const Icon(Icons.person,
                                color: primaryBlue, size: 30),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: const Color(0xFFE8EEF8),
                          child: const Icon(Icons.person,
                              color: primaryBlue, size: 30),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (title.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (organisation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          organisation,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _galleryTab() {
    final List gallery = List.from(_detail['gallery'] ?? []);

    if (gallery.isEmpty) {
      return _emptyState(
          Icons.photo_library_outlined, 'No gallery images yet');
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: gallery.length,
      itemBuilder: (context, index) {
        final item = gallery[index];
        final String? imageUrl = item['image'];
        final String caption = item['caption'] ?? '';

        return GestureDetector(
          onTap: () => _showImageFullscreen(imageUrl, caption),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFE4E6EB),
                        child: const Icon(Icons.image_outlined,
                            color: Colors.black26, size: 40),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE4E6EB),
                      child: const Icon(Icons.image_outlined,
                          color: Colors.black26, size: 40),
                    ),
              if (caption.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showImageFullscreen(String? imageUrl, String caption) {
    if (imageUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: Image.network(imageUrl, fit: BoxFit.contain)),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 16,
                right: 16,
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor, size: 18),
        onPressed: onTap,
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 320,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.black26),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(fontSize: 14, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}