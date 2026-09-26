import 'dart:convert';

import 'src/config/app_config.dart';

// Built from AppConfig rather than held as a const: there is one pool per
// platform project, so a baked-in id is right for exactly one of them.
String amplifyConfig() => jsonEncode({
  'UserAgent': 'aws-amplify-cli/2.0',
  'Version': '1.0',
  'auth': {
    'plugins': {
      'awsCognitoAuthPlugin': {
        'IdentityManager': {'Default': <String, dynamic>{}},
        'CognitoUserPool': {
          'Default': {
            'PoolId': AppConfig.cognitoUserPoolId,
            'AppClientId': AppConfig.cognitoClientId,
            'Region': AppConfig.cognitoRegion,
          },
        },
        'Auth': {
          'Default': {
            'authenticationFlowType': 'USER_SRP_AUTH',
            'usernameAttributes': ['email'],
            'signupAttributes': ['email', 'name'],
            'passwordProtectionSettings': {
              'passwordPolicyMinLength': 8,
              'passwordPolicyCharacters': [
                'REQUIRES_LOWERCASE',
                'REQUIRES_UPPERCASE',
                'REQUIRES_NUMBERS',
              ],
            },
          },
        },
      },
    },
  },
});
