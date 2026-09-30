import 'package:flutter/material.dart';

/// Parses a "#RRGGBB" hex string (as returned by the report-status API)
/// into a Color, falling back to [fallback] for anything malformed or
/// empty — a status the app doesn't recognize should still render with
/// a sensible neutral color, never crash or look broken.
Color hexToColor(String? hex, {Color fallback = const Color(0xFF6B7280)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
