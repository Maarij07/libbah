import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/call_control.dart';
import '../services/contact_actions.dart';
import '../widgets/button_navigable.dart';
import '../widgets/call_icon.dart';
import '../widgets/phone_shell_controller.dart';
import '../widgets/phone_shell_scope.dart';

enum _LoadState { loading, ready, error }

/// Shows everyone who rang and wasn't answered, one highlighted at a time,
/// with how many times each of them tried.
///
/// Opened with the Hang-up key from Home. Up / Down move the highlight;
/// the physical Call button rings the highlighted person back.
class MissedCallsScreen extends StatefulWidget {
  const MissedCallsScreen({super.key});

  @override
  State<MissedCallsScreen> createState() => _MissedCallsScreenState();
}

class _MissedCallsScreenState extends State<MissedCallsScreen>
    with RouteAware
    implements ButtonNavigable {
  _LoadState _state = _LoadState.loading;
  List<MissedCall> _calls = [];
  int _highlighted = 0;
  PhoneShellController? _shell;
  List<GlobalKey> _itemKeys = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

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
  void didPopNext() => _shell?.register(this);

  @override
  void didPushNext() => _shell?.unregister(this);

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final calls = await CallControl.missedCalls();
      if (!mounted) return;
      setState(() {
        _calls = calls;
        _itemKeys = List.generate(calls.length, (_) => GlobalKey());
        _highlighted = 0;
        _state = _LoadState.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  @override
  void moveHighlightUp() => _moveHighlight(-1);

  @override
  void moveHighlightDown() => _moveHighlight(1);

  void _moveHighlight(int delta) {
    if (_state != _LoadState.ready || _calls.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, _calls.length - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[_highlighted].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  @override
  void confirmHighlighted() {
    if (_state == _LoadState.error) {
      _load();
      return;
    }
    if (_state != _LoadState.ready || _calls.isEmpty) return;
    final number = _calls[_highlighted].number;
    if (number.isNotEmpty) ContactActions.call(number);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            l10n.missedTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: switch (_state) {
            _LoadState.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            _LoadState.error => _MessagePane(
              icon: Icons.warning_amber_rounded,
              title: l10n.contactsErrorTitle,
              message: l10n.contactsErrorMessage,
            ),
            _LoadState.ready when _calls.isEmpty => _MessagePane(
              icon: Icons.phone_missed,
              title: l10n.missedEmptyTitle,
              message: l10n.missedEmptyMessage,
            ),
            _LoadState.ready => _buildList(),
          },
        ),
      ],
    );
  }

  Widget _buildList() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _calls.length,
      itemBuilder: (context, index) {
        final call = _calls[index];
        final highlighted = index == _highlighted;
        final title = call.name ?? call.number;
        return Container(
          key: _itemKeys[index],
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: highlighted ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? scheme.primary : Colors.transparent,
              width: 4,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            leading: _Avatar(call: call),
            title: Text(
              title.isEmpty ? l10n.callUnknownNumber : title,
              // A bare phone number reads left to right, even in Arabic.
              textDirection: call.name == null && title.isNotEmpty
                  ? TextDirection.ltr
                  : null,
              textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              l10n.missedCount(call.count),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD8433C),
              ),
            ),
            trailing: call.number.isEmpty ? null : const CallIcon(size: 36),
          ),
        );
      },
    );
  }
}

/// The caller's contact photo, their initial, or — for a number that
/// isn't saved — a person glyph.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.call});

  final MissedCall call;

  @override
  Widget build(BuildContext context) {
    const radius = 32.0;
    final photo = call.photo;
    if (photo != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(photo));
    }
    final color = Theme.of(context).colorScheme.primary;
    final name = call.name?.trim() ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: name.isEmpty
          ? Icon(Icons.person, size: radius * 1.2, color: color)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

class _MessagePane extends StatelessWidget {
  const _MessagePane({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
