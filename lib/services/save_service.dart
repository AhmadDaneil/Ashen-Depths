import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SaveService {
  static const _key = 'save';
  SharedPreferences? _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
  }

  Map<String, dynamic>? load() {
    final raw = _preferences?.getString(_key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Map<String, Object?> data) async {
    await _preferences?.setString(_key, jsonEncode(data));
  }
}
