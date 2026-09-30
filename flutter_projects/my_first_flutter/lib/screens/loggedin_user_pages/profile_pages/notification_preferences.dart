import 'package:flutter/material.dart';

import '../../../widgets/swipe_back.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  static const Color primaryBlue = Color(0xFF00334D);

  bool _alerts = true;
  bool _advisories = true;
  bool _news = false;
  bool _events = false;
  bool _reportUpdates = true;
  bool _emailNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Push Notifications'),
            const SizedBox(height: 12),
            _toggleCard([
              _ToggleItem(
                icon: Icons.warning_amber_outlined,
                title: 'Alerts',
                subtitle: 'Cyber threat and security alerts',
                value: _alerts,
                onChanged: (val) => setState(() => _alerts = val),
              ),
              _ToggleItem(
                icon: Icons.info_outline,
                title: 'Advisories',
                subtitle: 'Safety tips and advisories from CSA',
                value: _advisories,
                onChanged: (val) => setState(() => _advisories = val),
              ),
              _ToggleItem(
                icon: Icons.newspaper_outlined,
                title: 'News',
                subtitle: 'Latest news from CSA',
                value: _news,
                onChanged: (val) => setState(() => _news = val),
              ),
              _ToggleItem(
                icon: Icons.campaign_outlined,
                title: 'Events & Campaigns',
                subtitle: 'Upcoming CSA programmes',
                value: _events,
                onChanged: (val) => setState(() => _events = val),
              ),
              _ToggleItem(
                icon: Icons.description_outlined,
                title: 'Report Updates',
                subtitle: 'Status changes on your submitted reports',
                value: _reportUpdates,
                onChanged: (val) => setState(() => _reportUpdates = val),
              ),
            ]),

            const SizedBox(height: 24),

            _sectionLabel('Other'),
            const SizedBox(height: 12),
            _toggleCard([
              _ToggleItem(
                icon: Icons.mail_outline,
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                value: _emailNotifications,
                onChanged: (val) => setState(() => _emailNotifications = val),
              ),
            ]),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00334D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'SAVE PREFERENCES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.black38,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _toggleCard(List<_ToggleItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: item.value,
                      onChanged: item.onChanged,
                      activeColor: primaryBlue,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade100,
                  indent: 70,
                ),
            ],
          );
        }),
      ),
      ),
    );
  }
}

class _ToggleItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
}
