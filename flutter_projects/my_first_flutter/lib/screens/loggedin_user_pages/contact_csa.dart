import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/swipe_back.dart';

class LoggedInContactCsa extends StatefulWidget {
  const LoggedInContactCsa({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  State<LoggedInContactCsa> createState() => _LoggedInContactCsaState();
}

class _LoggedInContactCsaState extends State<LoggedInContactCsa> {
  static const Color primaryBlue = Color(0xFF00334D);
  // NCA Tower, 6 Airport Bypass Road, Accra — matches office_address
  // below. Only used if the CMS hasn't set a location yet. This is
  // Google Maps' own pin for the "National Communications Authority"
  // place listing itself (address on the listing reads "NCA Tower,
  // KIA, 6 Airport By-pass Rd") — not a raw lat/long guess, which
  // previously landed ~2.3km away with no place attached to it.
  static const LatLng _fallbackLocation = LatLng(5.6037075, -0.1764636);

  bool _isLoading = true;
  Map<String, dynamic>? _contact;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final result = await ApiService.getContactPage();
    if (!mounted) return;

    setState(() {
      _contact = result['success'] == true
          ? result['data']['contact'] as Map<String, dynamic>?
          : null;
      _isLoading = false;
    });
  }

  String _text(String key, String fallback) {
    final value = _contact?[key];
    return (value is String && value.isNotEmpty) ? value : fallback;
  }

  LatLng get _location {
    final lat = _contact?['latitude'];
    final lng = _contact?['longitude'];
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    return _fallbackLocation;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _getDirections() async {
    final loc = _location;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final officeAddress = _text(
      'office_address',
      '3rd Floor, NCA Tower, 6 Airport By-pass Road, Accra',
    );
    final phone = _text('phone', '+233 303 972 530');
    final emergencyHotline = _text('emergency_hotline', '292');
    final email = _text('email', 'info@csa.gov.gh');
    // wa.me opens a direct chat with this number — the response
    // team's actual WhatsApp line. Deliberately NOT sourced from the
    // 'whatsapp_channel_url' CMS field — that field holds the
    // broadcast channel link (used elsewhere for a "WhatsApp Channel"
    // tile), which only lets you receive posts, not send a message.
    // There's no CMS field yet for a direct chat number, so this
    // stays hardcoded until one exists.
    const whatsappUrl = 'https://wa.me/233501603111';
    final twitterUrl = _text('twitter_url', 'https://twitter.com/CSAGhana');
    final instagramUrl =
        _text('instagram_url', 'https://www.instagram.com/csaghana/');
    final linkedinUrl = _text('linkedin_url', 'https://www.linkedin.com');
    final facebookUrl =
        _text('facebook_url', 'https://www.facebook.com/CSAGhana');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Contact Us',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
      ),
      body: EdgeSwipeBack(
        child: _isLoading
            ? _buildSkeleton()
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== Visit Our Office =====
                    _sectionLabel('Visit Our Office'),
                    const SizedBox(height: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 280,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE4E6EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: _location,
                                initialZoom: 15,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.my_first_flutter',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _location,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.location_pin,
                                        color: Colors.red,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            Positioned(
                              top: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        officeAddress,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _getDirections,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.directions,
                                          color: primaryBlue, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Get Directions',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Digital address line — kept from the old logged-in
                    // page, shown as a small caption under the map
                    // instead of a separate tile. Not part of the
                    // backend-editable content yet.
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'Digital Address: GL-126-7029',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ===== Get in Touch =====
                    _sectionLabel('Get in Touch'),
                    const SizedBox(height: 4),
                    const Text(
                      'Our response team is available 24 hours.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _contactTile(
                      icon: Icons.phone_outlined,
                      label: 'PHONE',
                      value: phone,
                      onTap: () =>
                          _launchUrl('tel:${phone.replaceAll(' ', '')}'),
                    ),
                    const SizedBox(height: 12),
                    _contactTile(
                      icon: Icons.local_phone_outlined,
                      label: 'EMERGENCY HOTLINE',
                      value: emergencyHotline,
                      onTap: () => _launchUrl(
                          'tel:${emergencyHotline.replaceAll(' ', '')}'),
                    ),
                    const SizedBox(height: 12),
                    _contactTile(
                      icon: Icons.email_outlined,
                      label: 'EMAIL',
                      value: email,
                      onTap: () => _launchUrl('mailto:$email'),
                    ),

                    const SizedBox(height: 32),

                    // ===== Follow Our Social Media Pages =====
                    _sectionLabel('Follow Our Social Media Pages'),
                    const SizedBox(height: 16),

                    // Explicit rows with identical natural-height tiles and
                    // identical SizedBox gaps throughout — a GridView here
                    // previously forced each 2-up cell to a fixed aspect
                    // ratio, which made those cells taller than the wide
                    // WhatsApp tile below them and made the gap between
                    // LinkedIn and WhatsApp look uneven next to the gap
                    // between Twitter and LinkedIn, even though both
                    // SizedBox gaps were the same value.
                    Row(
                      children: [
                        Expanded(
                          child: _socialTile(
                            assetPath: 'assets/icons/twitter_logo.png',
                            title: 'X (Twitter)',
                            url: twitterUrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _socialTile(
                            assetPath: 'assets/icons/instagram_logo.png',
                            title: 'Instagram',
                            url: instagramUrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _socialTile(
                            assetPath: 'assets/icons/linkedin_logo.png',
                            title: 'LinkedIn',
                            url: linkedinUrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _socialTile(
                            assetPath: 'assets/icons/facebook_logo.png',
                            title: 'Facebook',
                            url: facebookUrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _socialTileWide(
                      assetPath: 'assets/icons/whatsapp_logo.png',
                      title: 'Message Us on WhatsApp',
                      url: whatsappUrl,
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 16, width: 130),
            const SizedBox(height: 12),
            const SkeletonBox(height: 280, width: double.infinity, radius: 8),
            const SizedBox(height: 8),
            const SkeletonBox(height: 12, width: 160),
            const SizedBox(height: 32),
            const SkeletonBox(height: 16, width: 110),
            const SizedBox(height: 4),
            const SkeletonBox(height: 13, width: 200),
            const SizedBox(height: 16),
            for (var i = 0; i < 2; i++) ...[
              const SkeletonBox(height: 68, width: double.infinity, radius: 8),
              const SizedBox(height: 12),
            ],
            const SkeletonBox(height: 68, width: double.infinity, radius: 8),
            const SizedBox(height: 32),
            const SkeletonBox(height: 16, width: 220),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SkeletonBox(height: 48, radius: 8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonBox(height: 48, radius: 8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SkeletonBox(height: 48, radius: 8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonBox(height: 48, radius: 8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SkeletonBox(height: 54, width: double.infinity, radius: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F9),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 20, color: primaryBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _socialTile({
    required String assetPath,
    required String title,
    required String url,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(assetPath, width: 20, height: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialTileWide({
    required String assetPath,
    required String title,
    required String url,
  }) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(assetPath, width: 20, height: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
