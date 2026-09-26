import 'package:ahorro_ui/src/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        isA<MissingConfigKeys>().having(
          (e) => e.keys,
          'keys',
          ['cognitoUserPoolId', 'cognitoClientId', 'cognitoRegion'],
        ),
      ),
    );
  });

  test('helloUrl joins the base URL and the endpoint', () {
    AppConfig.apply({
      'apiBaseUrl': 'https://api.example.invalid',
      'cognitoUserPoolId': '',
      'cognitoClientId': '',
      'cognitoRegion': 'eu-west-1',
    });

    expect(AppConfig.helloUrl, 'https://api.example.invalid/api/v1/hello');
  });
}
