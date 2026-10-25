import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to Quick Switch (Android only):
///  - Leaving Labbiah: hold the case's Home key and the physical Volume Up
///    button together for 5 seconds (native `HomeVolumeCombo`). This class
///    reports the Home key's held state, since only Flutter can see it.
///  - Returning to Labbiah: hold Volume Up for 12 seconds anywhere (native
///    `QuickSwitchAccessibilityService`), which needs a one-time setup step
///    a human must do in Settings (no app can grant itself accessibility
///    access).
class QuickSwitch {
  const QuickSwitch._();

  static const _channel = MethodChannel('com.labbiah.labbiah/quick_switch');

  /// Whether the case's Home key is being held right now.
  static final homeHeld = ValueNotifier<bool>(false);

  /// Whether the physical Volume Up button is being held right now, as
  /// reported by the native side. Shown on screen, together with
  /// [homeHeld], so it's visible that the two-button hold is registering.
  static final volumeUpHeld = ValueNotifier<bool>(false);

  /// Starts listening for the native side's Volume Up reports.
  static void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpChanged') {
        volumeUpHeld.value = call.arguments == true;
      }
    });
  }

  static Future<void> promptIfNeeded() async {
    try {
      await _channel.invokeMethod<void>('promptIfNeeded');
    } on PlatformException {
      // Setup is unavailable on this platform.
    } on MissingPluginException {
      // Android only.
    }
  }

  /// How long the Home key must be held, without Volume Up, to count as
  /// the hidden "open Quick Switch setup" gesture.
  static const _setupHold = Duration(milliseconds: 800);

  static final _homeHold = Stopwatch();

  /// Fingers currently on the Home key. Shaky or two-finger presses are
  /// common for elderly users, and the key only counts as released once
  /// the last of them lifts.
  static var _homePointers = 0;
  static var _homeHoldCancelled = false;

  static Future<void> homeKeyDown() async {
    if (_homePointers++ > 0) return;
    homeHeld.value = true;
    _homeHoldCancelled = false;
    _homeHold
      ..reset()
      ..start();
    await _setHomeHeld(true);
  }

  /// [cancelled] is true when the touch was interrupted (e.g. Labbiah left
  /// the screen because the combo fired) rather than lifted normally.
  static Future<void> homeKeyUp({bool cancelled = false}) async {
    if (_homePointers == 0) return;
    _homeHoldCancelled |= cancelled;
    if (--_homePointers > 0) return;
    homeHeld.value = false;
    _homeHold.stop();
    final usedVolumeUp = await _setHomeHeld(false);
    if (!_homeHoldCancelled &&
        !usedVolumeUp &&
        _homeHold.elapsed >= _setupHold) {
      await _openAccessibilitySettings();
    }
  }

  /// Returns whether Volume Up was pressed during this Home hold.
  static Future<bool> _setHomeHeld(bool held) async {
    try {
      return await _channel.invokeMethod<bool>('setHomeHeld', held) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens Android's Accessibility settings list so whoever is setting up
  /// the phone can find "Labbiah Quick Switch" and turn it on.
  static Future<void> _openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException {
      // Nothing sensible to show on this app's read-only display if the
      // platform call fails (e.g. running on a non-Android platform).
    } on MissingPluginException {
      // Same — e.g. web/desktop builds during development.
    }
  }
}
