import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../widgets/swipe_back.dart';
import '../../../widgets/top_toast.dart';

class SendFeedbackPage extends StatefulWidget {
  const SendFeedbackPage({super.key});

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  int _selectedCategory = 0;
  bool _isLoading = false;
  final _feedbackController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {
      'icon': Icons.bug_report_outlined,
      'label': 'Bug Report',
      'value': 'BUG_REPORT',
    },
    {
      'icon': Icons.lightbulb_outlined,
      'label': 'Suggestion',
      'value': 'SUGGESTION',
    },
    {'icon': Icons.help_outline, 'label': 'Question', 'value': 'QUESTION'},
    {
      'icon': Icons.thumb_up_outlined,
      'label': 'Compliment',
      'value': 'COMPLIMENT',
    },
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    if (_feedbackController.text.trim().isEmpty) {
      showTopToast(context, 'Please write your feedback before submitting');
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';
    final category = _categories[_selectedCategory]['value'] as String;

    final result = await ApiService.sendFeedback(
      accessToken: accessToken,
      category: category,
      message: _feedbackController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      showTopToast(
        context,
        'Feedback submitted successfully. Thank you!',
        isError: false,
      );
      Navigator.pop(context);
    } else {
      showTopToast(context, result['error'] ?? 'Failed to send feedback');
    }
  }

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
          'Send Feedback',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
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
            const SizedBox(height: 8),

            const Text(
              'What is your feedback about?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 16),

            // ===== Category Selector =====
            Row(
              children: List.generate(_categories.length, (index) {
                final isSelected = index == _selectedCategory;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = index),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index < _categories.length - 1 ? 8 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? primaryBlue
                              : const Color(0xFFE4E6EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _categories[index]['icon'] as IconData,
                            size: 22,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _categories[index]['label'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            const Text(
              'Your Feedback',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 6,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Describe your feedback in detail...',
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
                onPressed: _isLoading ? null : _sendFeedback,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SEND FEEDBACK',
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
