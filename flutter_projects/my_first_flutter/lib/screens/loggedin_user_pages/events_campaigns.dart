import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/event_status.dart';
import '../../services/bookmark_service.dart';
import '../../widgets/swipe_back.dart';
import 'bookmarks_page.dart';
import 'campaign_article_detail.dart';
import 'campaign_details.dart';
import 'event_detail.dart';
import 'press_release_detail.dart';

class LoggedInEventsCampaigns extends StatefulWidget {
  const LoggedInEventsCampaigns({super.key});

  @override
  State<LoggedInEventsCampaigns> createState() =>
      _LoggedInEventsCampaignsState();
}

class _LoggedInEventsCampaignsState
    extends State<LoggedInEventsCampaigns> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  int _activeCategoryIndex = 0;
  bool _isInitialLoad = true;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _pressReleases = [];

  Set<String> _bookmarkedEventIds = {};
  Set<String> _bookmarkedCampaignIds = {};
  Set<String> _bookmarkedPressReleaseIds = {};

  final List<String> categories = [
    'All',
    'Events',
    'NCSAM',
    'Campaigns',
    'Press Releases',
  ];

  @override
  void initState() {
    super.initState();
    _loadContent();
    _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    final events = await BookmarkService.loadIds('event');
    final campaigns = await BookmarkService.loadIds('campaign');
    final pressReleases = await BookmarkService.loadIds('press_release');
    if (!mounted) return;
    setState(() {
      _bookmarkedEventIds = events;
      _bookmarkedCampaignIds = campaigns;
      _bookmarkedPressReleaseIds = pressReleases;
    });
  }

  String _typeOf(Map<String, dynamic> item) {
    final bool isPressRelease = item.containsKey('body') &&
        !item.containsKey('event_date') &&
        !item.containsKey('start_date');
    final bool isCampaign = item.containsKey('start_date') &&
        !item.containsKey('event_date');
    if (isPressRelease) return 'press_release';
    if (isCampaign) return 'campaign';
    return 'event';
  }

  bool _isBookmarked(Map<String, dynamic> item) {
    final id = item['id'].toString();
    switch (_typeOf(item)) {
      case 'campaign':
        return _bookmarkedCampaignIds.contains(id);
      case 'press_release':
        return _bookmarkedPressReleaseIds.contains(id);
      default:
        return _bookmarkedEventIds.contains(id);
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> item) async {
    final type = _typeOf(item);
    final nowBookmarked = await BookmarkService.toggle(type, item);
    final id = item['id'].toString();
    if (!mounted) return;
    setState(() {
      final set = switch (type) {
        'campaign' => _bookmarkedCampaignIds,
        'press_release' => _bookmarkedPressReleaseIds,
        _ => _bookmarkedEventIds,
      };
      if (nowBookmarked) {
        set.add(id);
      } else {
        set.remove(id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _isInitialLoad = true);

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
        _campaigns = campaigns
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
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

  // ===== Fixed countdown using DateTime.parse() =====
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
      case 0:
        return [..._events, ..._campaigns, ..._pressReleases];
      case 1:
        return _events;
      case 2:
        return _campaigns
            .where((c) => c['category'] == 'NCSAM')
            .toList();
      case 3:
        return _campaigns;
      case 4:
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

  // NCSAM doesn't have its own backend model — it's the one Campaign
  // record tagged category 'NCSAM' (there's only ever one "current"
  // flagship campaign at a time). It filters into the list like any
  // other tab; tapping the resulting card opens the tabbed detail page.
  void _navigateToDetail(Map<String, dynamic> item) {
    final bool isCampaign = item.containsKey('start_date') &&
        !item.containsKey('event_date');
    final bool isPressRelease = item.containsKey('body') &&
        !item.containsKey('event_date') &&
        !item.containsKey('start_date');
    final String category = item['category'] ?? '';

    if (isPressRelease) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PressReleaseDetailPage(pressRelease: item),
        ),
      );
    } else if (isCampaign) {
      if (category == 'NCSAM') {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CampaignDetailPage(campaign: item)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CampaignArticleDetailPage(campaign: item),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EventDetailPage(event: item, isCampaign: false),
        ),
      );
    }
  }

  // ===== Skeleton =====
  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(height: 28, width: 280),
          const SizedBox(height: 24),
          _skeletonBox(height: 48, radius: 50),
          const SizedBox(height: 24),
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
          ..._buildSkeletonTiles(),
        ],
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  _skeletonBox(height: 12, width: 80),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Events and Campaigns',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline,
                color: Colors.black, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BookmarksPage(
                  initialFilter: 'Events & Campaigns',
                ),
              ),
            ),
          ),
        ],
      ),
      body: EdgeSwipeBack(
        child: _isInitialLoad
          ? _buildSkeleton()
          : RefreshIndicator(
              color: Colors.grey.shade400,
              onRefresh: _loadContent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    

                    // ===== Search =====
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                                      color: Colors.black45, size: 20),
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
                                margin:
                                    const EdgeInsets.only(right: 24),
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
                                    const SizedBox(height: 4),
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

                    _filteredContent.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 48),
                              child: Column(
                                children: [
                                  const Icon(Icons.event_outlined,
                                      size: 48, color: Colors.black26),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No results found for "$_searchQuery"'
                                        : categories[_activeCategoryIndex] ==
                                                'NCSAM'
                                            ? 'NCSAM content not published yet'
                                            : 'No ${categories[_activeCategoryIndex].toLowerCase()} available',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black45),
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

  Widget _eventTile(Map<String, dynamic> item) {
    final String title = item['title'] ?? '';
    final String? imageUrl = item['image'];
    final String date = item['event_date'] ??
        item['start_date'] ??
        item['date_published'] ??
        '';
    // Only the "from" time shows here — the "to" time is only shown
    // once the user opens the full event. Campaigns/press releases
    // have no time field at all, so this is null for those.
    final String? startTime = item['start_time'];
    final String dateDisplay =
        startTime != null && startTime.isNotEmpty
            ? '$date · $startTime'
            : date;
    // Town-level location for the list view. This is the same
    // `location` field the detail page shows in full — there's no
    // separate short/exact pair of fields from the backend yet.
    final String location = item['location'] ?? '';
    final bool ended = _isEnded(item);
    final String countdown = ended ? '' : _getCountdown(item);
    final bool isPressRelease = item.containsKey('body') &&
        !item.containsKey('event_date') &&
        !item.containsKey('start_date');
    final String categoryDisplay = item['category_display'] ?? '';
    final bool bookmarked = _isBookmarked(item);

    String typeLabel = '';
    if (isPressRelease) {
      typeLabel = 'Press Release';
    } else if (item.containsKey('start_date') &&
        !item.containsKey('event_date')) {
      typeLabel =
          categoryDisplay.isNotEmpty ? categoryDisplay : 'Campaign';
    } else {
      typeLabel = 'Event';
    }

    return GestureDetector(
      onTap: () => _navigateToDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
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
                          errorBuilder:
                              (context, error, stackTrace) => Container(
                            width: double.infinity,
                            height: 180,
                            color: const Color(0xFFE4E6EB),
                            child: const Icon(Icons.event_outlined,
                                color: Colors.black26, size: 50),
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          height: 180,
                          color: const Color(0xFFE4E6EB),
                          child: const Icon(Icons.event_outlined,
                              color: Colors.black26, size: 50),
                        ),
                ),

                if (countdown.isNotEmpty && !isPressRelease)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        countdown,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top: 12,
                  right: 12,
                  child: _glassBookmarkButton(
                    bookmarked: bookmarked,
                    onTap: () => _toggleBookmark(item),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ===== Date (+ from-time) and Location, one line —
                  // a small clock icon marks the time portion when
                  // there is one; a vertical rule separates date/time
                  // from location =====
                  Row(
                    children: [
                      if (date.isNotEmpty) ...[
                        if (startTime != null && startTime.isNotEmpty) ...[
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            dateDisplay,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (date.isNotEmpty && location.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 1,
                          height: 12,
                          color: const Color(0xFFD9DCE3),
                        ),
                      if (location.isNotEmpty)
                        Flexible(
                          child: Text(
                            location,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Text(
                    typeLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                      letterSpacing: 0.6,
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

  // Plain semi-transparent circle — same treatment as the back/share
  // buttons on the Event/Campaign detail pages' photo headers.
  // Previously a frosted-glass blur with a light border ring, which
  // read as an odd glow rather than a normal button.
  Widget _glassBookmarkButton({
    required bool bookmarked,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: bookmarked ? primaryBlue : Colors.white,
          size: 16,
        ),
        onPressed: onTap,
      ),
    );
  }
}