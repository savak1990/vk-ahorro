import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_logger.dart';

class OpenAIAgentService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';

  /// messages — история сообщений, functions — список описаний функций (опционально)
  Future<OpenAIResponse> sendMessage(List<Map<String, String>> messages,
      {List<Map<String, dynamic>>? functions}) async {
    final stopwatch = Stopwatch()..start();
    const operation = 'sendMessage';

    try {
      ApiLogger.logOperationStart(operation, {
        'messagesCount': messages.length,
        'functionsCount': functions?.length ?? 0,
        'model': 'gpt-3.5-turbo-1106',
      });

      final bodyMap = {
        'model': 'gpt-3.5-turbo-1106',
        'messages': messages,
        if (functions != null) 'functions': functions,
        if (functions != null) 'function_call': 'auto',
      };

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

      ApiLogger.logRequest(
        method: 'POST',
        url: _apiUrl,
        headers: headers,
        body: bodyMap,
        operation: operation,
      );

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: headers,
        body: jsonEncode(bodyMap),
      );

      stopwatch.stop();

      ApiLogger.logResponse(
        method: 'POST',
        url: _apiUrl,
        statusCode: response.statusCode,
        headers: response.headers,
        body: response.body,
        operation: operation,
        duration: stopwatch.elapsed,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choice = data['choices'][0];
        final message = choice['message'];
        final content = message['content'] as String?;
        final functionCall = message['function_call'];

        ApiLogger.logOperationEnd(operation, stopwatch.elapsed);
        return OpenAIResponse(
          content: content,
          functionCall: functionCall,
        );
      } else {
        throw Exception(
            'Error OpenAI: ${response.statusCode} ${response.body}');
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      ApiLogger.logError(
        method: 'POST',
        url: _apiUrl,
        error: e,
        stackTrace: stackTrace,
        operation: operation,
      );
      rethrow;
    }
  }
}

class OpenAIResponse {
  final String? content;
  final dynamic functionCall;
  OpenAIResponse({this.content, this.functionCall});
}
