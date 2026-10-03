import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../services/bookmark_service.dart';
import '../../widgets/registered_pill.dart';
import '../../widgets/swipe_back.dart';
import '../../utils/event_status.dart';
import '../../widgets/top_toast.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final bool isCampaign;

  const EventDetailPage({
    super.key,
    required this.event,
    this.isCampaign = false,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  static const Color primaryBlue = Color(0xFF00334D);
  bool _interested = false;
  bool _isRegistering = false;
  bool _isCheckingRegistration = true;

  // True once the event is over: registering, unregistering and adding it
  // to a calendar are switched off. Starts from the data this page was
  // opened with; the server's answer (below) can only confirm or tighten it.
  late bool _hasEnded;

  // ===== Check-in code state =====
  String? _checkInCode;
  bool _checkedIn = false;

  bool _isBookmarked = false;

  // This page is reused by the logged-out "guest" browsing flow (see
  // main_user_screens/evens_campaign.dart), which has nowhere to
  // surface a saved bookmark — there's no Bookmarks page reachable
  // without an account. So bookmarking is only offered once a user is
  // actually logged in.
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    // Campaigns can be opened on this page too (guest browsing flow).
    _hasEnded = widget.isCampaign
        ? campaignHasEnded(widget.event)
        : eventHasEnded(widget.event);
    _checkRegistration();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (!mounted) return;
    setState(() => _isLoggedIn = accessToken != null);
    if (accessToken != null) _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    final isBookmarked = await BookmarkService.isBookmarked(
      'event',
      widget.event['id'].toString(),
    );
    if (!mounted) return;
    setState(() => _isBookmarked = isBookmarked);
  }

  Future<void> _toggleBookmark() async {
    final nowBookmarked = await BookmarkService.toggle('event', widget.event);
    if (!mounted) return;
    setState(() => _isBookmarked = nowBookmarked);
    showTopToast(
      context,
      nowBookmarked ? 'Event bookmarked' : 'Bookmark removed',
      isError: false,
      backgroundColor: nowBookmarked ? null : Colors.black54,
      icon: nowBookmarked ? null : Icons.info_outline,
    );
  }

  void _shareEvent() {
    final String title = widget.event['title'] ?? '';
    final id = widget.event['id'];
    final path = widget.isCampaign ? 'campaigns' : 'events';
    Share.share('$title\n\n${ApiService.publicWebBaseUrl}/$path/$id/');
  }

  Future<void> _checkRegistration() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null) {
      setState(() => _isCheckingRegistration = false);
      return;
    }

    final eventId = widget.event['id'];
    if (eventId == null) {
      setState(() => _isCheckingRegistration = false);
      return;
    }

    final result = await ApiService.checkEventRegistration(
      accessToken: accessToken,
      eventId: eventId,
    );

    if (result['success']) {
      setState(() {
        _interested = result['data']['registered'] ?? false;
        _checkInCode = result['data']['check_in_code'];
        _checkedIn = result['data']['checked_in'] ?? false;
        if (result['data']['has_ended'] == true) _hasEnded = true;
      });
    }

    setState(() => _isCheckingRegistration = false);
  }

  Future<void> _toggleRegistration() async {
    if (_hasEnded) {
      showTopToast(context, 'This event has ended');
      return;
    }

    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken == null) {
      showTopToast(context, 'Please login to register interest');
      return;
    }

    final eventId = widget.event['id'];
    if (eventId == null) return;

    setState(() => _isRegistering = true);

    if (_interested) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero),
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
                      color: Colors.red,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        setState(() => _isRegistering = false);
        return;
      }

      final result = await ApiService.unregisterEventInterest(
        accessToken: accessToken,
        eventId: eventId,
      );

      if (result['success']) {
        setState(() {
          _interested = false;
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
      final result = await ApiService.registerEventInterest(
        accessToken: accessToken,
        eventId: eventId,
      );

      if (result['success']) {
        final String? newCode = result['data']['check_in_code'];
        setState(() {
          _interested = true;
          _checkInCode = newCode;
          _checkedIn = result['data']['checked_in'] ?? false;
        });
        if (!context.mounted) return;

        // Show the full confirmation screen with the check-in code
        // instead of just a snackbar.
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
    final String title = widget.event['title'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        // Without this, Material 3 tints elevated surfaces with the
        // theme's primary color by default — this dialog was reading
        // as light blue/purple even though nothing here sets a blue
        // background directly.
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 32),
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
                // Explicit neutral ripple — otherwise Material uses
                // the theme's default (blue-tinted) splash color.
                splashColor: Colors.black.withValues(alpha: 0.06),
                highlightColor: Colors.black.withValues(alpha: 0.04),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  showTopToast(context, 'Code copied', isError: false);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 16),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
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

  String _getCountdown() {
    final dateStr =
        widget.event['event_date'] ?? widget.event['start_date'];
    if (dateStr == null) return '';
    try {
      final eventDate = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = eventDate.difference(now).inDays;
      if (diff > 0) return '$diff days to go';
      if (diff == 0) return 'Today';
      return 'Past event';
    } catch (e) {
      return '';
    }
  }

  void _addToCalendar() {
    if (kIsWeb) {
      showTopToast(
        context,
        'Adding to your calendar is only available in the mobile app',
        isError: false,
        backgroundColor: Colors.black54,
        icon: Icons.info_outline,
      );
      return;
    }
    final title = widget.event['title'] ?? '';
    final description = widget.event['description'] ?? '';
    final location = widget.event['location'] ?? '';
    final dateStr =
        widget.event['event_date'] ?? widget.event['start_date'];

    DateTime startDate;
    DateTime endDate;

    try {
      startDate = DateTime.parse(dateStr);
      endDate = startDate.add(const Duration(hours: 2));
    } catch (_) {
      startDate = DateTime.now().add(const Duration(days: 1));
      endDate = startDate.add(const Duration(hours: 2));
    }

    final Event calendarEvent = Event(
      title: title,
      description: description,
      location: location,
      startDate: startDate,
      endDate: endDate,
    );

    Add2Calendar.addEvent2Cal(calendarEvent);
  }

  Future<void> _openLocation(String location) async {
    // Prefer the exact pin (set by staff on the map in the admin
    // console) — opens the maps app right on that spot. Fall back to a
    // text search of the typed address when there's no pin.
    final lat = widget.event['latitude'];
    final lng = widget.event['longitude'];
    final String query = (lat != null && lng != null)
        ? '$lat,$lng'
        : location;
    if (query.trim().isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.event['title'] ?? '';
    final String description = widget.event['description'] ?? '';
    final String? imageUrl = widget.event['image'];
    final String date = widget.event['event_date'] ??
        widget.event['start_date'] ??
        '';
    final String endDate = widget.event['end_date'] ?? '';
    final String startTime = widget.event['start_time'] ?? '';
    final String endTime = widget.event['end_time'] ?? '';
    final String location = widget.event['location'] ?? '';
    final String audience = widget.event['target_audience'] ?? '';
    final String countdown = _getCountdown();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Stack(
        children: [
          SwipeBack(
            child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
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
              if (_isLoggedIn) ...[
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
              ],
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: _floatingIconButton(
                    icon: Icons.share_outlined,
                    onTap: _shareEvent,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) =>
                                  Container(color: primaryBlue),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // "Registered" / "Checked In" chip sits in the
                        // bottom-right corner of the image.
                        if (!_isCheckingRegistration && _interested)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: RegisteredPill(checkedIn: _checkedIn),
                          ),
                      ],
                    )
                  : Container(color: primaryBlue),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Countdown badge =====
                  if (countdown.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: countdown == 'Past event'
                            ? Colors.grey.shade200
                            : primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        countdown,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: countdown == 'Past event'
                              ? Colors.black45
                              : primaryBlue,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ===== Title =====
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),

                  // Location now lives only in the details card below —
                  // and the "Registered" chip sits on the image itself.

                  // ===== Saved check-in code (shown inline when
                  // reopening an event you're already registered for) =====
                  if (!_isCheckingRegistration &&
                      _interested &&
                      _checkInCode != null) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _showCheckInCodeDialog(_checkInCode!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFE4E6EB)),
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
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                  ],

                  const SizedBox(height: 24),

                  // ===== About =====
                  const Text(
                    'About this Event',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== Event facts — one card, monochrome =====
                  _detailsCard(
                    location: location,
                    date: date,
                    endDate: endDate,
                    startTime: startTime,
                    endTime: endTime,
                    audience: audience,
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _registerFooter(),
          ),
        ],
      ),
    );
  }

  // Pinned over the scrollable content (not pushed above it), so it
  // stays visible however far the user scrolls up or down. Wrapped in
  // SafeArea (bottom only — top is handled by the SliverAppBar above)
  // so the button sits above the phone's own gesture/nav bar instead
  // of being drawn underneath it on edge-to-edge Android devices.
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
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            elevation: _hasEnded ? 0 : 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed:
              (_isRegistering || _hasEnded) ? null : _toggleRegistration,
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
                  _hasEnded
                      ? 'EVENT HAS ENDED'
                      : (_interested ? 'UNREGISTER' : 'REGISTER FOR EVENT'),
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

  // One card holding every event fact — location, date/time, and the
  // Add to Calendar action — instead of separate cards per row. Icons
  // and text are plain black/grey throughout, no navy tint.
  Widget _detailsCard({
    required String location,
    required String date,
    required String endDate,
    required String startTime,
    required String endTime,
    required String audience,
  }) {
    final List<Widget> rows = [];

    if (_hasEnded) {
      rows.add(_infoRow(
        icon: Icons.event_busy,
        label: 'Status',
        value: 'This event has ended',
      ));
    } else {
      rows.add(_infoRow(
        icon: Icons.event_available,
        label: 'Add to Calendar',
        value: null,
        onTap: _addToCalendar,
        isAction: true,
      ));
    }

    if (location.isNotEmpty) {
      rows.add(_infoRow(
        icon: Icons.location_on,
        label: 'Location',
        value: location,
        onTap: () => _openLocation(location),
      ));
    }

    if (date.isNotEmpty) {
      rows.add(_infoRow(
        icon: Icons.calendar_today,
        label: 'Date',
        value: endDate.isNotEmpty ? '$date — $endDate' : date,
      ));
    }

    if (startTime.isNotEmpty) {
      rows.add(_infoRow(
        icon: Icons.access_time_filled,
        label: 'Time',
        value: endTime.isNotEmpty ? '$startTime – $endTime' : startTime,
      ));
    }

    // No speaker field exists on the Event backend model yet — left
    // out rather than shown with a fabricated value. Add
    // `speaker_name` to Event if this should appear here for real.
    if (audience.isNotEmpty) {
      rows.add(_infoRow(
        icon: Icons.people,
        label: 'Audience',
        value: audience,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E6EB)),
          ],
        ],
      ),
    );
  }

  // Plain black icon, no badge/glow — matches the flat icon treatment
  // used on the Campaign/NCSAM detail page.
  Widget _glassIconBadge(IconData icon) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Icon(icon, size: 20, color: Colors.black87),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
    bool isAction = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: Row(
            crossAxisAlignment: isAction
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
            _glassIconBadge(icon),
            const SizedBox(width: 12),
            Expanded(
              child: isAction
                  ? Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}