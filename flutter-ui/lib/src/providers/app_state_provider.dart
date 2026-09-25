import 'package:flutter/material.dart';

import 'amplify_provider.dart';

class AppStateProvider extends ChangeNotifier {
  final AmplifyProvider _amplify = AmplifyProvider();

  AmplifyProvider get amplify => _amplify;

  @override
  void dispose() {
    _amplify.dispose();
    super.dispose();
  }
}
