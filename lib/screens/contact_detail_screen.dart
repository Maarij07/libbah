import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/contact_actions.dart';
import '../services/contact_display.dart';
import '../widgets/button_navigable.dart';
import '../widgets/contact_avatar.dart';
import '../widgets/phone_shell_controller.dart';
import '../widgets/phone_shell_scope.dart';

/// Shows a contact's phone numbers. Up / Down highlight one; the physical
/// Call button calls it.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contact});

  final Contact contact;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen>
    with RouteAware
    implements ButtonNavigable {
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
  void didPopNext() => _shell?.register(this);

  @override
  void didPushNext() => _shell?.unregister(this);

  @override
  void moveHighlightUp() => _moveHighlight(-1);

  @override
  void moveHighlightDown() => _moveHighlight(1);

  void _moveHighlight(int delta) {
    final phones = widget.contact.phones;
    if (phones.isEmpty) return;
    setState(() {
      _highlighted = (_highlighted + delta).clamp(0, phones.length - 1);
    });
  }

  @override
  void confirmHighlighted() {
    final phones = widget.contact.phones;
    if (phones.isEmpty) return;
    ContactActions.call(phones[_highlighted].number);
  }

  @override
  Widget build(BuildContext context) {
    final name = contactDisplayName(widget.contact);
    final phones = widget.contact.phones;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(child: ContactAvatar(contact: widget.contact, radius: 48)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        if (phones.isEmpty)
          Center(
            child: Text(AppLocalizations.of(context)!.contactDetailNoPhone),
          )
        else ...[
          Center(
            child: Text(
              AppLocalizations.of(context)!.contactDetailHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < phones.length; i++)
            _PhoneRow(phone: phones[i], highlighted: i == _highlighted),
        ],
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone, required this.highlighted});

  final Phone phone;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? Border.all(color: scheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        title: Text(
          phone.number,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          phone.label.label.name,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
