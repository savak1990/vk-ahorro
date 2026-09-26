import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MissingConfigKeys implements Exception {
  const MissingConfigKeys(this.keys);

  final List<String> keys;

  @override
  String toString() => 'config.json is missing: ${keys.join(', ')}';
}

class AppConfig {
  // Plain fields, not late final: a late final throws on any read before
  // load() completes, and again on the second load() a hot restart causes.
  static String apiBaseUrl = '';
  static String cognitoUserPoolId = '';
  static String cognitoClientId = '';
  static String cognitoRegion = '';

  static const String helloEndpoint = '/api/v1/hello';

  static String get helloUrl => '$apiBaseUrl$helloEndpoint';

  static const List<String> _keys = [
    'apiBaseUrl',
    'cognitoUserPoolId',
    'cognitoClientId',
    'cognitoRegion',
  ];

  // Web fetches a file the chart mounts, so one image serves every
  // environment. Mobile has no server to fetch from and keeps its defines.
  static Future<void> load() async {
    if (!kIsWeb) {
      apiBaseUrl = const String.fromEnvironment('API_BASE_URL');
      cognitoUserPoolId = const String.fromEnvironment('COGNITO_USER_POOL_ID');
      cognitoClientId = const String.fromEnvironment('COGNITO_CLIENT_ID');
      cognitoRegion = const String.fromEnvironment('COGNITO_REGION');
      return;
    }

    // resolve() respects <base href>, so this holds under a sub-path.
    final response = await http.get(Uri.base.resolve('config.json'));
    if (response.statusCode != 200) {
      throw Exception('config.json returned ${response.statusCode}');
    }
    apply(jsonDecode(response.body) as Map<String, dynamic>);
  }

  static void apply(Map<String, dynamic> json) {
    final parsed = fromJson(json);
    apiBaseUrl = parsed['apiBaseUrl']!;
    cognitoUserPoolId = parsed['cognitoUserPoolId']!;
    cognitoClientId = parsed['cognitoClientId']!;
    cognitoRegion = parsed['cognitoRegion']!;
  }

  // Names every missing key, so a chart that forgets one fails loudly rather
  // than defaulting to a value that is correct in exactly one environment.
  static Map<String, String> fromJson(Map<String, dynamic> json) {
    final missing = _keys.where((k) => json[k] == null).toList();
    if (missing.isNotEmpty) {
      throw MissingConfigKeys(missing);
    }
    return {for (final k in _keys) k: json[k].toString()};
  }
}
