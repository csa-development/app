import 'package:flutter/material.dart';

/// "Registered" / "Checked In" marker drawn in the bottom-right corner of an
/// event or campaign image. It has no background of its own — it sits
/// directly on the image's dark bottom gradient, hence the white text.
class RegisteredPill extends StatelessWidget {
  final bool checkedIn;

  const RegisteredPill({super.key, required this.checkedIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checkedIn ? Icons.verified : Icons.check_circle,
            size: 14,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            checkedIn ? 'Checked In' : 'Registered',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
