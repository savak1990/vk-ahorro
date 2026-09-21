import 'dart:async';
import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'base_provider.dart';

class AmplifyProvider extends BaseProvider {
  bool _isConfigured = false;
  String? _currentUserName;
  bool _isFetchingUserName = false;
  Map<String, dynamic>? _cachedUserInfo;
  Completer<Map<String, dynamic>>? _fetchCompleter;

  bool get isConfigured => _isConfigured || Amplify.isConfigured;
  String? get currentUserName => _currentUserName;
  Map<String, dynamic>? get cachedUserInfo => _cachedUserInfo;
  bool get isFetchingUserInfo =>
      _fetchCompleter != null && !_fetchCompleter!.isCompleted;

  Future<void> configure(String amplifyconfig) async {
    if (isConfigured) {
      _isConfigured = true;
      return;
    }

    await execute(() async {
      try {
        final auth = AmplifyAuthCognito();
        await Amplify.addPlugin(auth);
      } catch (_) {
        // Плагин мог быть добавлен ранее при hot-restart — игнорируем
      }
      if (!Amplify.isConfigured) {
        await Amplify.configure(amplifyconfig);
      }
      _isConfigured = true;
      debugPrint('[AmplifyProvider]: configured');
    });
  }

  Future<void> ensureSignedIn() async {
    await execute(() async {
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) {
        try {
          await Amplify.Auth.signInWithWebUI();
        } catch (e) {
          debugPrint('[AmplifyProvider]: sign-in cancelled or failed: $e');
          rethrow;
        }
      }
    });
  }

  Future<void> loadCurrentUserName() async {
    if (!isConfigured || _isFetchingUserName) return;
    _isFetchingUserName = true;
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final nameAttr = attributes.firstWhere(
        (attr) => attr.userAttributeKey.key == 'name',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.name,
          value: 'User',
        ),
      );
      _currentUserName = (nameAttr.value.isNotEmpty) ? nameAttr.value : 'User';
      notifyListeners();
    } catch (e) {
      debugPrint('[AmplifyProvider]: failed to fetch user name: $e');
    } finally {
      _isFetchingUserName = false;
    }
  }

  Future<Map<String, dynamic>> fetchUserInfo({
    bool forceRefresh = false,
  }) async {
    // Return cached data if available and not forcing refresh
    if (_cachedUserInfo != null && !forceRefresh) {
      debugPrint('[AmplifyProvider]: Returning cached user info');
      return _cachedUserInfo!;
    }

    // If already fetching, return the existing future
    if (_fetchCompleter != null && !_fetchCompleter!.isCompleted) {
      debugPrint(
        '[AmplifyProvider]: Already fetching user info, returning existing future',
      );
      return _fetchCompleter!.future;
    }

    // Start new fetch
    _fetchCompleter = Completer<Map<String, dynamic>>();
    notifyListeners();

    try {
      debugPrint('[AmplifyProvider]: Starting fetchUserInfo');

      // Add timeout to prevent hanging
      final session = await Amplify.Auth.fetchAuthSession().timeout(
        const Duration(seconds: 10),
      );
      debugPrint(
        '[AmplifyProvider]: Auth session fetched, isSignedIn: ${session.isSignedIn}',
      );

      if (!session.isSignedIn) {
        debugPrint('[AmplifyProvider]: User not signed in');
        throw Exception('SignedOut');
      }

      debugPrint('[AmplifyProvider]: Fetching user attributes');
      // Add timeout to prevent hanging on fetchUserAttributes
      final attributes = await Amplify.Auth.fetchUserAttributes().timeout(
        const Duration(seconds: 15),
      );
      debugPrint(
        '[AmplifyProvider]: User attributes fetched, count: ${attributes.length}',
      );

      final nameAttribute = attributes.firstWhere(
        (element) => element.userAttributeKey.key == 'name',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.name,
          value: 'User',
        ),
      );

      final emailAttribute = attributes.firstWhere(
        (element) => element.userAttributeKey.key == 'email',
        orElse: () => const AuthUserAttribute(
          userAttributeKey: CognitoUserAttributeKey.email,
          value: 'N/A',
        ),
      );

      final userInfo = {
        'name': nameAttribute.value,
        'email': emailAttribute.value,
      };

      debugPrint(
        '[AmplifyProvider]: User info compiled - name: ${nameAttribute.value}, email: ${emailAttribute.value}',
      );

      // Cache the result
      _cachedUserInfo = userInfo;
      // Also update the currentUserName for consistency
      _currentUserName = nameAttribute.value;

      _fetchCompleter!.complete(userInfo);
      notifyListeners();
      return userInfo;
    } on TimeoutException catch (e) {
      debugPrint('[AmplifyProvider]: Timeout error in fetchUserInfo: $e');
      final error = Exception(
        'Request timed out. Please check your internet connection.',
      );
      _fetchCompleter!.completeError(error);
      throw error;
    } catch (e) {
      debugPrint('[AmplifyProvider]: Error in fetchUserInfo: $e');
      _fetchCompleter!.completeError(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void clearUserData() {
    _currentUserName = null;
    _cachedUserInfo = null;
    _fetchCompleter = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      // Add timeout to prevent hanging
      await Amplify.Auth.signOut().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(
            'Sign out timed out',
            const Duration(seconds: 10),
          );
        },
      );

      clearUserData();
    } catch (e) {
      debugPrint('[AmplifyProvider]: Error during sign out: $e');
      rethrow;
    }
  }
}
