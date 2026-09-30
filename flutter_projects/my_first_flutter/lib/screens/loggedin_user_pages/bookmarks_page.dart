import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/bookmark_service.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';
import 'campaign_article_detail.dart';
import 'campaign_details.dart';
import 'event_detail.dart';
import 'news_detail.dart';
import 'press_release_detail.dart';

class BookmarksPage extends StatefulWidget {
  // Which filter tab is active when the page opens. Lets each entry
  // point (News, Events & Campaigns, ...) land on just its own
  // bookmarks instead of always dumping the user into everything.
  final String initialFilter;

  const BookmarksPage({super.key, this.initialFilter = 'All'});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  static const List<String> _filters = [
    'All',
    'News',
    'Events & Campaigns',
    'Press Releases',
  ];

  bool _isLoading = true;
  List<Map<String, dynamic>> _bookmarks = [];
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadBookmarks();
  }

  List<Map<String, dynamic>> get _filteredBookmarks {
    switch (_selectedFilter) {
      case 'News':
        return _bookmarks.where((b) => b['bookmark_type'] == 'article').toList();
      case 'Events & Campaigns':
        return _bookmarks
            .where((b) =>
                b['bookmark_type'] == 'event' ||
                b['bookmark_type'] == 'campaign')
            .toList();
      case 'Press Releases':
        return _bookmarks
            .where((b) => b['bookmark_type'] == 'press_release')
            .toList();
      default:
        return _bookmarks;
    }
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);

    // News articles have their own long-standing bookmark storage
    // (untouched here); campaigns/press releases/events share the
    // newer BookmarkService. 'bookmark_type' tags each entry so the
    // tile knows how to render and navigate.
    final prefs = await SharedPreferences.getInstance();
    final articleData = prefs.getStringList('bookmarked_articles_data') ?? [];
    final articles = articleData
        .map((s) => {
              ...Map<String, dynamic>.from(jsonDecode(s)),
              'bookmark_type': 'article',
            })
        .toList();

    final campaigns = await BookmarkService.loadData('campaign');
    final pressReleases = await BookmarkService.loadData('press_release');
    final events = await BookmarkService.loadData('event');

    if (!mounted) return;
    setState(() {
      _bookmarks = [...articles, ...campaigns, ...pressReleases, ...events];
      _isLoading = false;
    });
  }

  Future<void> _removeBookmark(Map<String, dynamic> item) async {
    final String type = item['bookmark_type'] ?? 'article';
    final id = item['id'].toString();

    if (type == 'article') {
      final prefs = await SharedPreferences.getInstance();
      List<String> saved = prefs.getStringList('bookmarked_articles') ?? [];
      List<String> savedData =
          prefs.getStringList('bookmarked_articles_data') ?? [];

      saved.remove(id);
      savedData.removeWhere((s) => jsonDecode(s)['id'].toString() == id);

      await prefs.setStringList('bookmarked_articles', saved);
      await prefs.setStringList('bookmarked_articles_data', savedData);
    } else {
      await BookmarkService.toggle(type, item);
    }

    if (!mounted) return;
    setState(() {
      _bookmarks.removeWhere(
        (b) => b['id'].toString() == id && b['bookmark_type'] == type,
      );
    });
    showTopToast(
      context,
      'Bookmark removed',
      isError: false,
      backgroundColor: Colors.black54,
      icon: Icons.info_outline,
    );
  }

  void _openBookmark(Map<String, dynamic> item) {
    final String type = item['bookmark_type'] ?? 'article';
    switch (type) {
      case 'campaign':
        final bool isNcsam = (item['category'] ?? '') == 'NCSAM';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isNcsam
                ? CampaignDetailPage(campaign: item)
                : CampaignArticleDetailPage(campaign: item),
          ),
        );
        break;
      case 'press_release':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PressReleaseDetailPage(pressRelease: item),
          ),
        );
        break;
      case 'event':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventDetailPage(event: item)),
        );
        break;
      default:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NewsDetailPage(article: item)),
        );
    }
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
          'Bookmarks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: SwipeBack(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookmarks.isEmpty
                ? _emptyState(
                    'No bookmarks yet',
                    'Tap the bookmark icon on any article, event, '
                        'campaign, or press release to save it',
                  )
                : Column(
                    children: [
                      _filterTabs(),
                      Expanded(
                        child: _filteredBookmarks.isEmpty
                            ? _emptyState(
                                'No bookmarks here yet',
                                'Nothing saved under "$_selectedFilter" so far',
                              )
                            : RefreshIndicator(
                                color: primaryBlue,
                                onRefresh: _loadBookmarks,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredBookmarks.length,
                                  itemBuilder: (context, index) =>
                                      _bookmarkTile(_filteredBookmarks[index]),
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _filterTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _filters.map((filter) {
          final bool isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? primaryBlue : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isSelected)
                    Container(height: 3, width: 20, color: primaryBlue),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmark_border,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.black45),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookmarkTile(Map<String, dynamic> item) {
    final String type = item['bookmark_type'] ?? 'article';
    final String? imageUrl = item['image'];
    final String title = item['title'] ?? '';
    final String date = item['date_published'] ??
        item['event_date'] ??
        item['start_date'] ??
        '';
    final bool isAlert = type == 'article' && item['category'] == 'ALERT';

    String kicker;
    switch (type) {
      case 'campaign':
        kicker = item['category_display'] ?? 'Campaign';
        break;
      case 'press_release':
        kicker = 'Press Release';
        break;
      case 'event':
        kicker = 'Event';
        break;
      default:
        kicker = item['category_display'] ?? '';
    }

    return GestureDetector(
      onTap: () => _openBookmark(item),
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
                      errorBuilder: (context, error, stackTrace) =>
                          _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker.isNotEmpty) ...[
                      Text(
                        kicker.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              isAlert ? Colors.red.shade600 : Colors.black54,
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
            GestureDetector(
              onTap: () => _removeBookmark(item),
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.bookmark,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 92,
      height: 92,
      color: const Color(0xFFE4E6EB),
      child: const Icon(
        Icons.newspaper_outlined,
        color: Colors.black26,
      ),
    );
  }
}
