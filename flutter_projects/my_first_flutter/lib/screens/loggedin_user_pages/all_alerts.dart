import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/swipe_back.dart';
import 'news_detail.dart';

class AllAlertsPage extends StatefulWidget {
  const AllAlertsPage({super.key});

  @override
  State<AllAlertsPage> createState() => _AllAlertsPageState();
}

class _AllAlertsPageState extends State<AllAlertsPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  List<Map<String, dynamic>> _alertsList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getAlerts();
    if (result['success']) {
      final List alerts = result['data']['alerts'];
      setState(() {
        _alertsList = alerts.map((a) => Map<String, dynamic>.from(a)).toList();
      });
    }
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_searchQuery.isEmpty) return _alertsList;
    return _alertsList
        .where(
          (a) => (a['title'] ?? '').toString().toLowerCase().contains(
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
          'Latest Alerts',
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
              onRefresh: _loadAlerts,
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
                          hintText: 'Search alerts',
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

                  // ===== Alerts List =====
                  Expanded(
                    child: _filteredAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.warning_amber_outlined,
                                  size: 48,
                                  color: Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No results found for "$_searchQuery"'
                                      : 'No alerts available',
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
                            itemCount: _filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final item = _filteredAlerts[index];
                              return _alertTile(item);
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE4E6EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeletonBox(height: 36, width: 36, radius: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _skeletonBox(height: 14, width: double.infinity),
                            const SizedBox(height: 8),
                            _skeletonBox(height: 12, width: double.infinity),
                            const SizedBox(height: 6),
                            _skeletonBox(height: 12, width: 160),
                            const SizedBox(height: 8),
                            _skeletonBox(height: 10, width: 70),
                          ],
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

  Widget _alertTile(Map<String, dynamic> alert) {
    final String? imageUrl = alert['image'];
    final String title = alert['title'] ?? '';
    final String date = alert['date_published'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailPage(
            article: {
              ...alert,
              'category': 'ALERT',
              'category_display': 'Alert',
            },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _accentBar(),
                    )
                  : _accentBar(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _accentBar() {
    return Container(
      width: 4,
      height: 52,
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}