import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';
import 'bookmarks_page.dart';
import 'news_detail.dart';

class LoggedInNews extends StatefulWidget {
  const LoggedInNews({super.key});

  @override
  State<LoggedInNews> createState() => _LoggedInNewsState();
}

class _LoggedInNewsState extends State<LoggedInNews> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const int _loopMultiplier = 1000;

  int _activeCategoryIndex = 0;
  int _activeBreakingIndex = 0;
  bool _isInitialLoad = true;
  bool _isTabLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 1;
  String _searchQuery = '';

  PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _autoAdvanceTimer;
  Timer? _resumeTimer;

  List<Map<String, dynamic>> _allNews = [];
  List<Map<String, dynamic>> _breakingNews = [];
  List<String> _bookmarkedIds = [];

  final List<String> categories = [
    'All',
    'Alerts',
    'Advisories',
    'Notices',
    'CERT-GH',
  ];

  final List<String?> _categoryKeys = [
    null,
    'ALERT',
    'ADVISORY',
    'NOTICE',
    'NEWS',
  ];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadContent(initial: true);
    _loadBookmarks();

    // Instant refresh the moment a push arrives while this screen is
    // open (e.g. a new alert/advisory gets published).
    NotificationService.refreshSignal.addListener(_silentRefreshNews);

    // Baseline safety net independent of push delivery, same reasoning
    // as the Reports screen.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefreshNews(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _autoAdvanceTimer?.cancel();
    _resumeTimer?.cancel();
    NotificationService.refreshSignal.removeListener(_silentRefreshNews);
    _pollTimer?.cancel();
    super.dispose();
  }

  // Re-fetches just the current category's news list and swaps it in
  // place — no loading skeleton/shimmer, and deliberately doesn't
  // touch _breakingNews or _pageController. The breaking-news carousel
  // uses an infinite-loop trick (page index * 1000) to fake endless
  // scrolling; rebuilding it mid-refresh would jump the user's
  // scroll position, which would be a worse interruption than the
  // stale-data problem this is meant to fix.
  Future<void> _silentRefreshNews() async {
    final newsResult = await ApiService.getNews(
      page: 1,
      pageSize: 10,
      category: _currentCategory,
    );
    if (!mounted) return;
    if (newsResult['success']) {
      final List news = newsResult['data']['news'];
      final bool hasMore = newsResult['data']['has_more'] ?? false;
      setState(() {
        _allNews = news.map((n) => Map<String, dynamic>.from(n)).toList();
        _hasMore = hasMore;
        _currentPage = 1;
      });
    }
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarked_articles') ?? [];
    setState(() => _bookmarkedIds = saved);
  }

  Future<void> _toggleBookmark(Map<String, dynamic> article) async {
    final prefs = await SharedPreferences.getInstance();
    final id = article['id'].toString();
    List<String> saved = prefs.getStringList('bookmarked_articles') ?? [];
    List<String> savedData =
        prefs.getStringList('bookmarked_articles_data') ?? [];

    if (saved.contains(id)) {
      saved.remove(id);
      savedData.removeWhere((s) {
        final decoded = jsonDecode(s);
        return decoded['id'].toString() == id;
      });
      if (mounted) {
        showTopToast(
          context,
          'Bookmark removed',
          isError: false,
          backgroundColor: Colors.black54,
          icon: Icons.info_outline,
        );
      }
    } else {
      saved.add(id);
      savedData.add(jsonEncode(article));
      if (mounted) {
        showTopToast(context, 'Article bookmarked', isError: false);
      }
    }

    await prefs.setStringList('bookmarked_articles', saved);
    await prefs.setStringList('bookmarked_articles_data', savedData);
    setState(() => _bookmarkedIds = saved);
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_breakingNews.isEmpty) return;
    _autoAdvanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_pageController.hasClients) return;
        final nextPage = (_pageController.page?.round() ?? 0) + 1;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  void _pauseAndResumeAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 6), () {
      _startAutoAdvance();
    });
  }

  String? get _currentCategory => _categoryKeys[_activeCategoryIndex];

  Future<void> _loadContent({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isInitialLoad = true;
        _currentPage = 1;
        _allNews = [];
      });
    } else {
      setState(() {
        _isTabLoading = true;
        _currentPage = 1;
        _allNews = [];
      });
    }

    final newsResult = await ApiService.getNews(
      page: 1,
      pageSize: 10,
      category: _currentCategory,
    );

    if (initial) {
      final breakingResult = await ApiService.getBreakingNews();
      if (breakingResult['success']) {
        final List breaking = breakingResult['data']['breaking_news'];
        setState(() {
          _breakingNews =
              breaking.map((n) => Map<String, dynamic>.from(n)).toList();
        });
      }
    }

    if (newsResult['success']) {
      final List news = newsResult['data']['news'];
      final bool hasMore = newsResult['data']['has_more'] ?? false;
      setState(() {
        _allNews = news.map((n) => Map<String, dynamic>.from(n)).toList();
        _hasMore = hasMore;
        _currentPage = 1;
      });
    }

    if (initial && _breakingNews.isNotEmpty) {
      final middleStart = (_loopMultiplier ~/ 2) * _breakingNews.length;
      // Dispose the old controller before replacing it — without
      // this, every pull-to-refresh created a brand new
      // PageController and just abandoned the previous one,
      // leaking one controller per refresh.
      _pageController.dispose();
      _pageController = PageController(initialPage: middleStart);
      setState(() => _activeBreakingIndex = 0);
      _startAutoAdvance();
    }

    setState(() {
      _isInitialLoad = false;
      _isTabLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final newsResult = await ApiService.getNews(
      page: nextPage,
      pageSize: 10,
      category: _currentCategory,
    );

    if (newsResult['success']) {
      final List news = newsResult['data']['news'];
      final bool hasMore = newsResult['data']['has_more'] ?? false;
      setState(() {
        _allNews.addAll(
            news.map((n) => Map<String, dynamic>.from(n)).toList());
        _hasMore = hasMore;
        _currentPage = nextPage;
      });
    }

    setState(() => _isLoadingMore = false);
  }

  String _relativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else {
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    } catch (_) {
      return dateStr ?? '';
    }
  }

  bool _matchesSearch(Map<String, dynamic> n) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    final title = (n['title'] ?? '').toString().toLowerCase();
    final category = (n['category_display'] ?? '').toString().toLowerCase();
    final date = (n['date_published'] ?? '').toString().toLowerCase();
    final body = (n['body'] ?? '').toString().toLowerCase();
    return title.contains(query) ||
        category.contains(query) ||
        date.contains(query) ||
        body.contains(query);
  }

  // Matches the selected tab so "Advisories" with nothing in it says
  // "No advisories", not a generic message that talks about every
  // category regardless of which one is actually empty.
  String _emptyStateMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No results found for "$_searchQuery"';
    }
    switch (categories[_activeCategoryIndex]) {
      case 'Alerts':
        return 'No alerts yet';
      case 'Advisories':
        return 'No advisories yet';
      case 'Notices':
        return 'No notices yet';
      case 'CERT-GH':
        return 'No CERT-GH updates yet';
      default:
        return 'No news or advisories yet';
    }
  }

  Widget _buildSkeleton() {
    return _Shimmer(
      child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBox(height: 52, radius: 12),
          const SizedBox(height: 24),
          _skeletonBox(height: 16, width: 120),
          const SizedBox(height: 14),
          _skeletonBox(height: 200, radius: 8),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                6,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: _skeletonBox(height: 16, width: 60),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSkeletonList(),
        ],
      ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E6EB)),
          ),
          child: Row(
            children: [
              _skeletonBox(
                width: 92,
                height: 92,
                radius: 0,
                topLeftRadius: 8,
                bottomLeftRadius: 8,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeletonBox(height: 10, width: 60),
                      const SizedBox(height: 8),
                      _skeletonBox(height: 14, width: double.infinity),
                      const SizedBox(height: 4),
                      _skeletonBox(height: 14, width: 180),
                      const SizedBox(height: 8),
                      _skeletonBox(height: 10, width: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skeletonBox({
    double? width,
    required double height,
    double radius = 6,
    double? topLeftRadius,
    double? bottomLeftRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: topLeftRadius != null
            ? BorderRadius.only(
                topLeft: Radius.circular(topLeftRadius),
                bottomLeft: Radius.circular(bottomLeftRadius ?? 0),
              )
            : BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: EdgeSwipeBack(
        child: SafeArea(
        child: _isInitialLoad
            ? _buildSkeleton()
            : RefreshIndicator(
                color: Colors.grey.shade400,
                onRefresh: () => _loadContent(initial: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Header =====
                      // Matches the Reports screen's heading style —
                      // plain large left-aligned text, no AppBar.
                      // Only shown when this screen was pushed on top
                      // of something (e.g. from Home's Quick Actions)
                      // rather than reached as the bottom-nav tab —
                      // that's the only case with no bottom nav bar
                      // visible to get back with otherwise.
                      if (Navigator.canPop(context)) ...[
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F6F9),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'News and Advisories',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BookmarksPage(
                                  initialFilter: 'News',
                                ),
                              ),
                            ),
                            child: const Icon(
                              Icons.bookmark_outline,
                              color: primaryBlue,
                              size: 26,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

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
                            hintText: 'Search news and advisories',
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

                      // ===== Breaking News =====
                      if (_breakingNews.isNotEmpty &&
                          _searchQuery.isEmpty) ...[
                        const Text(
                          'Breaking News',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 200,
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification
                                  is ScrollStartNotification) {
                                _pauseAndResumeAutoAdvance();
                              }
                              return false;
                            },
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount:
                                  _loopMultiplier * _breakingNews.length,
                              onPageChanged: (index) {
                                setState(() => _activeBreakingIndex =
                                    index % _breakingNews.length);
                              },
                              itemBuilder: (context, index) {
                                final news = _breakingNews[
                                    index % _breakingNews.length];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NewsDetailPage(
                                        article: {
                                          ...news,
                                          'category_display':
                                              'Breaking News',
                                        },
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                        right: 12),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          news['image'] != null
                                              ? Image.network(
                                                  news['image'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context,
                                                          error,
                                                          stackTrace) =>
                                                      Container(
                                                    color: const Color(
                                                        0xFFE4E6EB),
                                                  ),
                                                )
                                              : Container(
                                                  color: const Color(
                                                      0xFFE4E6EB),
                                                ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withValues(
                                                      alpha: 0.75),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 10,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.35),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _relativeTime(
                                                    news['date_published']),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 16,
                                            left: 12,
                                            right: 60,
                                            child: Text(
                                              news['title'] ?? '',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 12,
                                            bottom: 12,
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.35),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.north_east,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _breakingNews.length,
                            (index) {
                              final isActive = index == _activeBreakingIndex;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                width: isActive ? 18 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: isActive
                                      ? primaryBlue
                                      : Colors.grey.shade300,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ===== Category Tabs =====
                      if (_searchQuery.isEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              categories.length,
                              (index) {
                                final isActive =
                                    index == _activeCategoryIndex;
                                return GestureDetector(
                                  onTap: () {
                                    setState(
                                        () => _activeCategoryIndex = index);
                                    _loadContent();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 24),
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
                              },
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

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

                      // ===== Tab Loading =====
                      if (_isTabLoading)
                        _Shimmer(child: _buildSkeletonList())

                      // ===== Empty State =====
                      else if (_allNews.where(_matchesSearch).isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 48),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.newspaper_outlined,
                                  size: 48,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _emptyStateMessage(),
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

                      // ===== News List =====
                      else
                        Column(
                          children: [
                            ..._allNews
                                .where(_matchesSearch)
                                .map((item) => _newsTile(item)),

                            // ===== Load More =====
                            if (_hasMore && _searchQuery.isEmpty) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _loadMore,
                                child: Center(
                                  child: _isLoadingMore
                                      ? Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.grey.shade400,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : const Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          child: Text(
                                            'Load more',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: primaryBlue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _newsTile(Map<String, dynamic> article) {
    final String? imageUrl = article['image'];
    final String title = article['title'] ?? '';
    final String date = article['date_published'] ?? '';
    final String category = article['category_display'] ?? '';
    final String rawCategory = article['category'] ?? '';
    final String id = article['id'].toString();
    final bool isBookmarked = _bookmarkedIds.contains(id);
    final bool isAlert = rawCategory == 'ALERT';
    final bool isAllTab = _activeCategoryIndex == 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => NewsDetailPage(article: article)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          // Top-aligned so the bookmark button lines up with the
          // category label (ALERT/NOTICE) instead of sitting centered
          // against the full height of the row (including the taller
          // thumbnail).
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Thumbnail =====
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        width: 92,
                        height: 92,
                        color: const Color(0xFFE4E6EB),
                        child: const Icon(
                          Icons.newspaper_outlined,
                          color: Colors.black26,
                        ),
                      ),
                    )
                  : Container(
                      width: 92,
                      height: 92,
                      color: const Color(0xFFE4E6EB),
                      child: const Icon(
                        Icons.newspaper_outlined,
                        color: Colors.black26,
                      ),
                    ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAllTab && category.isNotEmpty) ...[
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAlert
                              ? Colors.red.shade600
                              : primaryBlue,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== Bookmark =====
            // top:12 matches the Expanded column's own top padding, so
            // this sits level with the category label, not centered
            // against the whole card's height.
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 12),
              child: _glassBookmarkButton(
                bookmarked: isBookmarked,
                onTap: () => _toggleBookmark(article),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Plain icon button — no frosted-glass circle/blur/border ring
  // around it (previously read as an odd glow on this card's plain
  // white background, unlike Events/Campaigns where that treatment
  // sits on top of a photo).
  Widget _glassBookmarkButton({
    required bool bookmarked,
    required VoidCallback onTap,
  }) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        bookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: bookmarked ? primaryBlue : Colors.black45,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}

// ============================================================
// SHIMMER — sweeps a soft light band across whatever's inside it,
// on a loop. Same widget as used on the Home and Reports screens'
// skeletons.
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