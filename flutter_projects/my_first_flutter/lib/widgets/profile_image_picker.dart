import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/auth_storage.dart';
import 'top_toast.dart';

const Color _primaryBlue = Color(0xFF00334D);

/// Shows the "Take Photo / Choose from Gallery" bottom sheet used for
/// the profile picture on Home, Profile, and Edit Profile — one
/// shared implementation so all three stay in sync and behave
/// identically, instead of three separate pickers drifting apart.
Future<void> showProfileImagePicker(BuildContext context) async {
  final picker = ImagePicker();

  Future<void> pick(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        // image_picker's returned path points at a temporary/cache
        // file — the OS is free to clear it at any time (and often
        // does between app sessions), which was silently losing the
        // profile picture. Copy it into this app's own permanent
        // documents directory and save THAT path instead, so it
        // actually survives logging out, restarting the app, etc.
        final docsDir = await getApplicationDocumentsDirectory();
        final extension = picked.path.contains('.')
            ? picked.path.substring(picked.path.lastIndexOf('.'))
            : '.jpg';
        final savedPath =
            '${docsDir.path}/profile_picture${DateTime.now().millisecondsSinceEpoch}$extension';
        await File(picked.path).copy(savedPath);
        await AuthStorage.saveProfileImage(savedPath);
      }
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied') {
        showTopToast(
          context,
          "Permission denied. Enable camera/photo access for this app "
          "in your phone's Settings.",
        );
      } else {
        showTopToast(context, 'Could not access the camera. Please try again.');
      }
    } catch (_) {
      if (!context.mounted) return;
      showTopToast(context, 'Could not access the camera. Please try again.');
    }
  }

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
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
            const Text(
              'Update Profile Photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: _primaryBlue),
              title: const Text('Take Photo'),
              onTap: () => pick(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: _primaryBlue),
              title: const Text('Choose from Gallery'),
              onTap: () => pick(ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
}
