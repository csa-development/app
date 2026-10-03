import 'package:flutter/material.dart';

/// One round "glass" shortcut on the Home screen: a pearly frosted circle
/// with a thin cool edge, holding a thin black icon, with its label
/// underneath. No shadow and no coloured glow; the edge keeps it visible on
/// the plain page, so it needs no panel behind it.
class QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const Color iconColor = Colors.black;

  // Bright at the top-left, a cool pale grey-blue at the bottom-right, like
  // light catching glass.
  static const List<Color> bodyColors = [Colors.white, Color(0xFFDCE3EC)];

  // The thin edge that defines the circle on the plain page.
  static const Color edgeColor = Color(0xFFC9D2DE);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bodyColors,
              ),
              border: Border.all(color: edgeColor, width: 1),
            ),
            child: Center(child: Icon(icon, color: iconColor, size: 24)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
