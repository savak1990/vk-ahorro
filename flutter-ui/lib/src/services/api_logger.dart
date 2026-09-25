import 'package:flutter/foundation.dart';
import 'dart:convert';

enum LogLevel { error, warn, info, debug, verbose }

class ApiLogger {
  static const String _tag = '[ApiLogger]';

  static LogLevel? _cachedLogLevel;

  static LogLevel get _logLevel {
    if (_cachedLogLevel != null) return _cachedLogLevel!;

    const levelStr = String.fromEnvironment('LOG_LEVEL', defaultValue: 'warn');
    _cachedLogLevel = switch (levelStr.toLowerCase()) {
      'error' => LogLevel.error,
      'info' => LogLevel.info,
      'debug' => LogLevel.debug,
      'verbose' => LogLevel.verbose,
      _ => LogLevel.warn,
    };
    return _cachedLogLevel!;
  }

  static void clearCache() {
    _cachedLogLevel = null;
  }

  static void testLogging() {
    if (!kDebugMode) return;

    debugPrint('[ApiLogger] Testing logging configuration...');
    debugPrint('[ApiLogger] Current log level: $_logLevel');

    error('Test error message');
    warn('Test warning message');
    info('Test info message');
    debug('Test debug message');
    verbose('Test verbose message');

    debugPrint('[ApiLogger] Logging test complete.');
  }

  static bool _shouldLog(LogLevel level) {
    return kDebugMode && _logLevel.index >= level.index;
  }

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

    if (_shouldLog(LogLevel.verbose) && headers != null && headers.isNotEmpty) {
      debugPrint('$_tag HEADERS:');
      headers.forEach((key, value) {
        final maskedValue = _maskSensitiveData(key, value);
        debugPrint('$_tag   $key: $maskedValue');
      });
    }

    if (_shouldLog(LogLevel.verbose) && body != null) {
      debugPrint('$_tag BODY:');
      final bodyString = _formatJson(body);
      debugPrint('$_tag   $bodyString');
    }

    debugPrint('$_tag --- END REQUEST ---\n');
  }

  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    Map<String, String>? headers,
    dynamic body,
    String? operation,
    Duration? duration,
  }) {
    if (_shouldLog(LogLevel.info)) {
      final operationTag = operation != null ? '[$operation]' : '';
      final durationText = duration != null
          ? ' ${duration.inMilliseconds}ms'
          : '';
      debugPrint(
        '$_tag $operationTag $method $url -> $statusCode$durationText',
      );
    }

    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    final operationTag = operation != null ? '[$operation]' : '';
    final durationText = duration != null
        ? ' (${duration.inMilliseconds}ms)'
        : '';

    debugPrint(
      '$_tag $operationTag RESPONSE [$method] - $timestamp$durationText',
    );
    debugPrint('$_tag URL: $url');
    debugPrint('$_tag STATUS: $statusCode');

    if (_shouldLog(LogLevel.verbose) && headers != null && headers.isNotEmpty) {
      debugPrint('$_tag RESPONSE HEADERS:');
      headers.forEach((key, value) {
        debugPrint('$_tag   $key: $value');
      });
    }

    if (_shouldLog(LogLevel.verbose) && body != null) {
      debugPrint('$_tag RESPONSE BODY:');
      final bodyString = _formatJson(body);
      debugPrint('$_tag   $bodyString');
    }

    if (_shouldLog(LogLevel.debug)) {
      debugPrint('$_tag --- END RESPONSE ---\n');
    }
  }

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

    if (_shouldLog(LogLevel.debug) && stackTrace != null) {
      debugPrint('$_tag STACK TRACE:');
      debugPrint('$stackTrace');
    }

    debugPrint('$_tag --- END ERROR ---\n');
  }

  static String _formatJson(dynamic data) {
    try {
      if (data is String) {
        try {
          final parsed = json.decode(data);
          return const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          return data;
        }
      } else {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (e) {
      return data.toString();
    }
  }

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

  static void logOperationStart(
    String operation, [
    Map<String, dynamic>? params,
  ]) {
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    debugPrint('$_tag [$operation] OPERATION START - $timestamp');

    if (_shouldLog(LogLevel.verbose) && params != null && params.isNotEmpty) {
      debugPrint('$_tag [$operation] PARAMETERS:');
      params.forEach((key, value) {
        debugPrint('$_tag [$operation]   $key: $value');
      });
    }
  }

  static void logOperationEnd(String operation, [Duration? duration]) {
    if (!_shouldLog(LogLevel.debug)) return;

    final timestamp = DateTime.now().toIso8601String();
    final durationText = duration != null
        ? ' (${duration.inMilliseconds}ms)'
        : '';
    debugPrint('$_tag [$operation] OPERATION END - $timestamp$durationText\n');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!_shouldLog(LogLevel.error)) return;
    debugPrint('$_tag ERROR: $message');
    if (error != null) debugPrint('$_tag ERROR DETAILS: $error');
    if (_shouldLog(LogLevel.debug) && stackTrace != null) {
      debugPrint('$_tag STACK TRACE: $stackTrace');
    }
  }

  static void warn(String message) {
    if (!_shouldLog(LogLevel.warn)) return;
    debugPrint('$_tag WARN: $message');
  }

  static void info(String message) {
    if (!_shouldLog(LogLevel.info)) return;
    debugPrint('$_tag INFO: $message');
  }

  static void debug(String message) {
    if (!_shouldLog(LogLevel.debug)) return;
    debugPrint('$_tag DEBUG: $message');
  }

  static void verbose(String message) {
    if (!_shouldLog(LogLevel.verbose)) return;
    debugPrint('$_tag VERBOSE: $message');
  }
}
