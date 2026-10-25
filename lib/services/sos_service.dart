import '../models/emergency_contact.dart';
import 'contact_actions.dart';

/// Texts every emergency contact, then calls the first one.
///
/// Shared by the in-screen SOS button and the physical SOS key so both
/// trigger the exact same behavior. [message] is the localized SOS text to
/// send — callers pass `AppLocalizations.of(context)!.sosMessage` so it
/// follows whatever language the contact's own phone displays this app in.
class SosService {
  const SosService._();

  static Future<void> trigger(
    List<EmergencyContact> contacts,
    String message,
  ) async {
    if (contacts.isEmpty) return;
    for (final contact in contacts) {
      await ContactActions.message(contact.phone, body: message);
    }
    await ContactActions.call(contacts.first.phone);
  }
}
