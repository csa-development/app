import 'package:flutter/material.dart';
import '../main_user_screens/license_accreditation.dart';
import '../loggedin_user_pages/events_campaigns.dart';
import '../loggedin_user_pages/contact_csa.dart';
import '../main_user_screens/about_csa.dart';
import '../main_user_screens/csa_units.dart';

class LoggedInMore extends StatelessWidget {
  const LoggedInMore({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'More',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Access CSA services and information',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),

              const SizedBox(height: 32),

              _sectionLabel('CSA Services'),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                items: [
                  _TileItem(
                    icon: Icons.verified_outlined,
                    title: 'Licensing & Accreditation',
                    destination: const LicenseAccreditationScreen(),
                  ),
                  _TileItem(
                    icon: Icons.campaign_outlined,
                    title: 'Events & Campaigns',
                    destination: const LoggedInEventsCampaigns(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _sectionLabel('Information'),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                items: [
                  _TileItem(
                    icon: Icons.info_outline,
                    title: 'About CSA',
                    destination: const AboutCsa(),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _sectionLabel('Connect'),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                items: [
                  _TileItem(
                    icon: Icons.phone_outlined,
                    title: 'Contact CSA',
                    destination: const LoggedInContactCsa(),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
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

  Widget _sectionCard(BuildContext context, {required List<_TileItem> items}) {
    return Container(
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return _buildTile(context, item, isLast);
        }),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _TileItem item, bool isLast) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.destination),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
              indent: 72,
            ),
        ],
      ),
    );
  }
}

class _TileItem {
  final IconData icon;
  final String title;
  final Widget destination;

  const _TileItem({
    required this.icon,
    required this.title,
    required this.destination,
  });
}
