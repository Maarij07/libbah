import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/button_navigable.dart';
import '../widgets/call_icon.dart';
import '../widgets/phone_shell_controller.dart';
import '../widgets/phone_shell_scope.dart';
import 'contacts_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware
    implements ButtonNavigable {
  static const _tileCount = 2;
  int _highlighted = 0;
  PhoneShellController? _shell;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = PhoneShellScope.of(context);
    if (_shell != shell) {
      _shell = shell;
      shell.routeObserver.subscribe(this, ModalRoute.of(context)!);
      shell.register(this);
    }
  }

  @override
  void dispose() {
    _shell?.routeObserver.unsubscribe(this);
    _shell?.unregister(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _shell?.register(this);
    // Always land back on CALL — otherwise the Call button would act on
    // whatever tile was highlighted on a previous visit (e.g. silently
    // opening a contact's detail page instead of placing a call).
    setState(() => _highlighted = 0);
  }

  @override
  void didPushNext() => _shell?.unregister(this);

  @override
  void moveHighlightUp() => setState(
    () => _highlighted = (_highlighted - 1).clamp(0, _tileCount - 1),
  );

  @override
  void moveHighlightDown() => setState(
    () => _highlighted = (_highlighted + 1).clamp(0, _tileCount - 1),
  );

  @override
  void confirmHighlighted() {
    switch (_highlighted) {
      case 0:
        _openContacts(ContactsAction.call);
      case 1:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SosScreen()));
    }
  }

  void _openContacts(ContactsAction action) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ContactsScreen(action: action)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SvgPicture.asset('assets/images/logo.svg', height: 100),
          const SizedBox(height: 20),
          Expanded(
            child: Column(
              children: [
                const Expanded(flex: 2, child: _ClockCard()),
                const SizedBox(height: 18),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Expanded(
                        child: _HomeButton(
                          label: AppLocalizations.of(context)!.homeCallButton,
                          // The tile itself is already this green, so just
                          // the white glyph is drawn — a squircle badge on
                          // top would double up the green.
                          iconWidget: const CallGlyph(size: 44),
                          color: const Color(0xFF3FAE4C),
                          highlighted: _highlighted == 0,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _HomeButton(
                          label: AppLocalizations.of(context)!.homeSosButton,
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFD8433C),
                          highlighted: _highlighted == 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PageIndicator(highlighted: _highlighted),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ClockCard extends StatefulWidget {
  const _ClockCard();

  @override
  State<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends State<_ClockCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.jm(locale).format(_now);
    final day = DateFormat('EEEE, d MMMM', locale).format(_now);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF3B4CA8),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            time,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 40,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 24,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton({
    required this.label,
    this.icon,
    this.iconWidget,
    required this.color,
    required this.highlighted,
  }) : assert(icon != null || iconWidget != null);

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.transparent,
          width: 4,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)]
            : null,
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget ?? Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.highlighted});

  final int highlighted;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.grey.shade400;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _HomeScreenState._tileCount; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Icon(
            Icons.circle,
            size: 8,
            color: i == highlighted ? const Color(0xFF3B4CA8) : muted,
          ),
        ],
      ],
    );
  }
}
