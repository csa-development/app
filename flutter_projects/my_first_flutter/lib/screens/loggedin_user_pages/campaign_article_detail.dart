import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../widgets/swipe_back.dart';

class CampaignArticleDetailPage extends StatelessWidget {
  final Map<String, dynamic> campaign;

  const CampaignArticleDetailPage({super.key, required this.campaign});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  Widget build(BuildContext context) {
    final String title = campaign['title'] ?? '';
    final String description = campaign['description'] ?? '';
    final String? imageUrl = campaign['image'];
    final String startDate = campaign['start_date'] ?? '';
    final String endDate = campaign['end_date'] ?? '';
    final String targetAudience = campaign['target_audience'] ?? '';
    final String categoryDisplay = campaign['category_display'] ?? '';
    final String dates = endDate.isNotEmpty
        ? '$startDate — $endDate'
        : startDate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SwipeBack(
        child: CustomScrollView(
        slivers: [
          // ===== Image Header =====
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: primaryBlue,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                ),
                onPressed: () => Share.share(
                  '$title\n\n${ApiService.publicWebBaseUrl}/campaigns/${campaign['id']}/',
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // ===== Image =====
                  imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: primaryBlue),
                        )
                      : Container(color: primaryBlue),

                  // ===== Gradient =====
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),

                  // ===== Date at top left =====
                  if (dates.isNotEmpty)
                    Positioned(
                      top: 100,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dates,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Category Badge =====
                  if (categoryDisplay.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoryDisplay.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ===== Title =====
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== Info Rows =====
                  if (targetAudience.isNotEmpty)
                    _infoRow(
                      Icons.people_outline,
                      'Target Audience',
                      targetAudience,
                    ),

                  const SizedBox(height: 16),

                  const Divider(color: Color(0xFFE4E6EB)),

                  const SizedBox(height: 16),

                  // ===== Description =====
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ===== Issued By =====
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE4E6EB)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organised by',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Cyber Security Authority',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Republic of Ghana',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
