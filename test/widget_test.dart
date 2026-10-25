import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:labbiah/models/emergency_contact.dart';
import 'package:labbiah/services/sos_store.dart';

import 'package:labbiah/main.dart';
import 'package:labbiah/services/call_control.dart';

/// Advances past a screen transition without waiting for indeterminate
/// spinners (e.g. a pending, unmocked contacts-permission channel call in
/// this test environment) to settle, since [WidgetTester.pumpAndSettle]
/// would otherwise hang on them forever.
Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

final _callKey = find.byKey(const ValueKey('case-call'));
final _homeKey = find.byKey(const ValueKey('case-home'));
final _hangupKey = find.byKey(const ValueKey('case-hangup'));
final _upKey = find.byKey(const ValueKey('case-up'));
final _sosKey = find.byKey(const ValueKey('case-sos'));
final _downKey = find.byKey(const ValueKey('case-down'));

void main() {
  /// What the native side reports as the call history's missed callers.
  var missedCalls = <Map<String, Object?>>[];
  setUp(() {
    missedCalls = [];
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (locale != null) {
      tester.platformDispatcher.localesTestValue = [locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    }

    // No phone call in progress: Call and Hang-up ask the native side
    // first, and only navigate once it says there's no call to act on.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.labbiah.labbiah/call_control'),
      (call) async => switch (call.method) {
        'currentCall' => null,
        'missedCalls' => missedCalls,
        _ => false,
      },
    );

    await tester.pumpWidget(const LabbiahApp());
    await tester.pump();

    // Advance past the 1s splash screen and its transition into Home.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'SOS selects and calls another emergency contact in ${locale.languageCode}',
      (tester) async {
        await SosStore.save(const [
          EmergencyContact(name: 'Fatima', phone: '0501111111'),
          EmergencyContact(name: 'Ahmed', phone: '0502222222'),
        ]);
        final calls = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter_phone_direct_caller'),
          (call) async {
            calls.add((call.arguments as Map)['number'] as String);
            return true;
          },
        );
        await pumpApp(tester, locale: locale);
        tester.view.physicalSize = const Size(360, 780);
        await tester.pump();
        await tester.tap(_sosKey);
        await _advance(tester);
        expect(find.text('Fatima'), findsOneWidget);
        expect(find.text('Ahmed'), findsOneWidget);
        expect(calls, isEmpty);
        await tester.tap(_downKey);
        await _advance(tester);
        await tester.tap(_callKey);
        await _advance(tester);
        expect(calls, ['0502222222']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('SOS directly calls the only emergency contact', (tester) async {
    await SosStore.save(const [
      EmergencyContact(name: 'Fatima', phone: '0501111111'),
    ]);
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_phone_direct_caller'),
      (call) async {
        calls.add((call.arguments as Map)['number'] as String);
        return true;
      },
    );
    await pumpApp(tester);
    await tester.tap(_sosKey);
    await _advance(tester);
    expect(calls, ['0501111111']);
  });

  testWidgets('Startup requests Quick Switch setup once', (tester) async {
    var prompts = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.labbiah.labbiah/quick_switch'),
      (call) async {
        if (call.method == 'promptIfNeeded') prompts++;
        return false;
      },
    );
    await pumpApp(tester);
    expect(prompts, 1);
    await tester.pump();
    expect(prompts, 1);
  });

  testWidgets('Emergency contact names stay black with device dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await SosStore.save(const [
      EmergencyContact(name: 'Fatima', phone: '0501111111'),
      EmergencyContact(name: 'Ahmed', phone: '0502222222'),
    ]);
    await pumpApp(tester);
    await tester.tap(_sosKey);
    await _advance(tester);
    final name = find.text('Fatima');
    final rendered = tester.widget<RichText>(
      find.descendant(of: name, matching: find.byType(RichText)),
    );
    expect(rendered.text.style!.color, Colors.black);
    expect(Theme.of(tester.element(name)).brightness, Brightness.light);
  });

  testWidgets('App renders the home screen with the physical case', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('CALL'), findsOneWidget);
    expect(find.text('SOS\nEMERGENCY'), findsOneWidget);
    expect(_callKey, findsOneWidget);
    expect(_homeKey, findsOneWidget);
    expect(_hangupKey, findsOneWidget);
    expect(_upKey, findsOneWidget);
    expect(_sosKey, findsOneWidget);
    expect(_downKey, findsOneWidget);
    expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
  });

  testWidgets('Navigation fades the display while the case stays fixed', (
    tester,
  ) async {
    await pumpApp(tester);
    final casePosition = tester.getCenter(_homeKey);

    double displayOpacity() {
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.text('Emergency SOS'),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fades, isNotEmpty, reason: 'The next screen must not snap in');
      return fades.first.opacity.value;
    }

    await tester.tap(_sosKey);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final entering = displayOpacity();
    expect(entering, greaterThan(0));
    expect(entering, lessThan(1));
    expect(tester.getCenter(_homeKey), casePosition);
    await tester.pump(const Duration(milliseconds: 200));
    expect(displayOpacity(), 1);

    await tester.tap(_hangupKey);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(displayOpacity(), greaterThan(0));
    expect(displayOpacity(), lessThan(1));
    expect(tester.getCenter(_homeKey), casePosition);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Emergency SOS'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion skips the navigation fade', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester);
    await tester.tap(_sosKey);
    await tester.pump();
    await tester.pump();
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Emergency SOS'),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping content directly does nothing (display-only area)', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // The display area is wrapped in IgnorePointer, so a tap on a home tile
    // must not navigate anywhere.
    await tester.tap(find.text('CALL'), warnIfMissed: false);
    await _advance(tester);

    expect(find.text('Call a Contact'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets('Call on the highlighted CALL tile opens Call a Contact', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_callKey);
    await _advance(tester);

    expect(find.text('Call a Contact'), findsOneWidget);
  });

  testWidgets('Home button returns to the home screen from anywhere', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_callKey);
    await _advance(tester);
    expect(find.text('Call a Contact'), findsOneWidget);

    await tester.tap(_homeKey);
    await _advance(tester);
    // Let the pop transition finish so the old route leaves the tree.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Call a Contact'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets("Android's Back never closes Labbiah or changes screen", (
    WidgetTester tester,
  ) async {
    // What Flutter sends the platform when Back would exit the app.
    var exitRequests = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exitRequests++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester);

    // On Home, where there is nothing to go back to.
    await tester.binding.handlePopRoute();
    await _advance(tester);
    expect(exitRequests, 0);
    expect(find.text('CALL'), findsOneWidget);

    // And a screen deep, where it must not act as a back key either.
    await tester.tap(_callKey);
    await _advance(tester);
    await tester.binding.handlePopRoute();
    await _advance(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(exitRequests, 0);
    expect(find.text('Call a Contact'), findsOneWidget);
  });

  testWidgets('Hang-up button pops back one screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_callKey);
    await _advance(tester);
    expect(find.text('Call a Contact'), findsOneWidget);

    await tester.tap(_hangupKey);
    await _advance(tester);
    // Let the pop transition finish so the old route leaves the tree.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Call a Contact'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets('Up after Down moves the highlight back to CALL', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_downKey);
    await _advance(tester);
    await tester.tap(_upKey);
    await _advance(tester);
    await tester.tap(_callKey);
    await _advance(tester);

    expect(find.text('Call a Contact'), findsOneWidget);
  });

  testWidgets('SOS button is wired to the shell without error', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_sosKey);
    await _advance(tester);

    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.text('Add emergency contact'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The case keys sit under fixed physical buttons, so their order must
  // never change with the language: Hang-up / Up on the left, Home / SOS in
  // the middle, Call / Down on the right — in Arabic (RTL) as well.
  double centerX(WidgetTester tester, Finder key) => tester.getCenter(key).dx;

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'Case keys keep their physical order in ${locale.languageCode}',
      (WidgetTester tester) async {
        await pumpApp(tester, locale: locale);

        expect(
          centerX(tester, _hangupKey),
          lessThan(centerX(tester, _homeKey)),
        );
        expect(centerX(tester, _homeKey), lessThan(centerX(tester, _callKey)));
        expect(centerX(tester, _upKey), lessThan(centerX(tester, _sosKey)));
        expect(centerX(tester, _sosKey), lessThan(centerX(tester, _downKey)));
      },
    );
  }

  /// Delivers what the native side sends when a call starts, changes, or
  /// (with null) ends.
  Future<void> sendCall(WidgetTester tester, Map<String, Object?>? call) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'com.labbiah.labbiah/call_control',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('callChanged', call),
      ),
      (_) {},
    );
    await _advance(tester);
  }

  testWidgets('An incoming call covers the display with the caller', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    addTearDown(() => CallControl.current.value = null);

    await sendCall(tester, {
      'state': 'ringing',
      'number': '0501234567',
      'name': 'Fatima',
    });

    expect(find.text('Incoming call'), findsOneWidget);
    expect(find.text('Fatima'), findsOneWidget);
    expect(find.text('0501234567'), findsOneWidget);

    await sendCall(tester, {
      'state': 'active',
      'number': '0501234567',
      'name': 'Fatima',
      'speaker': true,
    });
    expect(find.text('Speaker on'), findsOneWidget);
  });

  testWidgets('Ending a call returns to the home screen from anywhere', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    addTearDown(() => CallControl.current.value = null);

    await tester.tap(_callKey);
    await _advance(tester);
    expect(find.text('Call a Contact'), findsOneWidget);

    await sendCall(tester, {'state': 'active', 'number': '0501234567'});

    await sendCall(tester, null);
    // Let the pop transition finish so the old route leaves the tree.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Call a Contact'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets('Hang-up on Home lists missed callers with their counts', (
    WidgetTester tester,
  ) async {
    missedCalls = [
      {'number': '0501234567', 'name': 'Fatima', 'count': 3},
      {'number': '0559999999', 'count': 1},
    ];
    await pumpApp(tester);

    await tester.tap(_hangupKey);
    await _advance(tester);

    expect(find.text('Missed Calls'), findsOneWidget);
    expect(find.text('Fatima'), findsOneWidget);
    expect(find.text('3 missed calls'), findsOneWidget);
    // An unsaved number is listed by the number itself.
    expect(find.text('0559999999'), findsOneWidget);
    expect(find.text('1 missed call'), findsOneWidget);

    // Hang-up again goes back, as on every other screen.
    await tester.tap(_hangupKey);
    await _advance(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Missed Calls'), findsNothing);
    expect(find.text('CALL'), findsOneWidget);
  });

  testWidgets('Missed Calls says so when nobody has called', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(_hangupKey);
    await _advance(tester);

    expect(find.text('No missed calls'), findsOneWidget);
  });
}
