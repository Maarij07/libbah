import 'package:flutter/material.dart';

import '../screens/call_screen.dart';
import '../screens/home_screen.dart';
import '../screens/missed_calls_screen.dart';
import '../screens/sos_screen.dart';
import '../services/call_control.dart';
import '../services/default_launcher.dart';
import '../services/quick_switch.dart';
import '../theme/app_colors.dart';
import 'phone_case.dart';
import 'phone_shell_controller.dart';
import 'phone_shell_scope.dart';

/// The permanent frame every screen renders inside: a display area on top
/// (touch-disabled — it's read-only) and the physical button case fixed at
/// the bottom, present on every screen.
///
/// Navigation between screens happens on a [Navigator] nested inside the
/// display area, so the case never rebuilds or moves as screens change.
///
/// A phone call covers the display area with [CallScreen] for as long as
/// it lasts; when it ends, Labbiah is back on its home screen.
class PhoneShell extends StatefulWidget {
  const PhoneShell({super.key});

  @override
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> {
  final _controller = PhoneShellController();

  @override
  void initState() {
    super.initState();
    // Asked once per app start (not on every resume) so "Not now" sticks
    // for the rest of the session.
    DefaultLauncher.promptIfNeeded();
    // Wherever the person was when the call came in, they finish on Home.
    CallControl.onCallEnded = _controller.pressHome;
    CallControl.start();
    QuickSwitch.start();
    QuickSwitch.promptIfNeeded();
  }

  @override
  void dispose() {
    CallControl.onCallEnded = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhoneShellScope(
      controller: _controller,
      // Android's own Back (button or edge swipe) must never close Labbiah
      // and drop the person onto the phone's launcher: the case's keys are
      // the only way around, and Quick Switch the only way out.
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: IgnorePointer(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Navigator(
                              key: _controller.navigatorKey,
                              observers: [_controller.routeObserver],
                              onGenerateRoute: (settings) {
                                final builder = switch (settings.name) {
                                  '/sos' =>
                                    (BuildContext _) => const SosScreen(),
                                  '/missed' =>
                                    (BuildContext _) =>
                                        const MissedCallsScreen(),
                                  _ => (BuildContext _) => const HomeScreen(),
                                };
                                return MaterialPageRoute(
                                  builder: builder,
                                  settings: settings,
                                );
                              },
                            ),
                            ValueListenableBuilder(
                              valueListenable: CallControl.current,
                              builder: (context, call, _) => call == null
                                  ? const SizedBox.shrink()
                                  : CallScreen(call: call),
                            ),
                            ValueListenableBuilder(
                              valueListenable: QuickSwitch.volumeUpHeld,
                              builder: (context, held, _) => held
                                  ? const _VolumeUpPressed()
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: PhoneCase(controller: _controller),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the physical Volume Up button as pressed, on the edge of the
/// screen it sits on — the on-screen counterpart to the Home key lighting
/// up, so the Home + Volume Up hold can be seen registering.
class _VolumeUpPressed extends StatelessWidget {
  const _VolumeUpPressed();

  @override
  Widget build(BuildContext context) {
    return Align(
      // The button is on the phone's right-hand side in every language.
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3B4CA8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.volume_up, color: Colors.white, size: 44),
      ),
    );
  }
}
