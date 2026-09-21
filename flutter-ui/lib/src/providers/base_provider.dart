import 'package:flutter/material.dart';

abstract class BaseProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastLoadedAt;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastLoadedAt => _lastLoadedAt;

  @protected
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @protected
  void setErrorMessage(String? errorMessage) {
    _errorMessage = errorMessage;
    notifyListeners();
  }

  @protected
  void setLastLoadedAt(DateTime? lastLoadedAt) {
    _lastLoadedAt = lastLoadedAt;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @protected
  Future<T> execute<T>(Future<T> Function() operation) async {
    setLoading(true);
    setErrorMessage(null);

    try {
      final result = await operation();
      setLastLoadedAt(DateTime.now());
      return result;
    } catch (e) {
      setErrorMessage(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  bool get hasError => _errorMessage != null;
  bool get hasData => _lastLoadedAt != null;
  bool get isInitialized => hasData && !hasError;

  bool shouldRefresh(Duration cacheDuration) {
    return _lastLoadedAt == null ||
        DateTime.now().difference(_lastLoadedAt!) > cacheDuration;
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _lastLoadedAt = null;
    notifyListeners();
  }
}
