import 'package:flutter/material.dart';

import '../services/call_control.dart';
import '../services/contact_actions.dart';
import '../services/sos_store.dart';
import 'button_navigable.dart';

/// Owns the nested [Navigator] and routes physical-button presses to
/// whichever screen is currently on top of it.
///
/// Home, Hang-up, and SOS are global: they act on the navigation stack (or,
/// for SOS, on the emergency-contact list) directly rather than through the
/// active screen. Up / Down / Call are forwarded to the active screen's
/// [ButtonNavigable] implementation, if it has one.
///
/// Hang-up goes back one screen; on Home, where there is nothing to go
/// back to, it opens Missed Calls instead.
///
/// A phone call takes priority over all of that: while one is ringing, Call
/// answers it, and while one is ringing or in progress, Hang-up ends it.
/// While Labbiah's own call screen is up, Up / Down / Call don't reach the
/// screen hidden behind it.
class PhoneShellController {
  final navigatorKey = GlobalKey<NavigatorState>();
  final routeObserver = RouteObserver<ModalRoute<void>>();

  ButtonNavigable? _activeHandler;

  void register(ButtonNavigable handler) => _activeHandler = handler;

  void unregister(ButtonNavigable handler) {
    if (identical(_activeHandler, handler)) _activeHandler = null;
  }

  bool get _showingCall => CallControl.current.value != null;

  void pressUp() {
    if (!_showingCall) _activeHandler?.moveHighlightUp();
  }

  void pressDown() {
    if (!_showingCall) _activeHandler?.moveHighlightDown();
  }

  Future<void> pressCall() async {
    if (await CallControl.answerIfRinging()) return;
    if (!_showingCall) _activeHandler?.confirmHighlighted();
  }

  void pressHome() {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> pressHangup() async {
    if (await CallControl.endIfInCall()) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Nothing to go back from on Home, so the key shows who called.
      navigator.pushNamed('/missed');
    }
  }

  Future<void> pressSos() async {
    final contacts = await SosStore.load();
    if (contacts.length != 1) {
      navigatorKey.currentState?.pushNamed('/sos');
      return;
    }
    await ContactActions.call(contacts.single.phone);
  }
}
