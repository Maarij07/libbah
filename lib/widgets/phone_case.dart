import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/quick_switch.dart';
import 'call_icon.dart';
import 'phone_shell_controller.dart';

/// The persistent physical-button bar shown at the bottom of every screen.
///
/// This is the only part of the app that responds to touch: Hang-up (back),
/// Home, Call (confirm), Up, SOS, and Down.
///
/// The keys sit under fixed physical buttons on the case, so their order is
/// always left-to-right, even in RTL languages like Arabic — only the text
/// inside each key follows the reading direction.
class PhoneCase extends StatelessWidget {
  const PhoneCase({super.key, required this.controller});

  final PhoneShellController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE4E4E4),
        border: Border(top: BorderSide(color: Colors.grey.shade400, width: 1)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CaseKey(
                  key: const ValueKey('case-hangup'),
                  icon: Icons.call_end,
                  iconColor: const Color(0xFFD8433C),
                  onPressed: controller.pressHangup,
                  semanticLabel: l10n.caseHangup,
                ),
                ValueListenableBuilder(
                  valueListenable: QuickSwitch.homeHeld,
                  builder: (context, held, _) => _CaseKey(
                    key: const ValueKey('case-home'),
                    icon: Icons.home,
                    iconColor: held ? Colors.white : const Color(0xFF4A4A4A),
                    // Lit up for as long as it is held, so a Quick Switch
                    // hold is visibly registering.
                    color: held ? const Color(0xFF3B4CA8) : Colors.white,
                    onPressed: controller.pressHome,
                    // Quick Switch: holding this key together with the
                    // physical Volume Up for 5 s leaves Labbiah. Holding it
                    // alone and releasing opens Android's Accessibility
                    // settings so a caregiver can turn on the way back (see
                    // QuickSwitch). A plain tap is completely unaffected.
                    onHoldStart: QuickSwitch.homeKeyDown,
                    onHoldEnd: QuickSwitch.homeKeyUp,
                    onHoldCancel: () => QuickSwitch.homeKeyUp(cancelled: true),
                    // Keeps a long hold from also counting as a tap on release.
                    onLongPress: () {},
                    semanticLabel: l10n.caseHome,
                  ),
                ),
                _CaseKey(
                  key: const ValueKey('case-call'),
                  onPressed: controller.pressCall,
                  semanticLabel: l10n.caseCall,
                  // Samsung's own green "C" call badge, not a plain handset
                  // glyph.
                  child: const CallIcon(size: 52),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CaseKey(
                  key: const ValueKey('case-up'),
                  icon: Icons.arrow_upward,
                  iconColor: const Color(0xFF4A4A4A),
                  onPressed: controller.pressUp,
                  semanticLabel: l10n.casePrevious,
                ),
                _CaseKey(
                  key: const ValueKey('case-sos'),
                  label: l10n.sosButtonLabel,
                  labelColor: const Color(0xFFD8433C),
                  onPressed: controller.pressSos,
                  semanticLabel: l10n.caseSos,
                ),
                _CaseKey(
                  key: const ValueKey('case-down'),
                  icon: Icons.arrow_downward,
                  iconColor: const Color(0xFF4A4A4A),
                  onPressed: controller.pressDown,
                  semanticLabel: l10n.caseNext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseKey extends StatelessWidget {
  const _CaseKey({
    super.key,
    this.icon,
    this.iconColor,
    this.label,
    this.labelColor,
    this.child,
    this.color = Colors.white,
    required this.onPressed,
    this.onLongPress,
    this.onHoldStart,
    this.onHoldEnd,
    this.onHoldCancel,
    required this.semanticLabel,
  });

  final IconData? icon;
  final Color? iconColor;
  final String? label;
  final Color? labelColor;
  final Widget? child;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final VoidCallback? onHoldCancel;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Each key fills its whole cell so a press anywhere under the physical
    // button above it lands on the key.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        // Raw pointer events, outside the gesture arena, so the held state
        // is reported regardless of whether the touch becomes a tap or a
        // long-press.
        child: Listener(
          onPointerDown: onHoldStart == null ? null : (_) => onHoldStart!(),
          onPointerUp: onHoldEnd == null ? null : (_) => onHoldEnd!(),
          onPointerCancel: onHoldCancel == null ? null : (_) => onHoldCancel!(),
          child: Semantics(
            button: true,
            label: semanticLabel,
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(14),
              elevation: 1.5,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPressed,
                onLongPress: onLongPress,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child:
                      child ??
                      (icon != null
                          ? Icon(icon, color: iconColor, size: 40)
                          : Text(
                              label!,
                              style: TextStyle(
                                color: labelColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 26,
                              ),
                            )),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
