import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';

/// Global logging levels for the entire application
enum LogLevel {
  error, // Only errors
  warn, // Errors + warnings
  info, // Errors + warnings + info (one-liner for API calls)
  debug, // Errors + warnings + info + debug details
  verbose, // Everything including full request/response bodies and headers
}

/// A comprehensive logging utility for API requests and responses
class ApiLogger {
  static const String _tag = '[ApiLogger]';

  // Cache the log level to avoid repeated .env lookups
  static LogLevel? _cachedLogLevel;

  /// Get the current log level from environment variables
  static LogLevel get _logLevel {
    if (_cachedLogLevel != null) return _cachedLogLevel!;

    String? levelStr;

    // Check dart-define variable first (this works for --dart-define=LOG_LEVEL=verbose)
    levelStr = const String.fromEnvironment('LOG_LEVEL');
    if (kDebugMode && levelStr.isNotEmpty) {
      print('[ApiLogger] Found dart-define LOG_LEVEL: $levelStr');
    }

    // Check runtime environment variable (this works for LOG_LEVEL=verbose flutter run on some platforms)
    if (levelStr.isEmpty) {
      try {
        levelStr = Platform.environment['LOG_LEVEL'];
        if (kDebugMode && levelStr != null && levelStr.isNotEmpty) {
          print('[ApiLogger] Found runtime environment LOG_LEVEL: $levelStr');
        }
      } catch (e) {
        // Platform.environment might not be available in some contexts (like web)
        levelStr = null;
        if (kDebugMode) {
          print('[ApiLogger] Platform.environment not available: $e');
        }
      }
    }

    // If still no value, fall back to .env file
    if (levelStr == null || levelStr.isEmpty) {
      levelStr = dotenv.env['LOG_LEVEL'] ?? 'warn';
      if (kDebugMode) {
        print('[ApiLogger] Using .env file LOG_LEVEL: $levelStr');
      }
    }

    if (kDebugMode) {
      print('[ApiLogger] Final LOG_LEVEL value: $levelStr');
    }

    switch (levelStr.toLowerCase()) {
      case 'error':
        _cachedLogLevel = LogLevel.error;
        break;
      case 'warn':
      case 'warning':
        _cachedLogLevel = LogLevel.warn;
        break;
      case 'info':
        _cachedLogLevel = LogLevel.info;
        break;
      case 'debug':
        _cachedLogLevel = LogLevel.debug;
        break;
      case 'verbose':
        _cachedLogLevel = LogLevel.verbose;
        break;
      default:
        _cachedLogLevel = LogLevel.warn;
    }

    if (kDebugMode) {
      print('[ApiLogger] Resolved to LogLevel: $_cachedLogLevel');
    }

    return _cachedLogLevel!;
  }

  /// Clear cached values (useful for testing or runtime config changes)
  static void clearCache() {
    _cachedLogLevel = null;
  }

  /// Test method to verify logging configuration
  static void testLogging() {
    if (!kDebugMode) return;

    print('[ApiLogger] Testing logging configuration...');
    print('[ApiLogger] Current log level: $_logLevel');

    error('Test error message');
    warn('Test warning message');
    info('Test info message');
    debug('Test debug message');
    verbose('Test verbose message');

    print('[ApiLogger] Logging test complete.');
  }

  /// Check if we should log at the given level
  static bool _shouldLog(LogLevel level) {
    return kDebugMode && _logLevel.index >= level.index;
  }

