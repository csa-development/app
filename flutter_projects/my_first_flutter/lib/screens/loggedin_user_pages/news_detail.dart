import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';

class NewsDetailPage extends StatefulWidget {
  final Map<String, dynamic> article;

  const NewsDetailPage({super.key, required this.article});

  @override
  State<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends State<NewsDetailPage> {
  static const Color primaryBlue = Color(0xFF00334D);
  bool _isBookmarked = false;

  // This page is reused by the logged-out "guest" browsing flow (see
  // main_user_screens/news_advisories.dart), which has nowhere to
  // surface a saved bookmark — there's no Bookmarks page reachable
  // without an account. So bookmarking is only offered once a user is
  // actually logged in.
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final accessToken = await AuthStorage.getAccessToken();
    if (!mounted) return;
    setState(() => _isLoggedIn = accessToken != null);
    if (accessToken != null) _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('bookmarked_articles') ?? [];
    final id = widget.article['id'].toString();
    setState(() => _isBookmarked = saved.contains(id));
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.article['id'].toString();
    List<String> saved = prefs.getStringList('bookmarked_articles') ?? [];
    List<String> savedData =
        prefs.getStringList('bookmarked_articles_data') ?? [];

    if (saved.contains(id)) {
      saved.remove(id);
      savedData.removeWhere((s) {
        final decoded = jsonDecode(s);
        return decoded['id'].toString() == id;
      });
      setState(() => _isBookmarked = false);
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
      savedData.add(jsonEncode(widget.article));
      setState(() => _isBookmarked = true);
      if (mounted) {
        showTopToast(context, 'Article bookmarked', isError: false);
      }
    }

    await prefs.setStringList('bookmarked_articles', saved);
    await prefs.setStringList('bookmarked_articles_data', savedData);
  }

  void _showMoreOptions() {
    final String title = widget.article['title'] ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              if (_isLoggedIn)
                ListTile(
                  leading: Icon(
                    _isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: primaryBlue,
                  ),
                  title: Text(
                    _isBookmarked ? 'Remove Bookmark' : 'Bookmark Article',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _toggleBookmark();
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: primaryBlue,
                ),
                title: const Text(
                  'Share Article',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final newsId = widget.article['id'];
                  Share.share(
                    '$title\n\n${ApiService.publicWebBaseUrl}/news/$newsId/',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final String title = widget.article['title'] ?? '';
    final String body = widget.article['body'] ?? '';
    final String date = widget.article['date_published'] ?? '';
    final String? imageUrl = widget.article['image'];
    final String category = widget.article['category_display'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: category.isNotEmpty
            ? Text(
                category.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: 0.8,
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.black,
              size: 22,
            ),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Title =====
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 10),

            // ===== Timestamp =====
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  _relativeTime(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ===== Image =====
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E6EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.newspaper_outlined,
                      color: Colors.black26,
                      size: 50,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ===== Body =====
            SelectableText(
              body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }
}