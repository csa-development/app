import 'package:flutter/material.dart';

import 'continue_login_flow.dart';
import 'main_user_screens/about_csa.dart';
import 'main_user_screens/contact_csa.dart';
import 'main_user_screens/cybersecurity_act.dart';
import 'main_user_screens/evens_campaign.dart';
import 'main_user_screens/license_accreditation.dart';
import 'main_user_screens/news_advisories.dart';

class MainUserScreen extends StatelessWidget {
  const MainUserScreen({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _goBack(context);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,

        // ========================================================
        // APP BAR
        // ========================================================

        appBar: AppBar(
          backgroundColor: primaryBlue,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 72,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => _goBack(context),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Image.asset(
                'assets/csalogowhite.png',
                height: 30,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cyber Security Authority',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // BODY
        //
        // Swipe RIGHT = Continue screen
        // Swipe LEFT  = nothing
        //
        // Same swipe behaviour as Login.
        // ========================================================

        body: GestureDetector(
          behavior: HitTestBehavior.translucent,

          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;

            if (velocity > 300) {
              _goBack(context);
            }
          },

          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                22,
                18,
                28,
              ),
              children: [
                _menuTile(
                  context,
                  title: 'News and Advisories',
                  subtitle:
                      'Stay informed on cybersecurity news and advisories.',
                  icon: Icons.campaign_outlined,
                  destination: const NewsAdvisoriesScreen(),
                ),

                _menuTile(
                  context,
                  title: 'Licensing & Accreditation',
                  subtitle:
                      'Access licensing and accreditation information.',
                  icon: Icons.verified_user_outlined,
                  destination: const LicenseAccreditationScreen(),
                ),

                _menuTile(
                  context,
                  title: 'Events and Campaigns',
                  subtitle:
                      'Explore cybersecurity events and awareness campaigns.',
                  icon: Icons.event_outlined,
                  destination: const EventsCampaignScreen(),
                ),

                _menuTile(
                  context,
                  title: 'About CSA',
                  subtitle:
                      'Learn more about the Cyber Security Authority.',
                  icon: Icons.info_outline_rounded,
                  destination: const AboutCsa(),
                ),

                _menuTile(
                  context,
                  title: 'Cybersecurity Act, 2020 (Act 1038)',
                  subtitle:
                      'Read the full text of the law that governs cybersecurity in Ghana.',
                  icon: Icons.balance_outlined,
                  destination: const CybersecurityActScreen(),
                ),

                _menuTile(
                  context,
                  title: 'Contact CSA',
                  subtitle:
                      'Find contact information and support channels.',
                  icon: Icons.support_agent_outlined,
                  destination: const ContactCsa(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BACK TO CONTINUE
  // ============================================================

  void _goBack(BuildContext context) {
    final nav = Navigator.of(context);

    // Normal case (came from the Continue screen): pop back to it so the
    // transition slides, matching Login / Create Account.
    if (nav.canPop()) {
      nav.pop();
      return;
    }

    // Reached here as the only route (e.g. after "message sent" clears the
    // stack) — nothing to pop, so rebuild the Continue flow.
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ContinueLoginFlow(),
      ),
    );
  }

  // ============================================================
  // MENU TILE
  // ============================================================

  Widget _menuTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigate(
            context,
            destination,
          ),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE7EAF0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.035,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: primaryBlue,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF20202F),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigate(
    BuildContext context,
    Widget destination,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => destination,
      ),
    );
  }
}