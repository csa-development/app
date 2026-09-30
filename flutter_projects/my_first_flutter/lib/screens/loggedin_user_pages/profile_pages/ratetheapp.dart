import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../widgets/swipe_back.dart';
import '../../../widgets/top_toast.dart';

class RateAppPage extends StatefulWidget {
  const RateAppPage({super.key});

  @override
  State<RateAppPage> createState() => _RateAppPageState();
}

class _RateAppPageState extends State<RateAppPage> {
  static const Color tileBg = Color(0xFFF3F6F9);

  int _selectedRating = 0;
  bool _isSubmitting = false;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';
    final result = await ApiService.sendFeedback(
      accessToken: accessToken,
      category: 'APP_RATING',
      message: _reviewController.text.trim(),
      rating: _selectedRating,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success']) {
      showTopToast(context, 'Thanks for rating the app!', isError: false);
      Navigator.pop(context);
    } else {
      showTopToast(context, result['error'] ?? 'Failed to submit rating');
    }
  }

  final List<String> _labels = [
    'Terrible',
    'Poor',
    'Average',
    'Good',
    'Excellent',
  ];

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
          'Rate the App',
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
            const SizedBox(height: 16),

            const Center(
              child: Text(
                'How would you rate\nyour experience?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Your feedback helps us improve the app',
                style: TextStyle(fontSize: 14, color: Colors.black45),
              ),
            ),

            const SizedBox(height: 40),

            // ===== Stars =====
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final isSelected = index < _selectedRating;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      isSelected ? Icons.star : Icons.star_outline,
                      size: 44,
                      color: isSelected ? Colors.amber : Colors.black26,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            if (_selectedRating > 0)
              Center(
                child: Text(
                  _labels[_selectedRating - 1],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            const Text(
              'Add a comment (optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _reviewController,
                maxLines: 4,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Tell us what you think...',
                  hintStyle: TextStyle(color: Colors.black38),
                ),
              ),
            ),

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
                onPressed: (_selectedRating == 0 || _isSubmitting)
                    ? null
                    : _submitRating,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SUBMIT RATING',
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
      ),
    );
  }
}
