import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps the native "phone call" and "send message" actions.
///
/// [call] places the call directly (Android's `ACTION_CALL`, requesting the
/// `CALL_PHONE` permission itself) rather than just opening the dialer. On
/// iOS this still falls back to the `tel:` scheme — Apple doesn't let any
/// third-party app place a call without the Phone app and user confirmation
/// in the loop, so there is no direct-call equivalent there.
///
/// [message] uses the `sms:` URI scheme via [url_launcher], handing off to
/// the device's own messaging app, since neither platform allows silently
/// sending a text either.
class ContactActions {
  const ContactActions._();

  static Future<bool> call(String phoneNumber) async {
    return await FlutterPhoneDirectCaller.callNumber(_sanitize(phoneNumber)) ??
        false;
  }

  static Future<bool> message(String phoneNumber, {String? body}) {
    return _launch(
      Uri(
        scheme: 'sms',
        path: _sanitize(phoneNumber),
        queryParameters: body == null ? null : {'body': body},
      ),
    );
  }

  static Future<bool> _launch(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri);
  }

  /// Strips everything except digits and a leading `+` — contacts are
  /// commonly stored with spaces, dashes, or parentheses (e.g.
  /// "(050) 123-4567"), which would otherwise get passed straight to the
  /// dialer/SMS intent and either fail to dial or dial the wrong digits.
  static String _sanitize(String phoneNumber) =>
      phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
}
