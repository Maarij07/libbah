import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../services/contact_display.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.contact, this.radius = 24});

  final Contact contact;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final thumbnail = contact.photo?.thumbnail;
    if (thumbnail != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(thumbnail),
      );
    }

    final name = contactDisplayName(contact);
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
