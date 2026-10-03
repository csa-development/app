import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'; // provides `routeObserver`
import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/local_image.dart';
import '../../widgets/profile_image_picker.dart';
import '../../widgets/quick_action_tile.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';
import '../main_user_screens/about_csa.dart';
import '../main_user_screens/csa_units.dart';
import '../main_user_screens/license_accreditation.dart';
import '../main_user_screens/license_accreditation/apply.dart';
import '../main_user_screens/license_accreditation/verify.dart';
import '../main_user_screens/report_incident.dart';
import 'all_alerts.dart';
import 'all_news.dart';
import 'contact_csa.dart';
import 'events_campaigns.dart';
import 'news.dart';
import 'news_detail.dart';

class LoggedInHome extends StatefulWidget {
  const LoggedInHome({super.key});

  @override
  State<LoggedInHome> createState() => _LoggedInHomeState();
}

class _LoggedInHomeState extends State<LoggedInHome> with RouteAware {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  String _firstName = '';
  String _searchQuery = '';
  bool _isInitialLoad = true;
  bool _hasError = false;
  // The specific reason the last load failed (offline / slow / CSA's
  // side), when ApiService could tell — shown in the banner instead of a
  // generic line. Null falls back to the generic text.
  String? _loadErrorMessage;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _newsList = [];
  List<Map<String, dynamic>> _alertsList = [];
  List<Map<String, dynamic>> _myRegistrations = [];

