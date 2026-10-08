import 'package:ahorro_ui/src/services/api_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> lines;
  late DebugPrintCallback original;

  setUp(() {
    lines = [];
    original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    ApiLogger.clearCache();
  });

  tearDown(() => debugPrint = original);

  test('the response line carries the status and the request id', () {
    ApiLogger.logResponse(
      method: 'GET',
      url: 'https://api.example.invalid/api/v1/hello',
      statusCode: 200,
      requestId: 'abc-123',
      duration: const Duration(milliseconds: 42),
    );

    expect(lines, hasLength(1));
    expect(lines.single, contains('GET'));
    expect(lines.single, contains('https://api.example.invalid/api/v1/hello'));
    expect(lines.single, contains('-> 200'));
    expect(lines.single, contains('42ms'));
    expect(lines.single, contains('request_id=abc-123'));
  });

  // The id is optional, so a caller that omits it must not print a dangling
  // label or the string "null".
  test('the response line omits the label when there is no id', () {
    ApiLogger.logResponse(
      method: 'GET',
      url: 'https://api.example.invalid/api/v1/hello',
      statusCode: 500,
    );

    expect(lines.single, contains('-> 500'));
    expect(lines.single, isNot(contains('request_id')));
    expect(lines.single, isNot(contains('null')));
  });

  // A call that never answers logs no response line, so error is the only
  // place left to correlate from.
  test('the error line carries the request id', () {
    ApiLogger.logError(
      method: 'GET',
      url: 'https://api.example.invalid/api/v1/hello',
      error: 'connection refused',
      requestId: 'def-456',
    );

    expect(lines.first, contains('request_id=def-456'));
    expect(lines.join('\n'), contains('connection refused'));
  });

  // info is the default so the correlation line needs no flag. warn would
  // suppress it, which is what sent the operator to verbose.
  test('the response line prints with no LOG_LEVEL define', () {
    ApiLogger.logResponse(
      method: 'GET',
      url: 'https://api.example.invalid/api/v1/hello',
      statusCode: 200,
      requestId: 'ghi-789',
    );

    expect(lines, isNotEmpty);
  });
}
