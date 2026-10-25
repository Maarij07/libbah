import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/contact_actions.dart';
import '../services/contact_display.dart';
import '../services/contacts_repository.dart';
import '../widgets/button_navigable.dart';
import '../widgets/call_icon.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/phone_shell_controller.dart';
import '../widgets/phone_shell_scope.dart';
import 'contact_detail_screen.dart';

enum _LoadState { loading, denied, ready, error }

/// What the Call button does to the highlighted contact.
enum ContactsAction { call, message, manage }

/// Shows every contact on the device, one highlighted at a time.
///
/// Up / Down move the highlight; the physical Call button confirms it. In
/// [selectionMode] (used to pick an emergency contact), confirming a
/// contact calls [onSelected] and pops instead of acting on it directly.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    this.action = ContactsAction.manage,
    this.selectionMode = false,
    this.onSelected,
  });

  final ContactsAction action;
  final bool selectionMode;
  final ValueChanged<Contact>? onSelected;

  String title(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (selectionMode) return l10n.contactsTitleChooseEmergency;
    return switch (action) {
      ContactsAction.call => l10n.contactsTitleCall,
      ContactsAction.message => l10n.contactsTitleMessage,
      ContactsAction.manage => l10n.contactsTitleManage,
    };
  }

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with RouteAware
    implements ButtonNavigable {
  _LoadState _state = _LoadState.loading;
  List<Contact> _contacts = [];
  int _highlighted = 0;
  PhoneShellController? _shell;
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() => _shell?.register(this);

  @override
  void didPushNext() => _shell?.unregister(this);

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      final granted =
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited;
      if (!granted) {
        setState(() => _state = _LoadState.denied);
        return;
      }
      final contacts = await ContactsRepository.getAll();
      setState(() {
        _contacts = contacts;
        _itemKeys = List.generate(contacts.length, (_) => GlobalKey());
        _highlighted = 0;
        _state = _LoadState.ready;
      });
    } catch (_) {
      setState(() => _state = _LoadState.error);
    }
  }

  @override
  void moveHighlightUp() => _moveHighlight(-1);

  @override
  void moveHighlightDown() => _moveHighlight(1);

  void _moveHighlight(int delta) {
    if (_state != _LoadState.ready || _contacts.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, _contacts.length - 1);
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
    if (_state != _LoadState.ready) {
      _load();
      return;
    }
    if (_contacts.isEmpty) return;
    final contact = _contacts[_highlighted];

    if (widget.selectionMode) {
      widget.onSelected?.call(contact);
      Navigator.of(context).pop();
      return;
    }

    final number = contact.phones.isNotEmpty
        ? contact.phones.first.number
        : null;
    switch (widget.action) {
      case ContactsAction.call:
        if (number != null) ContactActions.call(number);
      case ContactsAction.message:
        if (number != null) ContactActions.message(number);
      case ContactsAction.manage:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ContactDetailScreen(contact: contact),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            widget.title(context),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.denied:
        return _MessagePane(
          icon: Icons.contacts,
          title: l10n.contactsAccessNeededTitle,
          message: l10n.contactsAccessNeededMessage,
        );
      case _LoadState.error:
        return _MessagePane(
          icon: Icons.warning_amber_rounded,
          title: l10n.contactsErrorTitle,
          message: l10n.contactsErrorMessage,
        );
      case _LoadState.ready:
        return _buildList();
    }
  }

  Widget _buildList() {
    if (_contacts.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return _MessagePane(
        icon: Icons.contacts,
        title: l10n.contactsEmptyTitle,
        message: l10n.contactsEmptyMessage,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final highlighted = index == _highlighted;
        final scheme = Theme.of(context).colorScheme;
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
            leading: ContactAvatar(contact: contact, radius: 32),
            title: Text(
              contactDisplayName(contact),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            trailing:
                !widget.selectionMode && widget.action != ContactsAction.manage
                ? (widget.action == ContactsAction.call
                      ? const CallIcon(size: 36)
                      : Icon(
                          Icons.message,
                          size: 32,
                          color: Theme.of(context).colorScheme.outline,
                        ))
                : null,
          ),
        );
      },
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
