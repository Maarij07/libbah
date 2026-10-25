import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_display.dart';

/// Memoizes the device contact list for the lifetime of the app process.
///
/// `FlutterContacts.getAll()` is a real query against the OS contacts
/// provider — noticeably slow on devices with large address books. Since
/// the list rarely changes mid-session, every screen that needs it (the
/// main contacts list, the emergency-contact picker) shares one cached
/// fetch instead of re-querying every time it's opened.
class ContactsRepository {
  const ContactsRepository._();

  static List<Contact>? _cache;

  static Future<List<Contact>> getAll() async {
    final cached = _cache;
    if (cached != null) return cached;

    final contacts = await FlutterContacts.getAll(
      properties: {
        ContactProperty.name,
        ContactProperty.phone,
        ContactProperty.photoThumbnail,
      },
    );
    contacts.sort(
      (a, b) => contactDisplayName(
        a,
      ).toLowerCase().compareTo(contactDisplayName(b).toLowerCase()),
    );
    _cache = contacts;
    return contacts;
  }
}
