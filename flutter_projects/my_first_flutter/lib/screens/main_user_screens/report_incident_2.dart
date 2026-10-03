import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../services/api_service.dart';
import '../../services/auth_storage.dart';
import '../../widgets/local_image.dart';
import '../../widgets/swipe_back.dart';
import '../../widgets/top_toast.dart';
import 'location_picker.dart';
import 'report_not_successful.dart';
import 'report_successful.dart';

class ReportIncident2Screen extends StatefulWidget {
  final String incidentType;
  final String reporterName;
  final String description;
  final String dateOfIncident;

  const ReportIncident2Screen({
    super.key,
    required this.incidentType,
    required this.reporterName,
    required this.description,
    required this.dateOfIncident,
  });

  @override
  State<ReportIncident2Screen> createState() => _ReportIncident2ScreenState();
}

class _ReportIncident2ScreenState extends State<ReportIncident2Screen> {
  static const Color primaryBlue = Color(0xFF00334D);

  bool isConfirmed = false;
  bool _isLoading = false;
  XFile? _selectedFile;
  double? _latitude;
  double? _longitude;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillFromAccount();
  }

  Future<void> _prefillFromAccount() async {
    final email = await AuthStorage.getEmail();
    final phone = await AuthStorage.getPhone();
    if (!mounted) return;
    setState(() {
      emailController.text = email ?? '';
      phoneController.text = phone ?? '';
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    ageController.dispose();
    super.dispose();
  }

  /// Camera/gallery access can fail for reasons outside the app's
  /// control (permission denied, no camera app installed, etc.) —
  /// previously this failed silently with no feedback, which is
  /// indistinguishable from "the camera doesn't work" to a user.
  // Matches the server's limit (incidents/views.py) so a too-big video is
  // refused straight away instead of after a long upload.
  static const int _maxEvidenceBytes = 100 * 1024 * 1024;

  Future<void> _acceptPickedFile(XFile? file) async {
    if (file == null) return;
    final size = await file.length();
    if (!mounted) return;
    if (size > _maxEvidenceBytes) {
      showTopToast(
        context,
        'That file is too large. Please choose one under 100 MB.',
      );
      return;
    }
    setState(() => _selectedFile = file);
  }

  Future<XFile?> _pickImageSafely(ImageSource source) async {
    try {
      return await _picker.pickImage(source: source, imageQuality: 80);
    } on PlatformException catch (e) {
      if (!mounted) return null;
      if (e.code == 'camera_access_denied' ||
          e.code == 'photo_access_denied') {
        showTopToast(
          context,
          'Permission denied. Enable camera/photo access for this app in your phone\'s Settings.',
        );
      } else {
        showTopToast(context, 'Could not access the camera. Please try again.');
      }
      return null;
    } catch (e) {
      if (!mounted) return null;
      showTopToast(context, 'Could not access the camera. Please try again.');
      return null;
    }
  }

  Future<void> _showUploadOptions() async {
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
              const Text(
                'Upload Evidence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: primaryBlue),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _pickImageSafely(ImageSource.gallery);
                  await _acceptPickedFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined,
                    color: primaryBlue),
                title: const Text('Choose Video from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  XFile? file;
                  try {
                    file = await _picker.pickVideo(source: ImageSource.gallery);
                  } catch (e) {
                    if (!mounted) return;
                    showTopToast(
                      context,
                      'Could not access the gallery. Please try again.',
                    );
                    return;
                  }
                  await _acceptPickedFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: primaryBlue),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _pickImageSafely(ImageSource.camera);
                  await _acceptPickedFile(file);
                },
              ),
              if (_selectedFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  title: const Text(
                    'Remove file',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedFile = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );

    if (result == null || !mounted) return;

    setState(() {
      locationController.text = result['address'] as String;
      _latitude = result['latitude'] as double?;
      _longitude = result['longitude'] as double?;
    });
  }

  Future<void> _submitReport() async {
    if (emailController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter your email');
      return;
    }

    if (phoneController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter your phone number');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter your location');
      return;
    }

    if (ageController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter your age');
      return;
    }

    if (!isConfirmed) {
      showTopToast(context, 'Please confirm the information is accurate');
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';

    final result = await ApiService.submitReport(
      accessToken: accessToken,
      incidentType: widget.incidentType,
      platform: 'MobApp-CSA',
      description: widget.description,
      dateOfIncident: widget.dateOfIncident,
      location: locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      reporterName: widget.reporterName,
      reporterPhone: phoneController.text.trim(),
      reportingForSomeone: false,
      evidenceDescription: _selectedFile?.name ?? '',
      evidenceFile: _selectedFile != null && !kIsWeb
          ? File(_selectedFile!.path)
          : null,
      evidenceBytes: _selectedFile != null && kIsWeb
          ? await _selectedFile!.readAsBytes()
          : null,
      evidenceFilename: _selectedFile?.name ?? 'evidence',
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      final refNumber =
          result['data']['reference_number'] ?? 'CSA-000000';
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) =>
              ReportSuccessfulScreen(referenceNumber: refNumber),
        ),
      );
    } else {
      // Full failure screen — it keeps a back arrow so the reporter can
      // return here, fix things, and resubmit (nothing was sent).
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (_) => ReportNotSuccessfulScreen(
            errorMessage: result['error']?.toString(),
          ),
        ),
      );
    }
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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Report Incident',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Email'),
            const SizedBox(height: 6),
            _textField(
                controller: emailController,
                hint: 'Enter your email'),

            const SizedBox(height: 16),

            _label('Phone Number'),
            const SizedBox(height: 6),
            _textField(
              controller: phoneController,
              hint: 'Enter your phone number',
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),

            _label('Location'),
            const SizedBox(height: 6),
            _textField(
              controller: locationController,
              hint: 'Enter your location or pick it on the map',
              onMapTap: _pickLocation,
            ),

            const SizedBox(height: 16),

            _label('Age'),
            const SizedBox(height: 6),
            _textField(
              controller: ageController,
              hint: 'Enter your age',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 18),

            const Text(
              'Upload Evidence (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),

            _uploadBox(),

            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isConfirmed,
                      activeColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (value) {
                        setState(() {
                          isConfirmed = value ?? false;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I confirm that the information provided is accurate and true to the best of my knowledge.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _isLoading ? null : _submitReport,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        'SUBMIT REPORT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onMapTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
          suffixIcon: onMapTap == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.map_outlined,
                      color: primaryBlue, size: 22),
                  tooltip: 'Pick on map',
                  onPressed: onMapTap,
                ),
        ),
      ),
    );
  }

  static const Set<String> _videoExtensions = {
    'mp4', 'mov', 'webm', 'mkv', 'avi', '3gp', 'm4v',
  };

  bool get _selectedIsVideo {
    final file = _selectedFile;
    if (file == null) return false;
    if (file.mimeType?.startsWith('video/') ?? false) return true;
    // name, not path: in a browser the path is a temporary link with no
    // extension, while the name still carries the original one.
    final name = file.name.toLowerCase();
    final dot = name.lastIndexOf('.');
    return dot != -1 && _videoExtensions.contains(name.substring(dot + 1));
  }

  Widget _uploadBox() {
    return GestureDetector(
      onTap: _showUploadOptions,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E6EB)),
        ),
        child: _selectedFile != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedIsVideo
                        ? _VideoPreview(
                            key: ValueKey(_selectedFile!.path),
                            path: _selectedFile!.path,
                          )
                        : localImage(
                            _selectedFile!.path,
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _uploadPlaceholder(),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _selectedFile!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              )
            : _uploadPlaceholder(),
      ),
    );
  }

  Widget _uploadPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file_outlined,
              size: 26, color: Colors.black45),
          SizedBox(height: 6),
          Text(
            'Tap to upload image or video',
            style: TextStyle(color: Colors.black45, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Shows the first frame of a picked video, with a play badge on top, so
/// a chosen video fills the upload box the same way a chosen photo does.
/// Never plays — it only needs to decode one frame. If the frame can't be
/// decoded, the dark tile with the play badge is still shown.
class _VideoPreview extends StatefulWidget {
  final String path;

  const _VideoPreview({super.key, required this.path});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // In a browser the picked video is a temporary web link, not a file.
    _controller = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
        : VideoPlayerController.file(File(widget.path));
    _controller.initialize().then((_) async {
      await _controller.seekTo(Duration.zero);
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (_ready)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}