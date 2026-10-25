import 'package:flutter_contacts/flutter_contacts.dart';

/// Best-effort display text for a contact.
///
/// The system [Contact.displayName] is usually present, but some contacts
/// (SIM-only entries, partially-synced accounts) come back with it empty.
/// Falls back to the structured name, then the first phone number, so a
/// contact never shows as a dead-end "Unknown" when it's actually callable.
String contactDisplayName(Contact contact) {
  final displayName = contact.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  final name = contact.name;
  if (name != null) {
    final joined = [
      name.first,
      name.last,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ').trim();
    if (joined.isNotEmpty) return joined;
  }

  if (contact.phones.isNotEmpty) return contact.phones.first.number;

  return 'Unknown';
}
