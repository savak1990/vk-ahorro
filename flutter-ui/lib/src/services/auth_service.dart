import 'package:amplify_flutter/amplify_flutter.dart';

class AuthService {
  // Hardcoded groupId constant
  static const String groupId = '6a785a55-fced-4f13-af78-5c19a39c9abc';

  // Get current userId using Amplify Auth
  static Future<String> getUserId() async {
    final currentUser = await Amplify.Auth.getCurrentUser();
    return currentUser.userId;
  }
} 