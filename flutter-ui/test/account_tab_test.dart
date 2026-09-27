import 'package:ahorro_ui/src/config/app_config.dart';
import 'package:ahorro_ui/src/providers/amplify_provider.dart';
import 'package:ahorro_ui/src/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _config({required bool authDisabled, String email = ''}) =>
    {
      'apiBaseUrl': 'http://localhost:8091',
      'cognitoUserPoolId': '',
      'cognitoClientId': '',
      'cognitoRegion': 'eu-west-1',
      'authDisabled': authDisabled,
      'devUserEmail': email,
      'devUserSub': '',
    };

Widget _wrap() => ChangeNotifierProvider<AmplifyProvider>(
  create: (_) => AmplifyProvider(),
  child: const MaterialApp(home: Scaffold(body: AccountTab())),
);

void main() {
  tearDown(() => AppConfig.apply(_config(authDisabled: false)));

  testWidgets('offers Sign out when the pool is configured', (tester) async {
    AppConfig.apply(_config(authDisabled: false));

    await tester.pumpWidget(_wrap());

    expect(find.text('Sign out'), findsOneWidget);
  });

  // signOut() throws against an Amplify that was never configured, so the
  // button must not be offered at all on a target with no pool.
  testWidgets(
    'names the stand-in user and hides Sign out when auth is skipped',
    (tester) async {
      AppConfig.apply(
        _config(authDisabled: true, email: 'e2e@vk-ahorro.invalid'),
      );

      await tester.pumpWidget(_wrap());

      expect(find.text('Sign out'), findsNothing);
      expect(
        find.text('Signed in as e2e@vk-ahorro.invalid (sign-in skipped)'),
        findsOneWidget,
      );
    },
  );
}
