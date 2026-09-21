import 'package:ahorro_ui/src/screens/balances_screen.dart';
import 'package:ahorro_ui/src/screens/main_screen.dart';
import 'package:ahorro_ui/src/widgets/fragments/home_tabs/transactions_tab.dart';
import 'package:ahorro_ui/src/screens/default_balance_currency_screen.dart';
import 'package:ahorro_ui/src/screens/transaction_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'src/providers/balances_provider.dart';
import 'src/providers/categories_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'amplifyconfiguration.dart' as stable_config;
import 'amplifyconfiguration_prod.dart' as prod_config;

import 'src/constants/app_strings.dart';
import 'src/config/app_theme.dart';
import 'src/config/adaptive_theme.dart';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'src/providers/transaction_entries_provider.dart';
import 'src/providers/app_state_provider.dart';
import 'src/providers/amplify_provider.dart';
import 'src/providers/transactions_filter_provider.dart';

void main() async {
  debugPrint('Starting Ahorro UI...');
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late String amplifyconfig;

  @override
  void initState() {
    debugPrint('MyApp initState called');
    super.initState();
    const env = String.fromEnvironment('ENV', defaultValue: 'stable');
    amplifyconfig = env == 'prod'
        ? prod_config.amplifyconfig
        : stable_config.amplifyconfig;
    // Configure Amplify once before the Authenticator UI appears
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppStateProvider>();
      await appState.amplify.configure(amplifyconfig);
      // If already signed in at startup — initialize app data
      try {
        final session = await Amplify.Auth.fetchAuthSession();
        if (session.isSignedIn) {
          await appState.initializeApp(amplifyconfig);
        }
      } catch (_) {}

      // Listen for auth state changes
      _setupAuthListener(appState);
    });
  }

  void _setupAuthListener(AppStateProvider appState) {
    Amplify.Hub.listen(HubChannel.Auth, (hubEvent) async {
      debugPrint('[MyApp]: Auth event received: ${hubEvent.eventName}');

      switch (hubEvent.eventName) {
        case 'SIGNED_IN':
          debugPrint('[MyApp]: User signed in, loading data');
          try {
            await appState.onUserSignedIn();
          } catch (e) {
            debugPrint('[MyApp]: Error loading user data after sign in: $e');
          }
          break;
        case 'SIGNED_OUT':
          debugPrint('[MyApp]: User signed out, clearing data');
          appState.clearAllUserData();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AmplifyProvider>.value(value: appState.amplify),
        ChangeNotifierProvider<BalancesProvider>.value(
          value: appState.balances,
        ),
        ChangeNotifierProvider<CategoriesProvider>.value(
          value: appState.categories,
        ),
        ChangeNotifierProvider<TransactionEntriesProvider>.value(
          value: appState.transactions,
        ),
        ChangeNotifierProvider<TransactionsFilterProvider>(
          create: (_) => TransactionsFilterProvider(),
        ),
      ],
      child: Authenticator(
        child: PlatformProvider(
          builder: (context) => PlatformTheme(
            materialLightTheme: AdaptiveTheme.lightTheme,
            materialDarkTheme: AdaptiveTheme.darkTheme,
            themeMode: ThemeMode.system,
            cupertinoLightTheme: materialToCupertino(AdaptiveTheme.lightTheme),
            cupertinoDarkTheme: materialToCupertino(AdaptiveTheme.darkTheme),
            builder: (context) => PlatformApp(
              builder: Authenticator.builder(),
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
              ],
              title: AppStrings.appTitle,
              debugShowCheckedModeBanner: false,
              initialRoute: '/',
              routes: {
                '/': (context) => const MainScreen(),
                '/transactions': (context) => const TransactionsTab(),
                '/transactions/stats': (context) =>
                    const TransactionStatsScreen(),
                '/balances': (context) => const BalancesScreen(),
                '/default-balance-currency': (context) =>
                    const DefaultBalanceCurrencyScreen(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
