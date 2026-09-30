import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Shared local-bookmark storage for content types that don't have a
/// backend bookmark endpoint (campaigns, press releases, events).
///
/// Each type gets two SharedPreferences keys: an id list (fast
/// membership checks) and a JSON-data list (so the Bookmarks page can
/// render a tile without re-fetching from the API). Key names match
/// what campaign_details.dart / press_release_detail.dart already used
/// before this existed, so previously-saved bookmarks aren't lost.
class BookmarkService {
  static String _idsKey(String type) => 'bookmarked_${type}s';
  static String _dataKey(String type) => 'bookmarked_${type}s_data';

  static Future<bool> isBookmarked(String type, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_idsKey(type)) ?? [];
    return ids.contains(id);
  }

  static Future<Set<String>> loadIds(String type) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_idsKey(type)) ?? []).toSet();
  }

  /// Toggles the bookmark for [item] (must contain an 'id' field) and
  /// returns the new bookmarked state.
  static Future<bool> toggle(String type, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final id = item['id'].toString();
    final List<String> ids = prefs.getStringList(_idsKey(type)) ?? [];
    final List<String> data = prefs.getStringList(_dataKey(type)) ?? [];

    final bool wasBookmarked = ids.contains(id);
    if (wasBookmarked) {
      ids.remove(id);
      data.removeWhere((s) => jsonDecode(s)['id'].toString() == id);
    } else {
      ids.add(id);
      data.add(jsonEncode({...item, 'bookmark_type': type}));
    }

    await prefs.setStringList(_idsKey(type), ids);
    await prefs.setStringList(_dataKey(type), data);
    return !wasBookmarked;
  }

  static Future<List<Map<String, dynamic>>> loadData(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_dataKey(type)) ?? [];
    return data
        .map((s) => Map<String, dynamic>.from(jsonDecode(s)))
        .toList();
  }
}
