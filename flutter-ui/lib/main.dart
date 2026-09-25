import 'dart:async';

import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';

import 'amplifyconfiguration.dart';
import 'src/config/adaptive_theme.dart';
import 'src/config/app_theme.dart';
import 'src/constants/app_strings.dart';
import 'src/providers/amplify_provider.dart';
import 'src/providers/app_state_provider.dart';
import 'src/screens/main_screen.dart';

// Renders the shell without sign-in, for local UI work. kDebugMode keeps it
// out of any release build, so a shipped app can never start unauthenticated.
const skipAuth = bool.fromEnvironment('SKIP_AUTH') && kDebugMode;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const AhorroApp(),
    ),
  );
}

class AhorroApp extends StatefulWidget {
  const AhorroApp({super.key});

  @override
  State<AhorroApp> createState() => _AhorroAppState();
}

class _AhorroAppState extends State<AhorroApp> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startAmplify());
  }

  Future<void> _startAmplify() async {
    if (skipAuth) return;

    final amplify = context.read<AppStateProvider>().amplify;
    await amplify.configure(amplifyconfig);
    await amplify.loadCurrentUserName();

    Amplify.Hub.listen(HubChannel.Auth, (event) {
      if (event.eventName == 'SIGNED_IN') {
        unawaited(amplify.loadCurrentUserName());
      } else if (event.eventName == 'SIGNED_OUT') {
        amplify.clearUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = PlatformProvider(
      builder: (context) => PlatformTheme(
        materialLightTheme: AdaptiveTheme.lightTheme,
        materialDarkTheme: AdaptiveTheme.darkTheme,
        themeMode: ThemeMode.system,
        cupertinoLightTheme: materialToCupertino(AdaptiveTheme.lightTheme),
        cupertinoDarkTheme: materialToCupertino(AdaptiveTheme.darkTheme),
        builder: (context) => PlatformApp(
          builder: skipAuth ? null : Authenticator.builder(),
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          routes: {'/': (_) => const MainScreen()},
        ),
      ),
    );

    return ChangeNotifierProvider<AmplifyProvider>.value(
      value: context.read<AppStateProvider>().amplify,
      child: skipAuth ? app : Authenticator(child: app),
    );
  }
}
