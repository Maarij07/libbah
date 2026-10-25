import 'package:flutter/services.dart';

/// Bridges to the native `DefaultLauncher` (Android only), which asks the
/// user to make Labbiah the device's default Home app — the only way for it
/// to come back on its own after a reboot or a Home press.
class DefaultLauncher {
  const DefaultLauncher._();

  static const _channel = MethodChannel('com.labbiah.labbiah/default_launcher');

  /// Shows the "Make Labbiah the home screen?" popup, unless Labbiah
  /// already is the default Home app.
  static Future<void> promptIfNeeded() async {
    try {
      final isDefault = await _channel.invokeMethod<bool>('isDefault');
      if (isDefault == true) return;
      await _channel.invokeMethod('showPrompt');
    } on PlatformException {
      // Nothing sensible to show on this app's read-only display.
    } on MissingPluginException {
      // e.g. web/desktop builds during development.
    }
  }
}
