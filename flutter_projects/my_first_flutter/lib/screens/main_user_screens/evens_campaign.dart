import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/event_status.dart';
import '../../widgets/ended_badge.dart';
import '../../widgets/swipe_back.dart';
import '../loggedin_user_pages/event_detail.dart';

class EventsCampaignScreen extends StatefulWidget {
  const EventsCampaignScreen({super.key});

  @override
  State<EventsCampaignScreen> createState() => _EventsCampaignScreenState();
}

class _EventsCampaignScreenState extends State<EventsCampaignScreen> {
  static const Color primaryBlue = Color(0xFF00334D);

  int _activeCategoryIndex = 0;
  bool _isInitialLoad = true;
  final bool _isTabLoading = false;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _pressReleases = [];

  final List<String> categories = [
    'All',
    'Events',
    'Campaigns',
    'Press Releases',
  ];

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isInitialLoad = true;
    });

    final eventsResult = await ApiService.getEvents();
    final campaignsResult = await ApiService.getCampaigns();
    final pressResult = await ApiService.getPressReleases();

    if (eventsResult['success']) {
      final List events = eventsResult['data']['events'];
      setState(() {
        _events =
            events.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }

    if (campaignsResult['success']) {
      final List campaigns = campaignsResult['data']['campaigns'];
      setState(() {
        _campaigns =
            campaigns.map((c) => Map<String, dynamic>.from(c)).toList();
      });
    }

    if (pressResult['success']) {
      final List press = pressResult['data']['press_releases'];
      setState(() {
        _pressReleases =
            press.map((p) => Map<String, dynamic>.from(p)).toList();
      });
    }

    setState(() => _isInitialLoad = false);
  }

  String _getCountdown(Map<String, dynamic> item) {
    final dateStr = item['event_date'] ?? item['start_date'];
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

  List<Map<String, dynamic>> get _baseContent {
    switch (_activeCategoryIndex) {
      case 1:
        return _events;
      case 2:
        return _campaigns;
      case 3:
        return _pressReleases;
      default:
        return [..._events, ..._campaigns, ..._pressReleases];
    }
  }

  // Events and campaigns that are over. Press releases never end.
  bool _isEnded(Map<String, dynamic> item) {
    final bool isPressRelease = item.containsKey('body') &&
        !item.containsKey('event_date') &&
        !item.containsKey('start_date');
    if (isPressRelease) return false;
    final bool isCampaign =
        item.containsKey('start_date') && !item.containsKey('event_date');
    return isCampaign ? campaignHasEnded(item) : eventHasEnded(item);
  }

  List<Map<String, dynamic>> get _filteredContent {
    final List<Map<String, dynamic>> matches = _searchQuery.isEmpty
        ? _baseContent
        : _baseContent
            .where(
              (item) => (item['title'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()),
            )
            .toList();

    // Upcoming and ongoing first, ended ones after — each group keeps the
    // order the server sent.
    return [
      ...matches.where((item) => !_isEnded(item)),
      ...matches.where(_isEnded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Events and Campaigns',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: EdgeSwipeBack(
        child: _isInitialLoad
          ? _buildSkeleton()
          : RefreshIndicator(
              color: Colors.grey.shade400,
              onRefresh: _loadContent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ===== Search =====
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE4E6EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          hintText: 'Search events and campaigns',
                          hintStyle: const TextStyle(
                              color: Colors.black45, fontSize: 15),
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.black45, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Icon(Icons.close,
                                      color: Colors.black45,
                                      size: 20),
                                )
                              : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== Category Tabs =====
                    if (_searchQuery.isEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(
                              categories.length, (index) {
                            final isActive =
                                index == _activeCategoryIndex;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _activeCategoryIndex = index),
                              child: Container(
                                margin: const EdgeInsets.only(
                                    right: 24),
                                child: Column(
                                  children: [
                                    Text(
                                      categories[index],
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? primaryBlue
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (isActive)
                                      Container(
                                        height: 3,
                                        width: 24,
                                        color: primaryBlue,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ===== Search Results Label =====
                    if (_searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Results for "$_searchQuery"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                    // ===== Content =====
                    _filteredContent.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 48),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 48,
                                    color: Colors.black26,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No results found for "$_searchQuery"'
                                        : 'No ${categories[_activeCategoryIndex].toLowerCase()} available',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: _filteredContent
                                .map((item) => _eventTile(item))
                                .toList(),
                          ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return _Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar skeleton
            _skeletonBox(height: 52, radius: 12),
            const SizedBox(height: 24),
            // Tabs skeleton
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: _skeletonBox(height: 16, width: 70),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Event tiles skeleton
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
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            _skeletonBox(
              height: 180,
              radius: 0,
              topLeftRadius: 12,
              topRightRadius: 12,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(height: 12, width: 180),
                  const SizedBox(height: 10),
                  _skeletonBox(height: 18, width: double.infinity),
                  const SizedBox(height: 6),
                  _skeletonBox(height: 18, width: 240),
                  const SizedBox(height: 10),
                  _skeletonBox(height: 12, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({
    double? width,
    required double height,
    double radius = 6,
    double? topLeftRadius,
    double? topRightRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: topLeftRadius != null
            ? BorderRadius.only(
                topLeft: Radius.circular(topLeftRadius),
                topRight: Radius.circular(topRightRadius ?? 0),
              )
            : BorderRadius.circular(radius),
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> item) {
    final String title = item['title'] ?? '';
    final String? imageUrl = item['image'];
    final String date = item['event_date'] ??
        item['start_date'] ??
        item['date_published'] ??
        '';
    final String location = item['location'] ?? '';
    final String meta =
        location.isNotEmpty ? '$date  |  $location' : date;
    final bool ended = _isEnded(item);
    final String countdown = ended ? '' : _getCountdown(item);
    final bool isCampaign = item.containsKey('start_date') &&
        !item.containsKey('event_date');
    final bool isPressRelease = item.containsKey('body') &&
        !item.containsKey('event_date') &&
        !item.containsKey('start_date');
    final String categoryDisplay = item['category_display'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailPage(event: item, isCampaign: isCampaign),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: double.infinity,
                        height: 180,
                        color: const Color(0xFFE4E6EB),
                        child: const Icon(
                          Icons.event_outlined,
                          color: Colors.black26,
                          size: 50,
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 180,
                      color: const Color(0xFFE4E6EB),
                      child: const Icon(
                        Icons.event_outlined,
                        color: Colors.black26,
                        size: 50,
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      if (meta.isNotEmpty)
                        Expanded(
                          child: Text(
                            meta,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      if (ended)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: EndedBadge(),
                        ),
                      if (countdown.isNotEmpty && !isPressRelease)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: countdown == 'Past event'
                                ? Colors.grey.shade200
                                : countdown == 'Today'
                                    ? Colors.green.shade50
                                    : primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            countdown,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: countdown == 'Past event'
                                  ? Colors.black45
                                  : countdown == 'Today'
                                      ? Colors.green.shade700
                                      : primaryBlue,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.black38,
                        size: 16,
                      ),
                    ],
                  ),

                  if (categoryDisplay.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      categoryDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SHIMMER — sweeps a soft light band across whatever's inside it,
// on a loop. Same widget used on the logged-in dashboard skeletons.
// ============================================================

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