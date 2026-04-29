import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'data/local/database_helper.dart';
import 'presentation/pages/home_page.dart';
import 'core/app_theme.dart';
import 'presentation/providers/settings_provider.dart';
import 'src/rust/frb_generated.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:toastification/toastification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  final initialThemeModeFuture = _loadInitialThemeMode();
  final initialLocaleFuture = _loadInitialLocale();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });
  }

  ThemeMode initialThemeMode = ThemeMode.system;
  Locale initialLocale = const Locale('en');

  try {
    initialThemeMode = await initialThemeModeFuture;
    initialLocale = await initialLocaleFuture;
  } catch (e) {
    // Initialization error handled silently
  }

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(initial: initialThemeMode),
        ),
        localeProvider.overrideWith(
          (ref) => LocaleNotifier(initial: initialLocale),
        ),
      ],
      child: const PostLensApp(),
    ),
  );
}

Future<ThemeMode> _loadInitialThemeMode() async {
  final val = await DatabaseHelper.instance.getKeyValue('theme_mode');
  if (val == ThemeMode.light.name) return ThemeMode.light;
  if (val == ThemeMode.dark.name) return ThemeMode.dark;
  if (val == ThemeMode.system.name) return ThemeMode.system;
  return ThemeMode.system;
}

Future<Locale> _loadInitialLocale() async {
  final val = await DatabaseHelper.instance.getKeyValue('locale');
  if (val == null || val.isEmpty) return const Locale('en');
  return Locale(val);
}

class NoOverscrollBehavior extends MaterialScrollBehavior {
  const NoOverscrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // 移除 Android 的发光效果
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(); // 移除 iOS/Mac 的回弹效果，并在所有平台上阻止过度拖拽
  }
}

class PostLensApp extends ConsumerWidget {
  const PostLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return ToastificationWrapper(
      child: MaterialApp(
        title: 'PostLens',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        scrollBehavior: const NoOverscrollBehavior(),
        home: const HomePage(),
      ),
    );
  }
}
