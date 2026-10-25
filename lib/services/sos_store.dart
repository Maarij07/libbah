import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';

/// Persists the small list of emergency contacts used by the SOS screen.
class SosStore {
  const SosStore._();

  static const _key = 'sos_contacts';

  static Future<List<EmergencyContact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(contacts.map((c) => c.toJson()).toList()),
    );
  }
}
