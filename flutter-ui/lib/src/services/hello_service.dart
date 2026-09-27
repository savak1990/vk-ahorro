import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_logger.dart';
import 'operation_id_service.dart';

class HelloError implements Exception {
  const HelloError(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'hello failed with status $statusCode';
}

class HelloService {
  HelloService({http.Client? client, Future<String?> Function()? idToken})
    : _client = client ?? http.Client(),
      _idToken = idToken ?? _cognitoIdToken;

  final http.Client _client;
  final Future<String?> Function() _idToken;

  Future<String> hello() async {
    final url = Uri.parse(AppConfig.helloUrl);
    final headers = <String, String>{'X-Request-Id': generateOperationId()};
    final token = await _idToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';

    ApiLogger.logRequest(method: 'GET', url: '$url', headers: headers);
    final response = await _client.get(url, headers: headers);
    ApiLogger.logResponse(
      method: 'GET',
      url: '$url',
      statusCode: response.statusCode,
      body: response.body,
    );
    if (response.statusCode != 200) throw HelloError(response.statusCode);

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['message'] as String;
  }
}

Future<String?> _cognitoIdToken() async {
  if (!Amplify.isConfigured) return null;
  final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
  return session.userPoolTokensResult.value.idToken.raw;
}
