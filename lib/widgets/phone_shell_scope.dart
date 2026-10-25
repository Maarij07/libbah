import 'package:flutter/material.dart';

import 'phone_shell_controller.dart';

class PhoneShellScope extends InheritedWidget {
  const PhoneShellScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PhoneShellController controller;

  static PhoneShellController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PhoneShellScope>();
    assert(scope != null, 'No PhoneShellScope found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(PhoneShellScope oldWidget) =>
      controller != oldWidget.controller;
}