  /// Log an API request (only for debug and verbose levels)
  static void logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    String? operation,
  }) {
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    final operationTag = operation != null ? '[$operation]' : '';

    debugPrint('$_tag $operationTag REQUEST [$method] - $timestamp');
    debugPrint('$_tag URL: $url');

    // Only show headers for verbose level
    if (_shouldLog(LogLevel.verbose) && headers != null && headers.isNotEmpty) {
      debugPrint('$_tag HEADERS:');
      headers.forEach((key, value) {
        final maskedValue = _maskSensitiveData(key, value);
        debugPrint('$_tag   $key: $maskedValue');
      });
    }

    // Only show body for verbose level
    if (_shouldLog(LogLevel.verbose) && body != null) {
      debugPrint('$_tag BODY:');
      final bodyString = _formatJson(body);
      debugPrint('$_tag   $bodyString');
    }

    debugPrint('$_tag --- END REQUEST ---\n');
  }

  /// Log an API response with level-appropriate detail
  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    Map<String, String>? headers,
    dynamic body,
    String? operation,
    Duration? duration,
  }) {
    // Info level: one-liner with URL, status, and timing
    if (_shouldLog(LogLevel.info)) {
      final operationTag = operation != null ? '[$operation]' : '';
      final durationText =
          duration != null ? ' ${duration.inMilliseconds}ms' : '';
      debugPrint(
          '$_tag $operationTag $method $url -> $statusCode$durationText');
    }

    // Debug and verbose levels: detailed logging
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    final operationTag = operation != null ? '[$operation]' : '';
    final durationText =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';

    debugPrint(
        '$_tag $operationTag RESPONSE [$method] - $timestamp$durationText');
    debugPrint('$_tag URL: $url');
    debugPrint('$_tag STATUS: $statusCode');

    // Only show headers for verbose level
    if (_shouldLog(LogLevel.verbose) && headers != null && headers.isNotEmpty) {
      debugPrint('$_tag RESPONSE HEADERS:');
      headers.forEach((key, value) {
        debugPrint('$_tag   $key: $value');
      });
    }

    // Only show body for verbose level
    if (_shouldLog(LogLevel.verbose) && body != null) {
      debugPrint('$_tag RESPONSE BODY:');
      final bodyString = _formatJson(body);
      debugPrint('$_tag   $bodyString');
    }

    if (_shouldLog(LogLevel.debug)) {
      debugPrint('$_tag --- END RESPONSE ---\n');
    }
  }

  /// Log an API error (visible at error level and above)
  static void logError({
    required String method,
    required String url,
    required dynamic error,
    StackTrace? stackTrace,
    String? operation,
  }) {
    if (!_shouldLog(LogLevel.error)) return;

    final timestamp = DateTime.now().toIso8601String();
    final operationTag = operation != null ? '[$operation]' : '';

    debugPrint('$_tag $operationTag ERROR [$method] - $timestamp');
    debugPrint('$_tag URL: $url');
    debugPrint('$_tag ERROR: $error');

    // Only show stack trace for debug level and above
    if (_shouldLog(LogLevel.debug) && stackTrace != null) {
      debugPrint('$_tag STACK TRACE:');
      debugPrint('$stackTrace');
    }

    debugPrint('$_tag --- END ERROR ---\n');
  }

  /// Format JSON for better readability
  static String _formatJson(dynamic data) {
    try {
      if (data is String) {
        // Try to parse as JSON first
        try {
          final parsed = json.decode(data);
          return const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          // If not JSON, return as is
          return data;
        }
      } else {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (e) {
      return data.toString();
    }
  }

  /// Mask sensitive data in headers
  static String _maskSensitiveData(String key, String value) {
    final lowerKey = key.toLowerCase();
    if (lowerKey.contains('authorization') ||
        lowerKey.contains('token') ||
        lowerKey.contains('bearer') ||
        lowerKey.contains('api-key') ||
        lowerKey.contains('secret')) {
      if (value.length <= 10) {
        return '***';
      }
      return '${value.substring(0, 10)}...***';
    }
    return value;
  }

  /// Log operation start (visible at debug level and above)
  static void logOperationStart(String operation,
      [Map<String, dynamic>? params]) {
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_tag [$operation] OPERATION START - $timestamp');

    // Only show parameters for verbose level
    if (_shouldLog(LogLevel.verbose) && params != null && params.isNotEmpty) {
      debugPrint('$_tag [$operation] PARAMETERS:');
      params.forEach((key, value) {
        debugPrint('$_tag [$operation]   $key: $value');
      });
    }
  }

  /// Log operation end (visible at debug level and above)
  static void logOperationEnd(String operation, [Duration? duration]) {
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    final durationText =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    debugPrint('$_tag [$operation] OPERATION END - $timestamp$durationText\n');
  }

  /// Generic logging methods for use throughout the application

  /// Log error messages (visible at error level and above)
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_shouldLog(LogLevel.error)) return;
    debugPrint('$_tag ERROR: $message');
    if (error != null) debugPrint('$_tag ERROR DETAILS: $error');
    if (_shouldLog(LogLevel.debug) && stackTrace != null) {
      debugPrint('$_tag STACK TRACE: $stackTrace');
    }
  }

  /// Log warning messages (visible at warn level and above)
  static void warn(String message) {
    if (!_shouldLog(LogLevel.warn)) return;
    debugPrint('$_tag WARN: $message');
  }

  /// Log info messages (visible at info level and above)
  static void info(String message) {
    if (!_shouldLog(LogLevel.info)) return;
    debugPrint('$_tag INFO: $message');
  }

  /// Log debug messages (visible at debug level and above)
  static void debug(String message) {
    if (!_shouldLog(LogLevel.debug)) return;
    debugPrint('$_tag DEBUG: $message');
  }

  /// Log verbose messages (visible only at verbose level)
  static void verbose(String message) {
    if (!_shouldLog(LogLevel.verbose)) return;
    debugPrint('$_tag VERBOSE: $message');
  }
}
