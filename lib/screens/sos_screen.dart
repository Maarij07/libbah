import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/emergency_contact.dart';
import '../services/contact_actions.dart';
import '../services/contact_display.dart';
import '../services/sos_store.dart';
import '../widgets/button_navigable.dart';
import '../widgets/call_icon.dart';
import '../widgets/phone_shell_controller.dart';
import '../widgets/phone_shell_scope.dart';
import 'contacts_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with RouteAware
    implements ButtonNavigable {
  List<EmergencyContact> _contacts = [];
  bool _loading = true;
  bool _triggering = false;
  int _highlighted = 0;
  PhoneShellController? _shell;

  // Contact rows come first; the final item adds another contact.
  int get _itemCount => _contacts.length + 1;
  List<GlobalKey> _itemKeys = [GlobalKey()];

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
  void didPopNext() {
    _shell?.register(this);
    _load();
  }

  @override
  void didPushNext() => _shell?.unregister(this);

  Future<void> _load() async {
    final contacts = await SosStore.load();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _itemKeys = List.generate(_itemCount, (_) => GlobalKey());
      _highlighted = _highlighted.clamp(0, _itemCount - 1);
      _loading = false;
    });
  }

  void _addContact() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactsScreen(
          selectionMode: true,
          onSelected: (contact) async {
            if (contact.phones.isEmpty) return;
            final updated = [
              ..._contacts,
              EmergencyContact(
                name: contactDisplayName(contact),
                phone: contact.phones.first.number,
              ),
            ];
            await SosStore.save(updated);
            if (mounted) {
              setState(() {
                _contacts = updated;
                _itemKeys = List.generate(_itemCount, (_) => GlobalKey());
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _callSelected() async {
    if (_triggering || _highlighted >= _contacts.length) return;
    final contact = _contacts[_highlighted];
    setState(() => _triggering = true);
    try {
      await ContactActions.call(contact.phone);
    } finally {
      if (mounted) setState(() => _triggering = false);
    }
  }

  @override
  void moveHighlightUp() => _moveHighlight(-1);

  @override
  void moveHighlightDown() => _moveHighlight(1);

  void _moveHighlight(int delta) {
    if (_loading || _triggering) return;
    setState(
      () => _highlighted = (_highlighted + delta).clamp(0, _itemCount - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _itemKeys[_highlighted].currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  @override
  void confirmHighlighted() {
    if (_loading || _triggering) return;
    if (_highlighted < _contacts.length) {
      _callSelected();
    } else {
      _addContact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Text(l10n.sosTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _contacts.isEmpty ? l10n.sosNoContactsHint : l10n.contactDetailHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        for (var i = 0; i < _itemCount; i++)
                          Container(
                            key: _itemKeys[i],
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: i == _highlighted
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: i == _highlighted
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: ListTile(
                              leading: i < _contacts.length
                                  ? const CallIcon(size: 34)
                                  : const Icon(Icons.person_add, size: 30),
                              title: Text(
                                i < _contacts.length
                                    ? _contacts[i].name
                                    : l10n.sosAddContact,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: i < _contacts.length
                                  ? Text(
                                      _contacts[i].phone,
                                      textDirection: TextDirection.ltr,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
