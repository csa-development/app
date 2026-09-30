import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/bookmark_service.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';

class PressReleaseDetailPage extends StatefulWidget {
  final Map<String, dynamic> pressRelease;

  const PressReleaseDetailPage({super.key, required this.pressRelease});

  @override
  State<PressReleaseDetailPage> createState() =>
      _PressReleaseDetailPageState();
}

class _PressReleaseDetailPageState extends State<PressReleaseDetailPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadBookmarkState();
  }

  Future<void> _loadBookmarkState() async {
    final isBookmarked = await BookmarkService.isBookmarked(
      'press_release',
      widget.pressRelease['id'].toString(),
    );
    if (!mounted) return;
    setState(() => _isBookmarked = isBookmarked);
  }

  Future<void> _toggleBookmark() async {
    final nowBookmarked =
        await BookmarkService.toggle('press_release', widget.pressRelease);
    if (!mounted) return;
    setState(() => _isBookmarked = nowBookmarked);
    showTopToast(
      context,
      nowBookmarked ? 'Press release bookmarked' : 'Bookmark removed',
      isError: false,
      backgroundColor: nowBookmarked ? null : Colors.black54,
      icon: nowBookmarked ? null : Icons.info_outline,
    );
  }

  void _showMoreOptions() {
    final String title = widget.pressRelease['title'] ?? '';
    final String body = widget.pressRelease['body'] ?? '';

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

              // ===== Bookmark =====
              ListTile(
                leading: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: primaryBlue,
                ),
                title: Text(
                  _isBookmarked ? 'Remove Bookmark' : 'Bookmark Press Release',
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

              // ===== Share =====
              ListTile(
                leading: const Icon(Icons.share_outlined, color: primaryBlue),
                title: const Text(
                  'Share Press Release',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('$title\n\n$body');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.pressRelease['title'] ?? '';
    final String body = widget.pressRelease['body'] ?? '';
    final String date = widget.pressRelease['date_published'] ?? '';
    final String? imageUrl = widget.pressRelease['image'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? primaryBlue : Colors.black,
              size: 22,
            ),
            onPressed: _toggleBookmark,
          ),
          // ===== Three dots menu (replaces bare share icon) =====
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black, size: 22),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Category Badge =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRESS RELEASE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                  letterSpacing: 0.8,
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
                height: 1.3,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // ===== Date =====
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: Colors.black38,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ===== Image =====
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ===== Divider (spacing tightened: 20 -> 12) =====
            const Divider(color: Color(0xFFE4E6EB)),
            const SizedBox(height: 12),

            // ===== Body =====
            SelectableText(
              body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.8,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }
}