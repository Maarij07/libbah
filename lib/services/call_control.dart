import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PhoneCallState { ringing, dialing, active }

/// A phone call Labbiah is showing, as reported by the native `CallCenter`.
class PhoneCall {
  const PhoneCall({
    required this.state,
    required this.number,
    this.name,
    this.photo,
    this.connectedAt,
    this.speaker = false,
  });

  final PhoneCallState state;
  final String number;

  /// The saved contact's name, if the number belongs to one.
  final String? name;

  /// The saved contact's picture, if it has one.
  final Uint8List? photo;

  /// When the call was picked up; null until it is.
  final DateTime? connectedAt;

  /// Whether the call is on loudspeaker rather than the earpiece — set
  /// with the phone's Volume Up / Volume Down buttons during the call.
  final bool speaker;

  static PhoneCall? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final connectedAt = raw['connectedAt'] as int? ?? 0;
    return PhoneCall(
      state: switch (raw['state']) {
        'ringing' => PhoneCallState.ringing,
        'active' => PhoneCallState.active,
        _ => PhoneCallState.dialing,
      },
      number: raw['number'] as String? ?? '',
      name: raw['name'] as String?,
      photo: raw['photo'] as Uint8List?,
      speaker: raw['speaker'] == true,
      connectedAt: connectedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(connectedAt)
          : null,
    );
  }
}

/// Someone who rang and wasn't answered, with how many times they tried.
class MissedCall {
  const MissedCall({
    required this.number,
    required this.count,
    this.name,
    this.photo,
  });

  /// Empty when the caller hid their number — there is no one to ring back.
  final String number;
  final int count;

  /// The saved contact's name, if the number belongs to one.
  final String? name;

  /// The saved contact's picture, if it has one.
  final Uint8List? photo;

  factory MissedCall.fromMap(Map<Object?, Object?> raw) => MissedCall(
    number: raw['number'] as String? ?? '',
    count: raw['count'] as int? ?? 1,
    name: raw['name'] as String?,
    photo: raw['photo'] as Uint8List?,
  );
}

/// Bridges to the native call handling (Android only).
///
/// When Labbiah is the phone's default Phone app, Android hands it every
/// call: [current] then holds the call to draw (see `CallScreen`), and the
/// case's Call and Hang-up keys answer and end it.
///
/// When it isn't, the phone's own dialer shows the call and [current]
/// stays null, but the same two keys still work — here while Labbiah is on
/// screen, and through the native `CallCaseOverlay` once the dialer's call
/// screen covers it.
class CallControl {
  const CallControl._();

  static const _channel = MethodChannel('com.labbiah.labbiah/call_control');

  /// The call Labbiah is showing, or null when there is none.
  static final current = ValueNotifier<PhoneCall?>(null);

  /// Called whenever a call ends, whoever was showing it.
  static VoidCallback? onCallEnded;

  /// Starts listening for calls, picking up one already in progress.
  static Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'callChanged') return;
      current.value = PhoneCall.fromMap(call.arguments);
      if (current.value == null) onCallEnded?.call();
    });
    try {
      current.value = PhoneCall.fromMap(
        await _channel.invokeMethod<Object?>('currentCall'),
      );
    } on PlatformException {
      // No call to show.
    } on MissingPluginException {
      // e.g. iOS, or web/desktop builds during development.
    }
  }

  /// Everyone with unanswered calls, newest first — see the native
  /// `MissedCalls` for when a caller drops off the list. Throws a
  /// [PlatformException] if call history access hasn't been granted.
  static Future<List<MissedCall>> missedCalls() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('missedCalls');
      return [
        for (final entry in raw ?? const <Object?>[])
          if (entry is Map) MissedCall.fromMap(entry),
      ];
    } on MissingPluginException {
      // e.g. iOS, or web/desktop builds during development.
      return [];
    }
  }

  /// Picks up an incoming call. Returns false if nothing is ringing.
  static Future<bool> answerIfRinging() => _invoke('answerIfRinging');

  /// Ends the current call, or rejects it if it is still ringing. Returns
  /// false if there is no call.
  static Future<bool> endIfInCall() => _invoke('endIfInCall');

  static Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // e.g. iOS, or web/desktop builds during development.
      return false;
    }
  }
}
