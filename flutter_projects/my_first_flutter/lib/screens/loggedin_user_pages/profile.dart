import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/local_image.dart';
import '../continue_login_flow.dart';
import 'profile_pages/change_password.dart';
import 'profile_pages/edit_profile.dart';
import 'profile_pages/privacy_policy.dart';
import 'profile_pages/ratetheapp.dart';
import 'profile_pages/secondfeedback.dart';
import 'profile_pages/termsandconditions.dart';

class LoggedInProfile extends StatefulWidget {
  const LoggedInProfile({super.key});

  @override
  State<LoggedInProfile> createState() => _LoggedInProfileState();
}

class _LoggedInProfileState extends State<LoggedInProfile>
    with WidgetsBindingObserver {
  static const Color primaryBlue = Color(0xFF00334D);

  String _fullName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadProfileImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
      _loadProfileImage();
    }
  }

  Future<void> _loadUserData() async {
    final fullName = await AuthStorage.getFullName();
    setState(() {
      _fullName = fullName ?? 'User';
    });
  }

  Future<void> _loadProfileImage() async {
    await AuthStorage.getProfileImagePath();
  }

  Future<void> _navigateAndRefresh(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _loadUserData();
    _loadProfileImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Blue Header =====
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: ClipOval(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: AuthStorage.profileImageNotifier,
                        builder: (context, path, _) {
                          return path != null
                              ? localImage(
                                  path,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: primaryBlue,
                                );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 64),

            // ===== User Info =====
            Center(
              child: Text(
                _fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('ACCOUNT'),
                  const SizedBox(height: 12),
                  _profileTile(
                    context,
                    Icons.person_outline,
                    'Edit Profile',
                    const EditProfilePage(),
                  ),
                  _profileTile(
                    context,
                    Icons.lock_outline,
                    'Change Password',
                    const ChangePasswordPage(),
                  ),

                  const SizedBox(height: 12),
                  _sectionLabel('APP'),
                  const SizedBox(height: 12),
                  _profileTile(
                    context,
                    Icons.star_outline,
                    'Rate the App',
                    const RateAppPage(),
                  ),
                  _profileTile(
                    context,
                    Icons.feedback_outlined,
                    'Send Feedback',
                    const SendFeedbackPage(),
                  ),

                  const SizedBox(height: 12),
                  _sectionLabel('LEGAL'),
                  const SizedBox(height: 12),
                  _profileTile(
                    context,
                    Icons.privacy_tip_outlined,
                    'Privacy Policy',
                    const PrivacyPolicyPage(),
                  ),
                  _profileTile(
                    context,
                    Icons.description_outlined,
                    'Terms of Use',
                    const TermsOfUsePage(),
                  ),

                  const SizedBox(height: 20),

                  // ===== Logout =====
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: () async {
                        await ApiService.logout();
                        await AuthStorage.clearSession();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContinueLoginFlow(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'LOGOUT',
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
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.black38,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _profileTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget destination,
  ) {
    return GestureDetector(
      onTap: () => _navigateAndRefresh(destination),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }
}