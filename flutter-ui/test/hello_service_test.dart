import 'dart:convert';

import 'package:ahorro_ui/src/config/app_config.dart';
import 'package:ahorro_ui/src/services/hello_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AppConfig.apply({
      'apiBaseUrl': 'https://api.example.invalid',
      'cognitoUserPoolId': '',
      'cognitoClientId': '',
      'cognitoRegion': 'eu-west-1',
    });
  });

  HelloService service({
    required http.Request Function(http.Request) capture,
    int status = 200,
    Future<String?> Function()? idToken,
  }) {
    final client = MockClient((request) async {
      capture(request);
      return http.Response(jsonEncode({'message': 'Hello, tester'}), status);
    });
    return HelloService(client: client, idToken: idToken ?? () async => null);
  }

  test('hello GETs the hello URL and returns the message', () async {
    http.Request? seen;
    final s = service(capture: (r) => seen = r);

    final message = await s.hello();

    expect(message, 'Hello, tester');
    expect(seen!.method, 'GET');
    expect(seen!.url.toString(), 'https://api.example.invalid/api/v1/hello');
  });

  test('hello sends an X-Request-Id header', () async {
    http.Request? seen;
    await service(capture: (r) => seen = r).hello();

    expect(seen!.headers['X-Request-Id'], isNotEmpty);
  });

  test('hello sends a bearer token when one is available', () async {
    http.Request? seen;
    await service(capture: (r) => seen = r, idToken: () async => 't').hello();

    expect(seen!.headers['Authorization'], 'Bearer t');
  });

  test('hello sends no Authorization header without a token', () async {
    http.Request? seen;
    await service(capture: (r) => seen = r).hello();

    expect(seen!.headers.containsKey('Authorization'), isFalse);
  });

  test('hello throws HelloError carrying the status on non-200', () async {
    final s = service(capture: (r) => r, status: 500);

    await expectLater(
      s.hello(),
      throwsA(isA<HelloError>().having((e) => e.statusCode, 'status', 500)),
    );
  });
}
