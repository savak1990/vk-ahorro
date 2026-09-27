import 'package:ahorro_ui/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _base() => {
  'apiBaseUrl': 'https://api.example.invalid',
  'cognitoUserPoolId': '',
  'cognitoClientId': '',
  'cognitoRegion': 'eu-west-1',
};

void main() {
  // apply() writes statics, so a test that leaves them set would change the
  // next test's answer.
  tearDown(() => AppConfig.apply(_base()));

  test('fromJson returns every key when all are present', () {
    final parsed = AppConfig.fromJson({
      'apiBaseUrl': 'https://api.example.invalid',
      'cognitoUserPoolId': 'eu-west-1_abc',
      'cognitoClientId': 'client-abc',
      'cognitoRegion': 'eu-west-1',
    });

    expect(parsed['apiBaseUrl'], 'https://api.example.invalid');
    expect(parsed['cognitoUserPoolId'], 'eu-west-1_abc');
    expect(parsed['cognitoClientId'], 'client-abc');
    expect(parsed['cognitoRegion'], 'eu-west-1');
  });

  test('fromJson keeps an empty value, which is not a missing key', () {
    final parsed = AppConfig.fromJson({
      'apiBaseUrl': 'https://api.example.invalid',
      'cognitoUserPoolId': '',
      'cognitoClientId': '',
      'cognitoRegion': 'eu-west-1',
    });

    expect(parsed['cognitoClientId'], '');
  });

  test('fromJson throws naming every missing key', () {
    expect(
      () => AppConfig.fromJson({'apiBaseUrl': 'https://api.example.invalid'}),
      throwsA(
        isA<MissingConfigKeys>().having((e) => e.keys, 'keys', [
          'cognitoUserPoolId',
          'cognitoClientId',
          'cognitoRegion',
        ]),
      ),
    );
  });

  test('helloUrl joins the base URL and the endpoint', () {
    AppConfig.apply(_base());

    expect(AppConfig.helloUrl, 'https://api.example.invalid/api/v1/hello');
  });

  test('the auth-skip keys are optional and default to off', () {
    AppConfig.apply(_base());

    expect(AppConfig.authDisabled, isFalse);
    expect(AppConfig.skipAuth, isFalse);
    expect(AppConfig.devUserEmail, '');
    expect(AppConfig.devUserSub, '');
  });

  test('apply reads the auth-skip keys when the chart supplies them', () {
    AppConfig.apply({
      ..._base(),
      'authDisabled': true,
      'devUserEmail': 'e2e@vk-ahorro.invalid',
      'devUserSub': 'sub-local',
    });

    expect(AppConfig.authDisabled, isTrue);
    expect(AppConfig.skipAuth, isTrue);
    expect(AppConfig.devUserEmail, 'e2e@vk-ahorro.invalid');
    expect(AppConfig.devUserSub, 'sub-local');
  });

  // A chart may deliver the flag as text. Anything but "true" must stay off,
  // because the failure mode is an app that serves itself unauthenticated.
  test('authDisabled accepts the string true and rejects everything else', () {
    AppConfig.apply({..._base(), 'authDisabled': 'true'});
    expect(AppConfig.authDisabled, isTrue);

    for (final value in <dynamic>['false', '', 'yes', 1, null]) {
      AppConfig.apply({..._base(), 'authDisabled': value});
      expect(AppConfig.authDisabled, isFalse, reason: 'for $value');
    }
  });
}
