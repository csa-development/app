import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/swipe_back.dart';
import '../loggedin_user_pages/news_detail.dart';

class NewsAdvisoriesScreen extends StatefulWidget {
  const NewsAdvisoriesScreen({super.key});

  @override
  State<NewsAdvisoriesScreen> createState() =>
      _NewsAdvisoriesScreenState();
}

class _NewsAdvisoriesScreenState extends State<NewsAdvisoriesScreen> {
  static const Color primaryBlue = Color(0xFF00334D);

  int _activeCategoryIndex = 0;
  bool _isInitialLoad = true;
  bool _isTabLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _currentPage = 1;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allNews = [];

  final List<String> categories = [
    'All',
    'Alerts',
    'Advisories',
    'Notices',
    'News',
  ];

  final List<String?> _categoryKeys = [
    null,
    'ALERT',
    'ADVISORY',
    'NOTICE',
    'NEWS',
  ];

  final List<IconData> _categoryIcons = [
    Icons.grid_view_rounded,
    Icons.warning_amber_rounded,
    Icons.shield_outlined,
    Icons.campaign_outlined,
    Icons.article_outlined,
  ];

  final List<Color> _categoryIconColors = [
    primaryBlue,
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF00334D),
    Color(0xFF16A34A),
  ];

  @override
  void initState() {
    super.initState();
    _loadContent(initial: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

    if (newsResult['success']) {
      final List news = newsResult['data']['news'];
      final bool hasMore = newsResult['data']['has_more'] ?? false;
      setState(() {
        _allNews = news.map((n) => Map<String, dynamic>.from(n)).toList();
        _hasMore = hasMore;
        _currentPage = 1;
      });
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
      return dateStr;
    }
  }

  List<Map<String, dynamic>> get _filteredNews {
    if (_searchQuery.isEmpty) return _allNews;
    return _allNews
        .where((n) => (n['title'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase()))
        .toList();
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
      case 'News':
        return 'No news yet';
      default:
        return 'No news or advisories yet';
    }
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
            'NEWS AND ADVISORIES',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      body: EdgeSwipeBack(
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

                    if (_searchQuery.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE4E6EB)),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: List.generate(
                              categories.length, (index) {
                            final isActive =
                                index == _activeCategoryIndex;
                            return GestureDetector(
                              onTap: () {
                                setState(
                                    () => _activeCategoryIndex = index);
                                _loadContent();
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _categoryIcons[index],
                                    color: isActive
                                        ? _categoryIconColors[index]
                                        : Colors.black26,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    categories[index],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? primaryBlue
                                          : Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 2,
                                    width: 20,
                                    color: isActive
                                        ? primaryBlue
                                        : Colors.transparent,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),

                    const SizedBox(height: 20),

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

                    // ===== Tab Loading Skeleton — now shimmering =====
                    if (_isTabLoading)
                      _Shimmer(child: _buildSkeletonList())
                    else if (_filteredNews.isEmpty)
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
                    else
                      Column(
                        children: [
                          ..._filteredNews
                              .map((article) =>
                                  _newsTile(context, article)),
                          if (_hasMore && _searchQuery.isEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _loadMore,
                              child: Center(
                                child: _isLoadingMore
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.all(16),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child:
                                              CircularProgressIndicator(
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
    );
  }

  // ===== Initial-load skeleton — now shimmering =====
  Widget _buildSkeleton() {
    return _Shimmer(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonBox(height: 52, radius: 12),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: _skeletonBox(height: 16, width: 50),
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
                      _skeletonBox(
                          height: 14, width: double.infinity),
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
                bottomLeft:
                    Radius.circular(bottomLeftRadius ?? 0),
              )
            : BorderRadius.circular(radius),
      ),
    );
  }

  Widget _newsTile(
      BuildContext context, Map<String, dynamic> article) {
    final String? imageUrl = article['image'];
    final String title = article['title'] ?? '';
    final String date = article['date_published'] ?? '';
    final String category = article['category_display'] ?? '';
    final String rawCategory = article['category'] ?? '';
    final bool isAlert = rawCategory == 'ALERT';

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
          children: [
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
                      errorBuilder:
                          (context, error, stackTrace) => Container(
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
                    if (category.isNotEmpty)
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
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: Colors.black26,
                size: 20,
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