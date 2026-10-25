import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/generated/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The fixed case buttons require an upright portrait layout on every screen.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Date symbol data (weekday/month names, AM/PM markers) for the two
  // supported locales — DateFormat throws if this isn't loaded first.
  await initializeDateFormatting('en');
  await initializeDateFormatting('ar');
  runApp(const LabbiahApp());
}

/// Text sizes tuned for elderly users: everything is close to the size of
/// the home screen's clock ("12:08 PM") rather than standard Material
/// defaults, which are too small to read comfortably at a glance.
const _elderlyTextTheme = TextTheme(
  displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
  displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
  displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
  headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
  headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
  headlineSmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
  titleLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
  titleMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(fontSize: 24),
  bodyMedium: TextStyle(fontSize: 20),
  bodySmall: TextStyle(fontSize: 18),
  labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
  labelMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

class LabbiahApp extends StatelessWidget {
  const LabbiahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;

    return MaterialApp(
      title: 'Labbiah',
      debugShowCheckedModeBanner: false,
      // The interface uses light surfaces in every screen, including the case.
      themeMode: ThemeMode.light,
      // Follows the device's language automatically; only English and
      // Arabic are supported for now. Listed with English first so an
      // unsupported device language falls back to English rather than
      // Arabic.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          surface: AppColors.background,
          onSurface: Colors.black,
          onPrimaryContainer: Colors.black,
        ),
        scaffoldBackgroundColor: AppColors.background,
        canvasColor: AppColors.background,
        textTheme: _elderlyTextTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _GentlePageTransition(),
            TargetPlatform.iOS: _GentlePageTransition(),
            TargetPlatform.macOS: _GentlePageTransition(),
            TargetPlatform.windows: _GentlePageTransition(),
            TargetPlatform.linux: _GentlePageTransition(),
            TargetPlatform.fuchsia: _GentlePageTransition(),
          },
        ),
        iconTheme: const IconThemeData(size: 28),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          minVerticalPadding: 12,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Briefly fades the display between screens without moving the case buttons.
class _GentlePageTransition extends PageTransitionsBuilder {
  const _GentlePageTransition();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Screens in the nested navigator have no Scaffold of their own. Paint
    // their background too, so the previous screen cannot show through them.
    final page = ColoredBox(color: AppColors.background, child: child);
    if (MediaQuery.disableAnimationsOf(context)) return page;
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: page,
    );
  }
}
