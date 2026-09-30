import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/swipe_back.dart';
import 'news_detail.dart';

class AllNewsPage extends StatefulWidget {
  const AllNewsPage({super.key});

  @override
  State<AllNewsPage> createState() => _AllNewsPageState();
}

class _AllNewsPageState extends State<AllNewsPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  List<Map<String, dynamic>> _newsList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getNews();
    if (result['success']) {
      final List news = result['data']['news'];
      setState(() {
        _newsList = news.map((n) => Map<String, dynamic>.from(n)).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredNews {
    if (_searchQuery.isEmpty) return _newsList;
    return _newsList
        .where(
          (n) => (n['title'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
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
          'Latest News',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
      body: SwipeBack(
        child: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              color: primaryBlue,
              onRefresh: _loadNews,
              child: Column(
                children: [
                  // ===== Search Bar =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE4E6EB)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(
                            fontSize: 15, color: Colors.black87),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          hintText: 'Search news',
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
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.black45,
                                    size: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // ===== News List =====
                  Expanded(
                    child: _filteredNews.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.newspaper_outlined,
                                  size: 48,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No results found for "$_searchQuery"'
                                      : 'No news available',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredNews.length,
                            itemBuilder: (context, index) {
                              final item = _filteredNews[index];
                              return _newsTile(item);
                            },
                          ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  // ===== SKELETON =====
  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _skeletonBox(height: 48, radius: 50),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
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
                        width: 90,
                        height: 90,
                        radius: 0,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _skeletonBox(height: 10, width: 60),
                              const SizedBox(height: 8),
                              _skeletonBox(height: 14, width: double.infinity),
                              const SizedBox(height: 4),
                              _skeletonBox(height: 14, width: 160),
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
            ),
          ),
        ],
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

  Widget _newsTile(Map<String, dynamic> article) {
    final String? imageUrl = article['image'];
    final String title = article['title'] ?? '';
    final String date = article['date_published'] ?? '';
    final String category = article['category_display'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
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
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90,
                        height: 90,
                        color: const Color(0xFFF3F6F9),
                        child: const Icon(
                          Icons.newspaper_outlined,
                          color: Colors.black26,
                        ),
                      ),
                    )
                  : Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFF3F6F9),
                      child: const Icon(
                        Icons.newspaper_outlined,
                        color: Colors.black26,
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty)
                      Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.black26, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}