  final List<Map<String, dynamic>> _searchItems = [
    {
      'title': 'Report Incident',
      'subtitle': 'Report a cyber incident to CSA',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(),
    },
    {
      'title': 'Verify Certificate',
      'subtitle': 'Verify a CSA issued certificate',
      'icon': Icons.verified_outlined,
      'page': const Verifyli(),
    },
    {
      'title': 'Apply for License',
      'subtitle': 'Apply for CSA licensing and accreditation',
      'icon': Icons.assignment_outlined,
      'page': const ApplyLicensePage(),
    },
    {
      'title': 'Events and Campaigns',
      'subtitle': 'View upcoming CSA events and campaigns',
      'icon': Icons.campaign_outlined,
      'page': const LoggedInEventsCampaigns(),
    },
    {
      'title': 'Licensing and Accreditation',
      'subtitle': 'Overview of CSA licensing categories',
      'icon': Icons.workspace_premium_outlined,
      'page': const LicenseAccreditationScreen(),
    },
    {
      'title': 'News and Advisories',
      'subtitle': 'Latest news alerts and advisories from CSA',
      'icon': Icons.newspaper_outlined,
      'page': const AllNewsPage(),
    },
    {
      'title': 'About CSA',
      'subtitle': 'Learn about the Cyber Security Authority',
      'icon': Icons.info_outline,
      'page': const AboutCsa(),
    },
    {
      'title': 'CSA Units',
      'subtitle': 'Departments and units of CSA',
      'icon': Icons.account_tree_outlined,
      'page': const CsaUnits(),
    },
    {
      'title': 'Contact CSA',
      'subtitle': 'Phone email and office locations',
      'icon': Icons.phone_outlined,
      'page': const LoggedInContactCsa(),
    },
    {
      'title': 'Fraud',
      'subtitle': 'Report a fraud incident',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(preselectedType: 'Fraud'),
    },
    {
      'title': 'Phishing',
      'subtitle': 'Report a phishing incident',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(preselectedType: 'Phishing'),
    },
    {
      'title': 'Cyberbullying',
      'subtitle': 'Report a cyberbullying incident',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(preselectedType: 'Cyberbullying'),
    },
    {
      'title': 'Malware',
      'subtitle': 'Report a malware incident',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(preselectedType: 'Malware'),
    },
    {
      'title': 'Online Blackmail',
      'subtitle': 'Report an online blackmail incident',
      'icon': Icons.report_outlined,
      'page': const ReportIncidentScreen(preselectedType: 'Online Blackmail'),
    },
  ];

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return [];
    return _searchItems.where((item) {
      return item['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          item['subtitle'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadContent(initial: true);
    _searchFocus.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so we know when this screen is
    // returned to (e.g. after registering for an event on
    // EventDetailPage and navigating back).
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ===== RouteAware =====
  // Called automatically whenever a route that was pushed on top of
  // this one (e.g. EventDetailPage) gets popped and this screen is
  // visible again. This is what refreshes "My Tickets" without
  // requiring a manual pull-to-refresh.
  @override
  void didPopNext() {
    _loadContent(initial: false);
  }

  Future<void> _loadUserData() async {
    final fullName = await AuthStorage.getFullName();
    await AuthStorage.getProfileImagePath();
    if (!mounted) return;
    setState(() {
      _firstName = fullName?.split(' ').first ?? '';
    });
  }

  Future<void> _loadContent({bool initial = false}) async {
    if (initial) {
      setState(() {
        _isInitialLoad = true;
        _hasError = false;
      });
    }

    bool newsOk = false;
    bool alertsOk = false;

    final newsResult = await ApiService.getNews();
    if (newsResult['success']) {
      newsOk = true;
      final List news = newsResult['data']['news'];
      setState(() {
        _newsList =
            news.take(3).map((n) => Map<String, dynamic>.from(n)).toList();
      });
    }

    final alertsResult = await ApiService.getAlerts();
    if (alertsResult['success']) {
      alertsOk = true;
      final List alerts = alertsResult['data']['alerts'];
      setState(() {
        _alertsList =
            alerts.take(3).map((a) => Map<String, dynamic>.from(a)).toList();
      });
    }

    final accessToken = await AuthStorage.getAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      final List<Map<String, dynamic>> allRegistrations = [];

      final registrationsResult = await ApiService.getMyEventRegistrations(
        accessToken: accessToken,
      );
      if (registrationsResult['success']) {
        final List regs = registrationsResult['data']['registrations'] ?? [];
        allRegistrations.addAll(
          regs.map((r) => {...Map<String, dynamic>.from(r), 'type': 'event'}),
        );
      }

      final campaignRegistrationsResult =
          await ApiService.getMyCampaignRegistrations(
        accessToken: accessToken,
      );
      if (campaignRegistrationsResult['success']) {
        final List regs =
            campaignRegistrationsResult['data']['registrations'] ?? [];
        allRegistrations.addAll(regs.map((r) => {
              'event_title': r['campaign_title'],
              'event_date': r['campaign_date'],
              'check_in_code': r['check_in_code'],
              'checked_in': r['checked_in'],
              'registered_at': r['registered_at'],
              'type': 'campaign',
            }));
      }

      // Newest registration first — previously this just kept whatever
      // order the two API calls happened to return (effectively oldest
      // registered event first), so a ticket you'd just registered for
      // showed up at the bottom of the list instead of the top.
      allRegistrations.sort((a, b) {
        DateTime? parse(dynamic value) {
          if (value is! String || value.isEmpty) return null;
          return DateTime.tryParse(value);
        }

        final aDate = parse(a['registered_at']);
        final bDate = parse(b['registered_at']);
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _myRegistrations = allRegistrations;
      });
    }

    if (!mounted) return;
    setState(() {
      _isInitialLoad = false;
      _hasError = !newsOk && !alertsOk;
      _loadErrorMessage = _hasError && newsResult['kind'] != null
          ? newsResult['error'] as String
          : null;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _callHotline() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '292');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _pickImage() => showProfileImagePicker(context);

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showTopToast(
      context,
      'Check-in code copied',
      isError: false,
      backgroundColor: Colors.black54,
      icon: Icons.info_outline,
    );
  }

  void _showMyTickets() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'My Tickets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _myRegistrations.isEmpty
                      ? ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: const [
                            SizedBox(height: 48),
                            Center(
                              child: Icon(
                                CupertinoIcons.ticket,
                                size: 40,
                                color: Colors.black26,
                              ),
                            ),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'You have no registration for an event yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: _myRegistrations
                              .map((reg) => _registrationCard(reg))
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullTicket(Map<String, dynamic> reg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF8F9FB),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            title: const Text(
              'Your Ticket',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          body: SwipeBack(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _registrationCard(reg, expandable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: _isInitialLoad ? _buildSkeleton() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: Colors.grey.shade400,
      onRefresh: () => _loadContent(initial: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      _firstName.isEmpty ? 'Welcome' : _firstName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _showMyTickets,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3F6F9),
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Center(
                                    child: Icon(
                                      CupertinoIcons.ticket,
                                      color: primaryBlue,
                                      size: 22,
                                    ),
                                  ),
                                  if (_myRegistrations.isNotEmpty)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${_myRegistrations.length}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Event Tickets',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F6F9),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: ValueListenableBuilder<String?>(
                            valueListenable: AuthStorage.profileImageNotifier,
                            builder: (context, path, _) {
                              return path != null
                                  ? localImage(
                                      path,
                                      fit: BoxFit.cover,
                                      width: 46,
                                      height: 46,
                                    )
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.black,
                                      size: 26,
                                    );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  hintText: 'Search CSA',
                  hintStyle: const TextStyle(
                      color: Colors.black45, fontSize: 15),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.black45, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _searchFocus.unfocus();
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

            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_filteredItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No results found',
                      style: TextStyle(fontSize: 14, color: Colors.black45),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4E6EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: List.generate(_filteredItems.length, (index) {
                      final item = _filteredItems[index];
                      final isLast = index == _filteredItems.length - 1;
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _searchFocus.unfocus();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => item['page'] as Widget,
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          primaryBlue.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      size: 18,
                                      color: primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'].toString(),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['subtitle'].toString(),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF0F0F0),
                              indent: 64,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),

              if (_hasError) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_outlined,
                          size: 18, color: Colors.red.shade600),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _loadErrorMessage ??
                              "Couldn't load the latest updates.",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _loadContent(initial: true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Try again',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              GestureDetector(
                onTap: _callHotline,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emergency Hotline',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 6),
                            Icon(Icons.phone, color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                      Text(
                        '292',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.report_outlined,
                      label: 'Report\nIncident',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReportIncidentScreen(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.campaign_outlined,
                      label: 'Events &\nCampaigns',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoggedInEventsCampaigns(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.phone_outlined,
                      label: 'Contact\nCSA',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoggedInContactCsa(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: QuickActionTile(
                      icon: Icons.newspaper_outlined,
                      label: 'News &\nAdvisories',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoggedInNews(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Latest News',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllNewsPage()),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 200,
                child: _newsList.isEmpty
                    ? Center(
                        child: Text(
                          _hasError
                              ? 'Unable to load news right now'
                              : 'No news available',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _newsList.length,
                        itemBuilder: (context, index) {
                          final item = _newsList[index];
                          return _newsCard(item);
                        },
                      ),
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Latest Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllAlertsPage(),
                      ),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _alertsList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _hasError
                              ? 'Unable to load alerts right now'
                              : 'No alerts available',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children:
                          _alertsList.map((a) => _alertTile(a)).toList(),
                    ),

              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _registrationCard(Map<String, dynamic> reg, {bool expandable = true}) {
    final String eventTitle = reg['event_title'] ?? '';
    final String eventDate = reg['event_date'] ?? '';
    final String checkInCode = reg['check_in_code'] ?? '';
    final bool checkedIn = reg['checked_in'] == true;
    final bool isCampaign = reg['type'] == 'campaign';
    const double notchSize = 16;

    return GestureDetector(
      onTap: expandable ? () => _showFullTicket(reg) : null,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, primaryBlue.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCampaign ? 'CAMPAIGN TICKET' : 'EVENT TICKET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        eventTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      if (eventDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.event_outlined,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.75)),
                            const SizedBox(width: 5),
                            Text(
                              eventDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (checkedIn)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Checked in',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(
            height: notchSize,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: notchSize / 2 - 1,
                  child: CustomPaint(
                    size: const Size(double.infinity, 2),
                    painter: _DashedLinePainter(color: const Color(0xFFE4E6EB)),
                  ),
                ),
                Positioned(
                  left: -notchSize / 2,
                  top: -notchSize / 2,
                  child: Container(
                    width: notchSize,
                    height: notchSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: -notchSize / 2,
                  top: -notchSize / 2,
                  child: Container(
                    width: notchSize,
                    height: notchSize,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (checkInCode.isNotEmpty)
            GestureDetector(
              onTap: () => _copyCode(checkInCode),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHECK-IN CODE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.black38,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            checkInCode,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryBlue,
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.copy_rounded,
                          size: 16, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return _Shimmer(
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(height: 14, width: 120),
                  const SizedBox(height: 8),
                  _skeletonBox(height: 22, width: 100),
                ],
              ),
              _skeletonBox(height: 46, width: 46, radius: 23),
            ],
          ),
          const SizedBox(height: 20),
          _skeletonBox(height: 48, radius: 50),
          const SizedBox(height: 24),
          _skeletonBox(height: 60, radius: 8),
          const SizedBox(height: 24),
          _skeletonBox(height: 16, width: 120),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  5,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        _skeletonBox(height: 60, width: 60, radius: 30),
                        const SizedBox(height: 8),
                        _skeletonBox(height: 10, width: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _skeletonBox(height: 16, width: 100),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  2,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _skeletonBox(height: 200, width: 200, radius: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _skeletonBox(height: 16, width: 100),
          const SizedBox(height: 12),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _skeletonBox(height: 60, radius: 8),
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

  Widget _newsCard(Map<String, dynamic> article) {
    final String? imageUrl = article['image'];
    final String title = article['title'] ?? '';
    final String date = article['date_published'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
      ),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
                      width: 200,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 200,
                        height: 120,
                        color: const Color(0xFFE4E6EB),
                        child: const Icon(
                          Icons.newspaper_outlined,
                          color: Colors.black26,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      width: 200,
                      height: 120,
                      color: const Color(0xFFE4E6EB),
                      child: const Icon(
                        Icons.newspaper_outlined,
                        color: Colors.black26,
                        size: 40,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
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

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================
// SHIMMER — sweeps a soft light band across whatever's inside it,
// on a loop. Wraps the whole skeleton so every grey box shimmers
// together as one, instead of needing to animate each box
// separately.
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
