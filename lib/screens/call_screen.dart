import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/call_control.dart';
import '../theme/app_colors.dart';

/// Shows a phone call across the whole display area: who it is, as large
/// as it will go, and nothing to tap.
///
/// There are deliberately no Answer / Decline buttons on screen — the
/// case's green Call key answers and its red Hang-up key declines or ends
/// the call (see `PhoneShellController`).
class CallScreen extends StatelessWidget {
  const CallScreen({super.key, required this.call});

  final PhoneCall call;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name = call.name;
    final title = name ?? (call.number.isEmpty ? l10n.callUnknownCaller : null);

    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          children: [
            _Status(call: call),
            // Always takes its line, so the picture doesn't jump when
            // the loudspeaker goes on or off.
            Visibility(
              visible: call.speaker,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.volume_up,
                    size: 30,
                    color: Color(0xFF3B4CA8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.callSpeakerOn,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3B4CA8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Large, but clear of the screen edges and the text.
                  final size =
                      math.min(constraints.maxWidth, constraints.maxHeight) *
                      0.78;
                  return Center(
                    child: _Picture(call: call, size: size),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (title != null)
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 44,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (call.number.isNotEmpty)
              // Phone numbers always read left to right, even in Arabic.
              Text(
                call.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.center,
                style: name == null
                    ? const TextStyle(fontSize: 44, fontWeight: FontWeight.bold)
                    : TextStyle(fontSize: 28, color: scheme.outline),
              ),
            const SizedBox(height: 12),
            Text(
              call.state == PhoneCallState.ringing
                  ? l10n.callAnswerHint
                  : l10n.callEndHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Incoming call", "Calling…", or the running length of the call.
class _Status extends StatefulWidget {
  const _Status({required this.call});

  final PhoneCall call;

  @override
  State<_Status> createState() => _StatusState();
}

class _StatusState extends State<_Status> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.call.state == PhoneCallState.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final call = widget.call;
    final text = switch (call.state) {
      PhoneCallState.ringing => l10n.callIncoming,
      PhoneCallState.dialing => l10n.callDialing,
      PhoneCallState.active => _elapsed(call.connectedAt),
    };
    final ringing = call.state == PhoneCallState.ringing;
    return Text(
      text,
      // The clock's digits keep their order in Arabic too.
      textDirection: call.state == PhoneCallState.active
          ? TextDirection.ltr
          : null,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: ringing ? const Color(0xFF3FAE4C) : const Color(0xFF3B4CA8),
      ),
    );
  }

  String _elapsed(DateTime? since) {
    if (since == null) return '00:00';
    final elapsed = DateTime.now().difference(since);
    final seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(seconds ~/ 60)}:${two(seconds % 60)}';
  }
}

/// The caller's contact photo, filling the space — or, without one, their
/// initial (a person glyph for an unsaved number) in the same big circle.
class _Picture extends StatelessWidget {
  const _Picture({required this.call, required this.size});

  final PhoneCall call;
  final double size;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF3B4CA8);
    final photo = call.photo;
    final name = call.name?.trim() ?? '';

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 4),
      ),
      alignment: Alignment.center,
      child: photo != null
          ? Image.memory(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : name.isNotEmpty
          ? Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          : Icon(Icons.person, size: size * 0.6, color: color),
    );
  }
}
